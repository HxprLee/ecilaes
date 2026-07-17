// Ecilaes - Cross-platform music player
// Copyright (C) 2024  hxprlee
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';
import '../signals/search_signal.dart';
import '../router/routes.dart';
import '../services/YoutubeDatasource.dart';
import '../theme/app_theme_tokens.dart';
import '../utils/navigation.dart';
import '../widgets/components/sliver_page_header.dart';
import '../widgets/components/song_tile.dart';
import '../widgets/components/yt_home_skeleton.dart';
import '../widgets/song_actions_sheet.dart';

class YoutubeMusicScreen extends StatefulWidget {
  const YoutubeMusicScreen({super.key});

  @override
  State<YoutubeMusicScreen> createState() => _YoutubeMusicScreenState();
}

class _YoutubeMusicScreenState extends State<YoutubeMusicScreen> {
  final List<Map<String, dynamic>> _sections = [];
  final List<Map<String, dynamic>> _moods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  Color _placeholderIconColor(BuildContext context) {
    if (context.isMaterial3) {
      return context.colorScheme.onSurface.withValues(alpha: 0.2);
    }
    return Colors.white24;
  }

  Color _placeholderIconColorStatic() {
    // Fallback for branches without context — use light eclipx color
    return Colors.white24;
  }

  void _updateStateWithData(
    Map<String, dynamic> moodsData,
    Map<String, dynamic> exploreData,
    List<Map<String, dynamic>> sections, {
    required bool isFromCache,
  }) {
    if (!mounted) return;

    final newMoods = <Map<String, dynamic>>[];
    if (moodsData.isNotEmpty) {
      for (var v in moodsData.values) {
        if (v is List) {
          newMoods.addAll(v.cast<Map<String, dynamic>>());
        }
      }
    }

    final newSections = <Map<String, dynamic>>[];
    // Add Explore sections to the top
    if (exploreData.containsKey('new_releases') && exploreData['new_releases'] is List) {
       newSections.add({
         'title': 'New Releases',
         'sectionKey': 'new_releases',
         'items': exploreData['new_releases'],
       });
    }

    if (exploreData.containsKey('trending') && exploreData['trending'] is Map) {
       final trending = exploreData['trending'];
       if (trending['items'] is List) {
           newSections.add({
             'title': 'Trending',
             'sectionKey': 'trending',
             'items': trending['items'],
           });
       }
    }

    newSections.addAll(sections);

    setState(() {
      _moods.clear();
      _moods.addAll(newMoods);
      _sections.clear();
      _sections.addAll(newSections);
      _isLoading = false;
    });

    // Cache browsed songs so resolveSong can find them later.
    // Only do this for freshly-fetched data to avoid duplicating already-cached entries.
    if (!isFromCache) {
      for (final section in newSections) {
        final items = section['items'] as List? ?? [];
        for (final item in items) {
          if (item is Map && item['videoId'] != null) {
            searchSignal.ytBrowseResults.value = [
              ...searchSignal.ytBrowseResults.value,
              youtubeDatasource.mapToSong(Map<String, dynamic>.from(item)),
            ];
          }
        }
      }
    }
  }

