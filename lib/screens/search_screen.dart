import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../signals/audio_signal.dart';
import '../signals/navigation_signal.dart';
import '../services/song_cache.dart';
import '../services/YoutubeDatasource.dart';
import '../widgets/page_header.dart';
import '../models/song.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String? _artDirPath;

  @override
  void initState() {
    super.initState();
    _initArtDir();
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
    return DefaultTabController(
      length: 2,
      child: Watch((context) {
        final localResults = audioSignal.localSearchResults.value;
        final youtubeResults = audioSignal.youtubeSearchResults.value;
        final ytRawResults = audioSignal.ytSearchResults.value;
        final query = audioSignal.searchQuery.value;
        final isSearching = query.isNotEmpty;
        final currentFilter = audioSignal.ytSearchFilter.value;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () {
                if (navigationSignal.canPopSync) {
                  navigationSignal.goBack(context);
                  // Clear search on exit
                  audioSignal.searchQuery.value = '';
                }
              },
            },
            child: Focus(
              autofocus: true,
              child: Column(
                children: [
                  // Header
                  PageHeader(
                    title: isSearching
                        ? 'Search results for "$query"'
                        : 'Search',
                    subtitle: isSearching 
                        ? '${localResults.length} local, ${ytRawResults.length} youtube'
                        : 'Search your library and YouTube',
                  ),

                  // TabBar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          isScrollable: true,
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          labelColor: Theme.of(context).colorScheme.onSecondary,
                          unselectedLabelColor: Theme.of(context).colorScheme.secondary,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                          tabs: const [
                            Tab(text: 'Local'),
                            Tab(text: 'YouTube'),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Results
                  Expanded(
                    child: TabBarView(
                      children: [
                        _ResultsList(
                          songs: localResults,
                          isSearching: isSearching,
                          query: query,
                          artDirPath: _artDirPath,
                          emptyMessage: 'No local songs found',
                        ),
                        // YouTube tab with filter chips + raw results
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
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Filter chip data
class _FilterOption {
  final String label;
  final SearchFilter? filter;
  final IconData icon;

  const _FilterOption(this.label, this.filter, this.icon);
}

const _filterOptions = [
  _FilterOption('Songs', SearchFilter.songs, FontAwesomeIcons.music),
  _FilterOption('Videos', SearchFilter.videos, FontAwesomeIcons.video),
  _FilterOption('Albums', SearchFilter.albums, FontAwesomeIcons.recordVinyl),
  _FilterOption('Artists', SearchFilter.artists, FontAwesomeIcons.userGroup),
  _FilterOption('Community Playlists', SearchFilter.community_playlists, FontAwesomeIcons.users),
  _FilterOption('Trending Playlists', SearchFilter.featured_playlists, FontAwesomeIcons.fire),
  _FilterOption('Podcasts', SearchFilter.podcasts, FontAwesomeIcons.podcast),
  _FilterOption('Episodes', SearchFilter.episodes, FontAwesomeIcons.circlePlay),
];

/// YouTube results tab with filter chips
class _YouTubeResultsTab extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips row
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _filterOptions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final opt = _filterOptions[index];
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
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSecondary
                      : Theme.of(context).colorScheme.secondary,
                ),
                selectedColor: Theme.of(context).colorScheme.secondary,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onSelected: (_) => onFilterChanged(opt.filter),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Results based on filter
        Expanded(
          child: _buildResults(context),
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    // For songs filter, use the mapped Song results for richer display
    if (currentFilter == SearchFilter.songs || currentFilter == null) {
      return _ResultsList(
        songs: songResults,
        isSearching: isSearching,
        query: query,
        artDirPath: artDirPath,
        emptyMessage: 'No YouTube songs found',
      );
    }

    // For all other filters, render raw results
    return _RawResultsList(
      results: rawResults,
      isSearching: isSearching,
      filterType: currentFilter!,
    );
  }
}

/// Renders raw map results for non-song filters (Albums, Artists, Playlists, etc.)
class _RawResultsList extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final bool isSearching;
  final SearchFilter filterType;

  const _RawResultsList({
    required this.results,
    required this.isSearching,
    required this.filterType,
  });

  String _getThumbnailUrl(Map<String, dynamic> item) {
    final thumbnails = item['thumbnails'];
    if (thumbnails is List && thumbnails.isNotEmpty) {
      return youtubeDatasource.transformThumbnail(thumbnails.last['url'] ?? '');
    }
    return '';
  }

  String _getTitle(Map<String, dynamic> item) {
    return item['title'] ?? item['name'] ?? item['artist'] ?? item['author'] ?? 'Unknown';
  }

  String _getSubtitle(Map<String, dynamic> item) {
    // Try artists list
    final artists = item['artists'];
    if (artists is List && artists.isNotEmpty) {
      return artists.map((a) => (a as Map)['name'] ?? '').join(', ');
    }
    // Try author
    if (item['author'] != null) return item['author'].toString();
    // Try subtitle
    if (item['subtitle'] != null) return item['subtitle'].toString();
    // Try type
    if (item['type'] != null) return item['type'].toString();
    return '';
  }

  IconData _getPlaceholderIcon() {
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

  bool _isCircularAvatar() {
    return filterType == SearchFilter.artists;
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final isSearchingYoutube = audioSignal.isSearchingYoutube.value;
      final showLoading = isSearchingYoutube && results.isEmpty;

      if (showLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      if (results.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(
                isSearching ? FontAwesomeIcons.magnifyingGlass : FontAwesomeIcons.music,
                size: 48,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
              ),
              const SizedBox(height: 16),
              Text(
                isSearching ? 'No results found' : 'Start typing to search',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                ),
              ),
            ],
          ),
        );
      }

      return CustomScrollView(
        slivers: [
          SuperSliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = results[index];
              final title = _getTitle(item);
              final subtitle = _getSubtitle(item);
              final thumbnailUrl = _getThumbnailUrl(item);
              final isCircular = _isCircularAvatar();

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
                            _getPlaceholderIcon(),
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
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
                subtitle: subtitle.isNotEmpty ? Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ) : null,
                onTap: () {
                  if (filterType == SearchFilter.videos && item['videoId'] != null) {
                    final song = youtubeDatasource.mapToSong(item);
                    audioSignal.playSong(song);
                  } else if (filterType == SearchFilter.albums && item['browseId'] != null) {
                    context.go('/youtube/album/${Uri.encodeComponent(item['browseId'])}',
                      extra: {'title': title, 'thumbnailUrl': thumbnailUrl});
                  } else if (filterType == SearchFilter.artists && (item['browseId'] != null)) {
                    context.go('/youtube/artist/${Uri.encodeComponent(item['browseId'])}',
                      extra: {'name': title, 'thumbnailUrl': thumbnailUrl});
                  } else if ((filterType == SearchFilter.community_playlists ||
                              filterType == SearchFilter.featured_playlists ||
                              filterType == SearchFilter.playlists) &&
                             item['browseId'] != null) {
                    // Playlist browseIds look like "VL...", strip the VL prefix for getPlaylist
                    String playlistId = item['browseId'];
                    if (playlistId.startsWith('VL')) playlistId = playlistId.substring(2);
                    context.go('/youtube/playlist/${Uri.encodeComponent(playlistId)}',
                      extra: {'title': title, 'thumbnailUrl': thumbnailUrl});
                  } else if (item['videoId'] != null) {
                    final song = youtubeDatasource.mapToSong(item);
                    audioSignal.playSong(song);
                  }
                },
              );
            }, childCount: results.length),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: audioSignal.reservedHeight.value),
          ),
        ],
      );
    });
  }
}

