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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../signals/audio_signal.dart';
import '../signals/navigation_signal.dart';
import '../services/song_cache.dart';
import '../services/YoutubeDatasource.dart';
import '../widgets/standard_sliver_list.dart';
import '../models/song.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  String? _artDirPath;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initArtDir();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initArtDir() async {
    final path = await SongCache.artDir;
    if (mounted) {
      setState(() {
        _artDirPath = path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final localResults = audioSignal.localSearchResults.value;
      final youtubeResults = audioSignal.youtubeSearchResults.value;
      final ytRawResults = audioSignal.ytSearchResults.value;
      final query = audioSignal.searchQuery.value;
      final isSearching = query.isNotEmpty;
      final currentFilter = audioSignal.ytSearchFilter.value;
      final localFilter = audioSignal.localSearchFilter.value;

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (navigationSignal.canPopSync) {
                navigationSignal.goBack(context);
                audioSignal.searchQuery.value = '';
              }
            },
          },
          child: ListenableBuilder(
            listenable: _tabController,
            builder: (context, _) {
              final currentTab = _tabController.index;
              return Column(
                children: [
                  // Fixed header: clear status bar + 80px window title bar
                  SizedBox(height: MediaQuery.of(context).padding.top + 80),
                // Apple-style tab switcher
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Container(
                      height: 36,
                      width: 360,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(67),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(67),
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        labelColor: Theme.of(context).colorScheme.onSecondary,
                        unselectedLabelColor: Theme.of(
                          context,
                        ).colorScheme.secondary,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        tabs: const [
                          Tab(text: 'Local'),
                          Tab(text: 'YouTube'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter chips (conditional on active tab)
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: currentTab == 0
                        ? _localFilterOptions.length
                        : _ytFilterOptions.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (currentTab == 0) {
                        final opt = _localFilterOptions[index];
                        final isSelected = opt.filter == localFilter;
                        return FilterChip(
                          selected: isSelected,
                          showCheckmark: false,
                          avatar: FaIcon(
                            opt.icon,
                            size: 14,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onSecondary
                                : Theme.of(context).colorScheme.secondary,
                          ),
                          label: Text(opt.label),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onSecondary
                                : Theme.of(context).colorScheme.secondary,
                          ),
                          selectedColor: Theme.of(context).colorScheme.secondary,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          onSelected: (_) =>
                              audioSignal.localSearchFilter.value = opt.filter,
                        );
                      } else {
                        final opt = _ytFilterOptions[index];
                        final isSelected = opt.filter == currentFilter;
                        return FilterChip(
                          selected: isSelected,
                          showCheckmark: false,
                          avatar: FaIcon(
                            opt.icon,
                            size: 14,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onSecondary
                                : Theme.of(context).colorScheme.secondary,
                          ),
                          label: Text(opt.label),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onSecondary
                                : Theme.of(context).colorScheme.secondary,
                          ),
                          selectedColor: Theme.of(context).colorScheme.secondary,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          onSelected: (_) =>
                              audioSignal.ytSearchFilter.value = opt.filter,
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _LocalResultsTab(
                        filter: localFilter,
                        songs: localResults,
                        isSearching: isSearching,
                        query: query,
                        artDirPath: _artDirPath,
                      ),
                      _YouTubeResultsTab(
                        rawResults: ytRawResults,
                        songResults: youtubeResults,
                        isSearching: isSearching,
                        query: query,
                        artDirPath: _artDirPath,
                        currentFilter: currentFilter,
                        onFilterChanged: (filter) {
                          audioSignal.ytSearchFilter.value = filter;
                        },
                      ),
                    ],
                  ),
                ),
                ],
              );
            },
          ),
        ),
      );
    });
  }
}

/// Filter chip data for YouTube tab
class _FilterOption {
  final String label;
  final SearchFilter? filter;
  final FaIconData icon;

  const _FilterOption(this.label, this.filter, this.icon);
}

const _ytFilterOptions = [
  _FilterOption('Songs', SearchFilter.songs, FontAwesomeIcons.music),
  _FilterOption('Videos', SearchFilter.videos, FontAwesomeIcons.video),
  _FilterOption('Albums', SearchFilter.albums, FontAwesomeIcons.recordVinyl),
  _FilterOption('Artists', SearchFilter.artists, FontAwesomeIcons.userGroup),
  _FilterOption(
    'Community Playlists',
    SearchFilter.community_playlists,
    FontAwesomeIcons.users,
  ),
  _FilterOption(
    'Trending Playlists',
    SearchFilter.featured_playlists,
    FontAwesomeIcons.fire,
  ),
  _FilterOption('Podcasts', SearchFilter.podcasts, FontAwesomeIcons.podcast),
  _FilterOption('Episodes', SearchFilter.episodes, FontAwesomeIcons.circlePlay),
];

