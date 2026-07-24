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
  final List<Map<String, dynamic>> _homeSections = [];
  final List<Map<String, dynamic>> _chartSections = [];
  final List<Map<String, dynamic>> _moods = [];
  bool _isLoading = true;
  String? _activeGenreParams;
  String? _activeGenreTitle;
  bool _isGenreLoading = false;
  bool _isChartsLoading = false;
  bool _chartsRequested = false;
  final ScrollController _scrollController = ScrollController();
  static const double _lazyLoadThreshold = 1500; // px from bottom

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadHome();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isChartsLoading || _chartsRequested) return;
    if (_activeGenreParams != null) return; // don't trigger when user is viewing a genre
    if (_sections.isEmpty || _isLoading) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) {
      // Nothing to scroll past — _maybePrefetchCharts handles this case.
      return;
    }
    if (position.pixels >= position.maxScrollExtent - _lazyLoadThreshold) {
      _loadMoreCharts();
    }
  }

  void _updateStateWithData(
    Map<String, dynamic> moodsData,
    Map<String, dynamic> exploreData,
    List<Map<String, dynamic>> sections, {
    required bool isFromCache,
  }) {
    if (!mounted) return;

    final newMoods = <Map<String, dynamic>>[];
    final seenMoodKeys = <String>{};
    if (moodsData.isNotEmpty) {
      for (var v in moodsData.values) {
        if (v is List) {
          for (final entry in v.cast<Map<String, dynamic>>()) {
            final title = (entry['title'] as String? ?? '').trim();
            if (title.isEmpty) continue;
            final key = title.toLowerCase();
            if (seenMoodKeys.add(key)) newMoods.add(entry);
          }
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
      _homeSections
        ..clear()
        ..addAll(newSections);
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
      _maybePrefetchCharts();
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
      _maybePrefetchCharts();
    } catch (e) {
      debugPrint('Error refreshing YTM home: $e');
      if (_sections.isEmpty && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// If the initial home fits fully on the viewport, the scroll-to-bottom
  /// gesture never fires. In that case, kick off the charts fetch after the
  /// first frame so the user immediately gets more sections beneath the
  /// existing ones without having to scroll.
  void _maybePrefetchCharts() {
    if (_chartsRequested || _isChartsLoading) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _chartsRequested || _isChartsLoading) return;
      // If the user can scroll beyond the bottom, the scroll listener will
      // take over. Only prefetch when scrolling is impossible (everything
      // already fits), or when the content is short.
      final canScroll = _scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 100;
      if (!canScroll && _sections.isNotEmpty) {
        _loadMoreCharts();
      }
    });
  }

  Future<void> _toggleGenre(String params, String title) async {
    if (_activeGenreParams == params) {
      // Deactivate: restore the home feed snapshot (home + any lazily-loaded charts).
      setState(() {
        _activeGenreParams = null;
        _activeGenreTitle = null;
        _isGenreLoading = false;
        _sections
          ..clear()
          ..addAll(_homeSections);
      });
      return;
    }

    // Show skeleton immediately while we fetch, but only if no cached data.
    final cached = await youtubeDatasource.getCachedMoodPlaylists(params);
    if (!mounted) return;
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _activeGenreParams = params;
        _activeGenreTitle = title;
        _sections
          ..clear()
          ..addAll(cached);
      });
    } else {
      setState(() {
        _activeGenreParams = params;
        _activeGenreTitle = title;
        _isGenreLoading = true;
        _sections.clear();
      });
    }

    try {
      final fresh = await youtubeDatasource.getMoodPlaylists(params);
      if (!mounted || _activeGenreParams != params) return;
      setState(() {
        _sections
          ..clear()
          ..addAll(fresh);
        _isGenreLoading = false;
      });
    } catch (e) {
      if (!mounted || _activeGenreParams != params) return;
      setState(() => _isGenreLoading = false);
      debugPrint('Error loading YTM genre $params: $e');
    }
  }

  Future<void> _loadMoreCharts() async {
    if (_isChartsLoading || _chartsRequested) return;
    _chartsRequested = true;
    setState(() => _isChartsLoading = true);

    try {
      // Use cache first for instant render, then refresh.
      final cached = await youtubeDatasource.getCachedCharts();
      if (mounted && cached != null && cached.isNotEmpty) {
        _appendChartsToHome(cached);
      }

      final fresh = await youtubeDatasource.getCharts();
      if (!mounted) return;
      _appendChartsToHome(fresh);
      setState(() => _isChartsLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isChartsLoading = false);
      debugPrint('Error loading YTM charts: $e');
    }
  }

  void _appendChartsToHome(Map<String, dynamic> charts) {
    if (charts.isEmpty) return;
    final built = _buildChartSections(charts);
    if (built.isEmpty) return;

    // Merge: keep home + the new sections that aren't already present (by title+key signature).
    final existingKeys = {
      for (final s in _sections) '${s['title']}|${s['sectionKey']}',
    };
    final toAdd = <Map<String, dynamic>>[];
    for (final section in built) {
      final key = '${section['title']}|${section['sectionKey']}';
      if (existingKeys.add(key)) toAdd.add(section);
    }
    if (toAdd.isEmpty) return;

    setState(() {
      _chartSections.addAll(toAdd);
      _sections.addAll(toAdd);
      _homeSections
        ..clear()
        ..addAll(_sections);
    });
  }

  List<Map<String, dynamic>> _buildChartSections(Map<String, dynamic> charts) {
    final built = <Map<String, dynamic>>[];
    final videoTitles = <String, String>{
      'videos': 'Top Music Videos',
      'daily': 'Daily Top Music Videos',
      'weekly': 'Weekly Top Music Videos',
      'genres': 'Top Genre Charts',
      'artists': 'Top Artists',
    };
    videoTitles.forEach((key, label) {
      final raw = charts[key];
      if (raw is List && raw.isNotEmpty) {
        final items = raw
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        if (items.isNotEmpty) {
          built.add({
            'title': label,
            'sectionKey': 'charts_$key',
            'items': items,
          });
        }
      }
    });
    return built;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        controller: _scrollController,
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
                      final params = mood['params'] ?? '';
                      final isActive = _activeGenreParams != null &&
                          _activeGenreParams == params;
                      final colorScheme = Theme.of(context).colorScheme;
                      return ActionChip(
                        label: Text(mood['title'] ?? ''),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        backgroundColor: isActive
                            ? colorScheme.secondary
                            : colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                        labelStyle: TextStyle(
                          color: isActive
                              ? colorScheme.surface
                              : colorScheme.secondary,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.normal,
                        ),
                        side: BorderSide.none,
                        onPressed: params.isEmpty
                            ? null
                            : () => _toggleGenre(params, mood['title'] ?? ''),
                      );
                    },
                  ),
                ),
              ),
            ),
          if (_isLoading && _sections.isEmpty)
            const YtHomeSkeleton()
          else if (_isGenreLoading && _sections.isEmpty)
            const YtHomeSkeleton()
          else if (_sections.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  _activeGenreTitle == null
                      ? 'Failed to load YouTube Music home.'
                      : 'No playlists found for $_activeGenreTitle.',
                ),
              ),
            )
          else ..._sections.map((section) => _buildSection(context, section)),
            
          if (!_chartsRequested && _activeGenreParams == null) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: OutlinedButton.icon(
                  onPressed: _isChartsLoading ? null : _loadMoreCharts,
                  icon: const Icon(Icons.bar_chart_outlined, size: 18),
                  label: const Text('Load charts'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ] else if (_isChartsLoading) ...[
            const SliverPadding(
              padding: EdgeInsets.symmetric(vertical: 24),
              sliver: SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],

          // Bottom spacing
          SliverToBoxAdapter(
            child: SignalBuilder(builder: (context) => SizedBox(height: audioSignal.reservedHeight.value)),
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
      navigatePush(context, '${AppRoutes.youtube}/album/${Uri.encodeComponent(browseId)}',
        extra: {'title': title, 'thumbnailUrl': thumbnailUrl});
    } else if (browseId.startsWith('UC') || browseId.startsWith('MPLA')) {
      // It's an artist
      navigatePush(context, '${AppRoutes.youtube}/artist/${Uri.encodeComponent(browseId)}',
        extra: {'name': title, 'thumbnailUrl': thumbnailUrl});
    } else if (playlistId.isNotEmpty) {
      // It's a playlist
      navigatePush(context, '${AppRoutes.youtube}/playlist/${Uri.encodeComponent(playlistId)}',
        extra: {'title': title, 'thumbnailUrl': thumbnailUrl});
    } else if (browseId.isNotEmpty) {
      // Generic browse — try as playlist (some community playlists are VL prefixed)
      String cleanId = browseId;
      if (cleanId.startsWith('VL')) cleanId = cleanId.substring(2);
      navigatePush(context, '${AppRoutes.youtube}/playlist/${Uri.encodeComponent(cleanId)}',
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