class _ResultsList extends StatelessWidget {
  final List<Song> songs;
  final bool isSearching;
  final String query;
  final String? artDirPath;
  final String emptyMessage;

  const _ResultsList({
    required this.songs,
    required this.isSearching,
    required this.query,
    required this.artDirPath,
    required this.emptyMessage,
  });

  String _getArtPath(String songPath) {
    if (artDirPath == null) return '';
    final fileName = '${songPath.hashCode.abs()}.jpg';
    return '$artDirPath/$fileName';
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '--:--';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final isSearchingYoutube = audioSignal.isSearchingYoutube.value;
      final showLoading = isSearchingYoutube && songs.isEmpty;

      if (showLoading) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      if (songs.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(
                isSearching ? FontAwesomeIcons.magnifyingGlass : FontAwesomeIcons.music,
                size: 48,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
              ),
              const SizedBox(height: 16),
              Text(
                isSearching ? emptyMessage : 'Start typing to search',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                ),
              ),
            ],
          ),
        );
      }

      return CustomScrollView(
      slivers: [
        SuperSliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final song = songs[index];
            final isCurrent = audioSignal.currentSong.value?.path == song.path;
            final isYoutube = song.path.startsWith('yt:');
            final artPath = !isYoutube ? _getArtPath(song.path) : '';
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
                      : hasArt && !isYoutube
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
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                        ),
                      )
                    : null,
              ),
              title: Text(
                song.title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                song.artist,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              trailing: Text(
                _formatDuration(song.duration ?? Duration.zero),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 12,
                ),
              ),
              onTap: () => audioSignal.playSong(song),
            );
          }, childCount: songs.length),
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: audioSignal.reservedHeight.value),
        ),
      ],
    );
    });
  }
}
