// Ecilaes - Cross-platform music player
// Copyright (C) 2024  Anton Borri
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
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';
import '../services/YoutubeDatasource.dart';
import '../theme/app_theme_tokens.dart';
import '../widgets/sliver_page_header.dart';
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

  Future<void> _loadHome() async {
    setState(() => _isLoading = true);
    
    final moodsData = await youtubeDatasource.getMoodCategories();
    final exploreData = await youtubeDatasource.getExplore();
    final sections = await youtubeDatasource.getHomeSections();
    
    if (mounted) {
      setState(() {
        if (moodsData.isNotEmpty) {
          for (var v in moodsData.values) {
            if (v is List) {
              _moods.addAll(v.cast<Map<String, dynamic>>());
            }
          }
        }
        
        // Add Explore sections to the top
        if (exploreData.containsKey('new_releases') && exploreData['new_releases'] is List) {
           _sections.add({
             'title': 'New Releases',
             'items': exploreData['new_releases'],
           });
        }
        
        if (exploreData.containsKey('trending') && exploreData['trending'] is Map) {
           final trending = exploreData['trending'];
           if (trending['items'] is List) {
               _sections.add({
                 'title': 'Trending',
                 'items': trending['items'],
               });
           }
        }
        
        _sections.addAll(sections);
        _isLoading = false;
      });
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
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_sections.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('Failed to load YouTube Music home.')),
            )
          else
            ..._sections.map((section) => _buildSection(context, section)),
            
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
    final items = section['items'] as List<dynamic>;

    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    // Check if primarily songs (videoId present, no specific browseId like MPRE)
    bool isSongSection = items.every((i) {
      if (i is! Map) return false;
      final browseId = i['browseId']?.toString() ?? '';
      return i['videoId'] != null && !browseId.startsWith('MPRE') && !browseId.startsWith('UC') && !browseId.startsWith('MPLA');
    });

    if (isSongSection) {
      return _buildSongGridSection(context, title, items.cast<Map<String, dynamic>>());
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.secondary,
              ),
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

  Widget _buildSongGridSection(BuildContext context, String title, List<Map<String, dynamic>> items) {
    final chunks = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < items.length; i += 4) {
      chunks.add(items.sublist(i, i + 4 > items.length ? items.length : i + 4));
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.secondary,
              ),
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
                      
                      String? rawThumbnail;
                      final dynamic thumbnails = dItem['thumbnails'];
                      if (thumbnails is List && thumbnails.isNotEmpty) {
                        rawThumbnail = thumbnails.last['url'];
                      }
                      final thumbnailUrl = youtubeDatasource.transformThumbnail(rawThumbnail ?? '');

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: ListTile(
                          contentPadding: const EdgeInsets.only(right: 8),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: thumbnailUrl.isNotEmpty ? Image.network(
                              thumbnailUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (context, _, _) => Container(
                                width: 48, height: 48, color: Colors.grey[900],
                                child: Icon(Icons.music_note, color: _placeholderIconColor(context), size: 24),
                              ),
                            ) : Container(
                                width: 48, height: 48, color: Colors.grey[900],
                                child: Icon(Icons.music_note, color: _placeholderIconColorStatic(), size: 24),
                            ),
                          ),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6), fontSize: 12),
                          ),
                          onTap: () => audioSignal.playSong(song),
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

    if (browseId.startsWith('MPRE')) {
      // It's an album
      context.go('/youtube/album/${Uri.encodeComponent(browseId)}',
        extra: {'title': title, 'thumbnailUrl': thumbnailUrl});
    } else if (browseId.startsWith('UC') || browseId.startsWith('MPLA')) {
      // It's an artist
      context.go('/youtube/artist/${Uri.encodeComponent(browseId)}',
        extra: {'name': title, 'thumbnailUrl': thumbnailUrl});
    } else if (playlistId.isNotEmpty) {
      // It's a playlist
      context.go('/youtube/playlist/${Uri.encodeComponent(playlistId)}',
        extra: {'title': title, 'thumbnailUrl': thumbnailUrl});
    } else if (videoId.isNotEmpty) {
      // It's a song/video — play it
      final song = youtubeDatasource.mapToSong(dItem);
      audioSignal.playSong(song);
    } else if (browseId.isNotEmpty) {
      // Generic browse — try as playlist (some community playlists are VL prefixed)
      String cleanId = browseId;
      if (cleanId.startsWith('VL')) cleanId = cleanId.substring(2);
      context.go('/youtube/playlist/${Uri.encodeComponent(cleanId)}',
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