/// Filter chip data for Local tab
class _LocalFilterOption {
  final String label;
  final LocalSearchFilter filter;
  final FaIconData icon;

  const _LocalFilterOption(this.label, this.filter, this.icon);
}

const _localFilterOptions = [
  _LocalFilterOption('Songs', LocalSearchFilter.songs, FontAwesomeIcons.music),
  _LocalFilterOption('Playlists', LocalSearchFilter.playlists, FontAwesomeIcons.list),
  _LocalFilterOption('Albums', LocalSearchFilter.albums, FontAwesomeIcons.recordVinyl),
  _LocalFilterOption('Artists', LocalSearchFilter.artists, FontAwesomeIcons.userGroup),
  _LocalFilterOption('Folders', LocalSearchFilter.folders, FontAwesomeIcons.folder),
];

/// YouTube results tab with filter chips
class _YouTubeResultsTab extends StatefulWidget {
  final List<Map<String, dynamic>> rawResults;
  final List<Song> songResults;
  final bool isSearching;
  final String query;
  final String? artDirPath;
  final SearchFilter? currentFilter;
  final ValueChanged<SearchFilter?> onFilterChanged;

  const _YouTubeResultsTab({
    required this.rawResults,
    required this.songResults,
    required this.isSearching,
    required this.query,
    required this.artDirPath,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  State<_YouTubeResultsTab> createState() => _YouTubeResultsTabState();
}

class _YouTubeResultsTabState extends State<_YouTubeResultsTab> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final hasMore = audioSignal.hasMoreYtResults.value;
    final isLoading = audioSignal.isSearchingYoutube.value;
    if (maxScroll - currentScroll < 300 && hasMore && !isLoading) {
      audioSignal.loadMoreYtResults();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        ..._buildResultsSlivers(context),
        Watch((context) {
          final isLoading = audioSignal.isSearchingYoutube.value;
          final hasMore = audioSignal.hasMoreYtResults.value;
          if (!isLoading && !hasMore) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          );
        }),
      ],
    );
  }

  List<Widget> _buildResultsSlivers(BuildContext context) {
    if (widget.currentFilter == SearchFilter.songs ||
        widget.currentFilter == null) {
      return _ResultsSliverList.buildSlivers(
        context,
        songs: widget.songResults,
        isSearching: widget.isSearching,
        query: widget.query,
        artDirPath: widget.artDirPath,
        emptyMessage: 'No YouTube songs found',
      );
    }

    return _RawResultsSliverList.buildSlivers(
      context,
      results: widget.rawResults,
      isSearching: widget.isSearching,
      filterType: widget.currentFilter ?? SearchFilter.songs,
    );
  }
}