  Future<void> _loadHome() async {
    // 1. Try to load from cache first for instant UI.
    // Show skeleton while attempting cache (if empty) or fetching fresh.
    final cachedMoods = await youtubeDatasource.getCachedMoodCategories();
    final cachedExplore = await youtubeDatasource.getCachedExplore();
    final cachedSections = await youtubeDatasource.getCachedHomeSections();

    if (cachedMoods != null && cachedExplore != null && cachedSections != null && cachedSections.isNotEmpty) {
      _updateStateWithData(cachedMoods, cachedExplore, cachedSections, isFromCache: true);
    } else {
      setState(() => _isLoading = true);
    }

    // 2. Fetch fresh data in parallel (cache writes are non-awaited).
    try {
      final (moodsData, exploreData) = await (
        youtubeDatasource.getMoodCategories(),
        youtubeDatasource.getExplore(),
      ).wait;
      final sections = await youtubeDatasource.getHomeSections();
      _updateStateWithData(moodsData, exploreData, sections, isFromCache: false);
    } catch (e) {
      debugPrint('Error refreshing YTM home: $e');
      if (_sections.isEmpty && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          const SliverPageHeader(title: 'YouTube Music'),
          if (_moods.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _moods.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final mood = _moods[index];
                      return ActionChip(
                        label: Text(mood['title'] ?? ''),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        side: BorderSide.none,
                        onPressed: () {
                           // Navigate to mood playlist future enhancement
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          if (_isLoading && _sections.isEmpty)
            const YtHomeSkeleton()
          else if (_sections.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('Failed to load YouTube Music home.')),
            )
          else ..._sections.map((section) => _buildSection(context, section)),
            
          // Bottom spacing
          SliverToBoxAdapter(
            child: Watch((context) => SizedBox(height: audioSignal.reservedHeight.value)),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, Map<String, dynamic> section) {
    final title = section['title'] as String;
    final sectionKey = section['sectionKey'] as String? ?? title.toLowerCase().replaceAll(' ', '_');
    final items = section['items'] as List<dynamic>;

    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    // Check if primarily songs (videoId present, no specific browseId like MPRE)
    bool isSongSection = items.every((i) {
      if (i is! Map) return false;
      final browseId = i['browseId']?.toString() ?? '';
      return i['videoId'] != null && !browseId.startsWith('MPRE') && !browseId.startsWith('UC') && !browseId.startsWith('MPLA');
    });

    if (isSongSection) {
      return _buildSongGridSection(context, title, sectionKey, items.cast<Map<String, dynamic>>());
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 8, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => navigatePush(context, AppRoutes.seeMore, extra: {'sectionKey': sectionKey, 'title': title}),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final item = items[index];
                final Map<String, dynamic> dItem = item is Map ? Map<String, dynamic>.from(item) : {};
                
                String? rawThumbnail;
                final dynamic thumbnails = dItem['thumbnails'];
                if (thumbnails is List && thumbnails.isNotEmpty) {
                  rawThumbnail = thumbnails.last['url'];
                } else if (dItem['thumbnail'] is Map) {
                  rawThumbnail = dItem['thumbnail']['url'];
                }

                final thumbnailUrl = youtubeDatasource.transformThumbnail(rawThumbnail ?? '');
                
                final String itemTitle = dItem['title'] ?? dItem['name'] ?? 'Unknown';
                
                String itemSubtitle = '';
                final dynamic artists = dItem['artists'];
                if (artists is List && artists.isNotEmpty) {
                  itemSubtitle = artists.map((a) => (a as Map)['name'] ?? '').join(', ');
                } else {
                  itemSubtitle = dItem['subtitle'] ?? '';
                }

                return _YtmCard(
                  title: itemTitle,
                  subtitle: itemSubtitle,
                  thumbnailUrl: thumbnailUrl,
                  onTap: () => _onItemTap(context, dItem, itemTitle, thumbnailUrl),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSongGridSection(BuildContext context, String title, String sectionKey, List<Map<String, dynamic>> items) {
    final chunks = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < items.length; i += 4) {
      chunks.add(items.sublist(i, i + 4 > items.length ? items.length : i + 4));
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 8, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => navigatePush(context, AppRoutes.seeMore, extra: {'sectionKey': sectionKey, 'title': title}),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 320, // 4 items * ~80 height
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: chunks.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final chunk = chunks[index];
                double width = MediaQuery.of(context).size.width * 0.85;
                if (width > 350) width = 350;

                return SizedBox(
                  width: width,
                  child: Column(
                    children: chunk.map((dItem) {
                      final song = youtubeDatasource.mapToSong(dItem);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: SongTile(
                          song: song,
                          trailing: IconButton(
                            icon: FaIcon(FontAwesomeIcons.ellipsisVertical, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
                            onPressed: () => showSongMoreActionsSheet(context: context, song: song),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _onItemTap(BuildContext context, Map<String, dynamic> dItem, String title, String thumbnailUrl) {
    // Album: has browseId starting with "MPRE"
    final browseId = dItem['browseId']?.toString() ?? '';
    final playlistId = dItem['playlistId']?.toString() ?? '';
    final videoId = dItem['videoId']?.toString() ?? '';

    // Song/video: check videoId first because items like "Listen again" can have
    // both videoId and playlistId, and playlistId should not take priority.
    if (videoId.isNotEmpty) {
      final song = youtubeDatasource.mapToSong(dItem);
      searchSignal.ytBrowseResults.value = [
        ...searchSignal.ytBrowseResults.value,
        song,
      ];
      audioSignal.playSong(song);
    } else if (browseId.startsWith('MPRE')) {
      // It's an album
      navigateGo(context, '${AppRoutes.youtube}/album/${Uri.encodeComponent(browseId)}',
        extra: {'title': title, 'thumbnailUrl': thumbnailUrl});
    } else if (browseId.startsWith('UC') || browseId.startsWith('MPLA')) {
      // It's an artist
      navigateGo(context, '${AppRoutes.youtube}/artist/${Uri.encodeComponent(browseId)}',
        extra: {'name': title, 'thumbnailUrl': thumbnailUrl});
    } else if (playlistId.isNotEmpty) {
      // It's a playlist
      navigateGo(context, '${AppRoutes.youtube}/playlist/${Uri.encodeComponent(playlistId)}',
        extra: {'title': title, 'thumbnailUrl': thumbnailUrl});
    } else if (browseId.isNotEmpty) {
      // Generic browse — try as playlist (some community playlists are VL prefixed)
      String cleanId = browseId;
      if (cleanId.startsWith('VL')) cleanId = cleanId.substring(2);
      navigateGo(context, '${AppRoutes.youtube}/playlist/${Uri.encodeComponent(cleanId)}',
        extra: {'title': title, 'thumbnailUrl': thumbnailUrl});
    }
  }
}

class _YtmCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String thumbnailUrl;
  final VoidCallback onTap;

  const _YtmCard({
    required this.title,
    required this.subtitle,
    required this.thumbnailUrl,
    required this.onTap,
  });

  Color _placeholderIconColor(BuildContext context) {
    if (context.isMaterial3) {
      return context.colorScheme.onSurface.withValues(alpha: 0.2);
    }
    return Colors.white24;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: thumbnailUrl.isNotEmpty
                    ? Image.network(
                        thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[900],
                          child: Icon(Icons.music_note, color: _placeholderIconColor(context),),
                        ),
                      )
                    : Container(color: Colors.grey[900]),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