/// Renders raw map results for non-song filters
class _RawResultsSliverList {
  static List<Widget> buildSlivers(
    BuildContext context, {
    required List<Map<String, dynamic>> results,
    required bool isSearching,
    required SearchFilter filterType,
  }) {
    final resultsWidget = Watch((context) {
      final isSearchingYoutube = audioSignal.isSearchingYoutube.value;
      return StandardSliverList<Map<String, dynamic>>(
        items: results,
        isLoading: isSearchingYoutube && results.isEmpty,
        emptyMessage: isSearching
            ? 'No results found'
            : 'Start typing to search',
        itemBuilder: (context, item, index) {
          final title =
              item['title'] ??
              item['name'] ??
              item['artist'] ??
              item['author'] ??
              'Unknown';
          final artists = item['artists'];
          final subtitle = (artists is List && artists.isNotEmpty)
              ? artists.map((a) => (a as Map)['name'] ?? '').join(', ')
              : (item['author']?.toString() ??
                    item['subtitle']?.toString() ??
                    item['type']?.toString() ??
                    '');
          final thumbnails = item['thumbnails'];
          final thumbnailUrl = (thumbnails is List && thumbnails.isNotEmpty)
              ? youtubeDatasource.transformThumbnail(
                  thumbnails.last['url'] ?? '',
                )
              : '';
          final isCircular = filterType == SearchFilter.artists;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              vertical: 4,
              horizontal: 24,
            ),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: isCircular
                    ? BorderRadius.circular(24)
                    : BorderRadius.circular(4),
                image: thumbnailUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(thumbnailUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: thumbnailUrl.isEmpty
                  ? Center(
                      child: FaIcon(
                        _getPlaceholderIcon(filterType),
                        size: 18,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.24),
                      ),
                    )
                  : null,
            ),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            subtitle: subtitle.isNotEmpty
                ? Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  )
                : null,
            onTap: () {
              if (filterType == SearchFilter.videos &&
                  item['videoId'] != null) {
                audioSignal.playSong(youtubeDatasource.mapToSong(item));
              } else if (filterType == SearchFilter.albums &&
                  item['browseId'] != null) {
                context.go(
                  '/youtube/album/${Uri.encodeComponent(item['browseId'])}',
                  extra: {'title': title, 'thumbnailUrl': thumbnailUrl},
                );
              } else if (filterType == SearchFilter.artists &&
                  (item['browseId'] != null)) {
                context.go(
                  '/youtube/artist/${Uri.encodeComponent(item['browseId'])}',
                  extra: {'name': title, 'thumbnailUrl': thumbnailUrl},
                );
              } else if ((filterType == SearchFilter.community_playlists ||
                      filterType == SearchFilter.featured_playlists ||
                      filterType == SearchFilter.playlists) &&
                  item['browseId'] != null) {
                String playlistId = item['browseId'];
                if (playlistId.startsWith('VL')) {
                  playlistId = playlistId.substring(2);
                }
                context.go(
                  '/youtube/playlist/${Uri.encodeComponent(playlistId)}',
                  extra: {'title': title, 'thumbnailUrl': thumbnailUrl},
                );
              } else if (item['videoId'] != null) {
                audioSignal.playSong(youtubeDatasource.mapToSong(item));
              }
            },
          );
        },
      );
    });

    return [resultsWidget];
  }

  static FaIconData _getPlaceholderIcon(SearchFilter filterType) {
    switch (filterType) {
      case SearchFilter.videos:
        return FontAwesomeIcons.video;
      case SearchFilter.albums:
        return FontAwesomeIcons.recordVinyl;
      case SearchFilter.artists:
        return FontAwesomeIcons.userGroup;
      case SearchFilter.community_playlists:
      case SearchFilter.featured_playlists:
      case SearchFilter.playlists:
        return FontAwesomeIcons.list;
      case SearchFilter.podcasts:
        return FontAwesomeIcons.podcast;
      case SearchFilter.episodes:
        return FontAwesomeIcons.circlePlay;
      default:
        return FontAwesomeIcons.music;
    }
  }
}

class _ResultsSliverList {
  static List<Widget> buildSlivers(
    BuildContext context, {
    required List<Song> songs,
    required bool isSearching,
    required String query,
    required String? artDirPath,
    required String emptyMessage,
  }) {
    final resultsWidget = Watch((context) {
      final isSearchingYoutube = audioSignal.isSearchingYoutube.value;
      return StandardSliverList<Song>(
        items: songs,
        isLoading: isSearchingYoutube && songs.isEmpty,
        emptyMessage: isSearching ? emptyMessage : 'Start typing to search',
        itemBuilder: (context, song, index) {
          final isYoutube = song.path.startsWith('yt:');
          final artPath = !isYoutube
              ? (artDirPath != null
                    ? '$artDirPath/${song.path.hashCode.abs()}.jpg'
                    : '')
              : '';
          final ytThumbnailUrl = isYoutube
              ? youtubeDatasource.getArtworkUrl(song.path.substring(3))
              : null;
          final hasArt = song.hasAlbumArt && (artPath.isNotEmpty || isYoutube);

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              vertical: 4,
              horizontal: 24,
            ),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
                image: isYoutube && hasArt
                    ? DecorationImage(
                        image: NetworkImage(ytThumbnailUrl!),
                        fit: BoxFit.cover,
                      )
                    : hasArt
                    ? DecorationImage(
                        image: FileImage(File(artPath)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: !hasArt
                  ? Center(
                      child: FaIcon(
                        FontAwesomeIcons.music,
                        size: 18,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.24),
                      ),
                    )
                  : null,
            ),
            title: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            trailing: Text(
              song.duration == null || song.duration == Duration.zero
                  ? '--:--'
                  : '${song.duration!.inMinutes}:${song.duration!.inSeconds.remainder(60).toString().padLeft(2, '0')}',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.38),
                fontSize: 12,
              ),
            ),
            onTap: () => audioSignal.playSong(song),
          );
        },
      );
    });

    return [resultsWidget];
  }
}

/// Local results tab that adapts content based on the selected filter.
class _LocalResultsTab extends StatelessWidget {
  final LocalSearchFilter filter;
  final List<Song> songs;
  final bool isSearching;
  final String query;
  final String? artDirPath;

  const _LocalResultsTab({
    required this.filter,
    required this.songs,
    required this.isSearching,
    required this.query,
    required this.artDirPath,
  });

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      switch (filter) {
        case LocalSearchFilter.songs:
          return CustomScrollView(
            slivers: [
              ..._ResultsSliverList.buildSlivers(
                context,
                songs: songs,
                isSearching: isSearching,
                query: query,
                artDirPath: artDirPath,
                emptyMessage: 'No local songs found',
              ),
            ],
          );
        case LocalSearchFilter.playlists:
          return _LocalPlaylistsList(
            isSearching: isSearching,
            query: query,
          );
        case LocalSearchFilter.albums:
          return _LocalAlbumsList(
            isSearching: isSearching,
            query: query,
          );
        case LocalSearchFilter.artists:
          return _LocalArtistsList(
            isSearching: isSearching,
            query: query,
          );
        case LocalSearchFilter.folders:
          return _LocalFoldersList(
            isSearching: isSearching,
            query: query,
          );
      }
    });
  }
}

/// Local playlists search results
class _LocalPlaylistsList extends StatelessWidget {
  final bool isSearching;
  final String query;

  const _LocalPlaylistsList({
    required this.isSearching,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final playlists = audioSignal.localSearchPlaylists.value;
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final playlist = playlists[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 24,
                ),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.list,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                    ),
                  ),
                ),
                title: Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${playlist.songPaths.length} songs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                onTap: () => context.go('/playlist/${playlist.id}'),
              );
            },
            childCount: playlists.length,
          ),
        ),
        if (playlists.isEmpty && isSearching)
          SliverFillRemaining(
            child: Center(
              child: Text(
                'No playlists found',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        if (!isSearching)
          SliverFillRemaining(
            child: Center(
              child: Text(
                'Start typing to search',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Local albums search results
class _LocalAlbumsList extends StatelessWidget {
  final bool isSearching;
  final String query;

  const _LocalAlbumsList({
    required this.isSearching,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final albums = audioSignal.localSearchAlbums.value;
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final album = albums[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 24,
                ),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.recordVinyl,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                    ),
                  ),
                ),
                title: Text(
                  album.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${album.artist} · ${album.songCount} songs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                onTap: () => context.go(
                  '/albums/${Uri.encodeComponent(album.artist)}/${Uri.encodeComponent(album.name)}',
                ),
              );
            },
            childCount: albums.length,
          ),
        ),
        if (albums.isEmpty && isSearching)
          SliverFillRemaining(
            child: Center(
              child: Text(
                'No albums found',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        if (!isSearching)
          SliverFillRemaining(
            child: Center(
              child: Text(
                'Start typing to search',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Local artists search results
class _LocalArtistsList extends StatelessWidget {
  final bool isSearching;
  final String query;

  const _LocalArtistsList({
    required this.isSearching,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final artists = audioSignal.localSearchArtists.value;
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final artist = artists[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 24,
                ),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.userGroup,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                    ),
                  ),
                ),
                title: Text(
                  artist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${artist.songCount} songs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                onTap: () => context.go(
                  '/artists/${Uri.encodeComponent(artist.name)}',
                ),
              );
            },
            childCount: artists.length,
          ),
        ),
        if (artists.isEmpty && isSearching)
          SliverFillRemaining(
            child: Center(
              child: Text(
                'No artists found',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        if (!isSearching)
          SliverFillRemaining(
            child: Center(
              child: Text(
                'Start typing to search',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Local folders search results
class _LocalFoldersList extends StatelessWidget {
  final bool isSearching;
  final String query;

  const _LocalFoldersList({
    required this.isSearching,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final folders = audioSignal.localSearchFolders.value;
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final folder = folders[index];
              final name = folder.split('/').last;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 24,
                ),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.folder,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                    ),
                  ),
                ),
                title: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  folder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                onTap: () => context.go('/explorer'),
              );
            },
            childCount: folders.length,
          ),
        ),
        if (folders.isEmpty && isSearching)
          SliverFillRemaining(
            child: Center(
              child: Text(
                'No folders found',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        if (!isSearching)
          SliverFillRemaining(
            child: Center(
              child: Text(
                'Start typing to search',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
