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
import '../widgets/sliver_page_header.dart';
import '../widgets/standard_sliver_list.dart';
import '../models/song.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
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
          child: ListenableBuilder(
            listenable: _tabController,
            builder: (context, _) => NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  sliver: SliverPageHeader(
                    title: isSearching
                        ? 'Search results for "$query"'
                        : 'Search',
                    subtitle: isSearching
                        ? '${localResults.length} local, ${ytRawResults.length} youtube'
                        : 'Search your library and YouTube',
                    pinned: true,
                    bottom: _SearchStickyBottom(
                      tabController: _tabController,
                      currentFilter: currentFilter,
                      onFilterChanged: (filter) {
                        audioSignal.ytSearchFilter.value = filter;
                      },
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _ResultsList(
                    songs: localResults,
                    isSearching: isSearching,
                    query: query,
                    artDirPath: _artDirPath,
                    emptyMessage: 'No local songs found',
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
          ),
        ),
      );
    });
  }
}

class _SearchStickyBottom extends StatelessWidget implements PreferredSizeWidget {
  final TabController tabController;
  final SearchFilter? currentFilter;
  final ValueChanged<SearchFilter?> onFilterChanged;

  const _SearchStickyBottom({
    required this.tabController,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Size get preferredSize => Size.fromHeight(54.0 + (tabController.index == 1 ? 54.0 : 0.0));

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabBar(context),
          if (tabController.index == 1) _buildChips(context),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: tabController,
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
    );
  }

  Widget _buildChips(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: _filterOptions.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
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
    );
  }
}



/// Filter chip data
class _FilterOption {
  final String label;
  final SearchFilter? filter;
  final FaIconData icon;

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
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        ..._buildResultsSlivers(context),
        Watch((context) {
          final isLoading = audioSignal.isSearchingYoutube.value;
          final hasMore = audioSignal.hasMoreYtResults.value;
          if (!isLoading && !hasMore) return const SliverToBoxAdapter(child: SizedBox.shrink());
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
    if (widget.currentFilter == SearchFilter.songs || widget.currentFilter == null) {
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
        emptyMessage: isSearching ? 'No results found' : 'Start typing to search',
        itemBuilder: (context, item, index) {
          final title = item['title'] ??
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
              ? youtubeDatasource.transformThumbnail(thumbnails.last['url'] ?? '')
              : '';
          final isCircular = filterType == SearchFilter.artists;

          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(vertical: 4, horizontal: 24),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius:
                    isCircular ? BorderRadius.circular(24) : BorderRadius.circular(4),
                image: thumbnailUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(thumbnailUrl), fit: BoxFit.cover)
                    : null,
              ),
              child: thumbnailUrl.isEmpty
                  ? Center(
                      child: FaIcon(_getPlaceholderIcon(filterType),
                          size: 18,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.24)))
                  : null,
            ),
            title: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            subtitle: subtitle.isNotEmpty
                ? Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .secondary
                            .withValues(alpha: 0.7),
                        fontSize: 12))
                : null,
            onTap: () {
              if (filterType == SearchFilter.videos && item['videoId'] != null) {
                audioSignal.playSong(youtubeDatasource.mapToSong(item));
              } else if (filterType == SearchFilter.albums && item['browseId'] != null) {
                context.go(
                    '/youtube/album/${Uri.encodeComponent(item['browseId'])}',
                    extra: {'title': title, 'thumbnailUrl': thumbnailUrl});
              } else if (filterType == SearchFilter.artists &&
                  (item['browseId'] != null)) {
                context.go(
                    '/youtube/artist/${Uri.encodeComponent(item['browseId'])}',
                    extra: {'name': title, 'thumbnailUrl': thumbnailUrl});
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
                    extra: {'title': title, 'thumbnailUrl': thumbnailUrl});
              } else if (item['videoId'] != null) {
                audioSignal.playSong(youtubeDatasource.mapToSong(item));
              }
            },
          );
        },
      );
    });

    return [
      resultsWidget,
    ];
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
            contentPadding:
                const EdgeInsets.symmetric(vertical: 4, horizontal: 24),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
                image: isYoutube && hasArt
                    ? DecorationImage(
                        image: NetworkImage(ytThumbnailUrl!), fit: BoxFit.cover)
                    : hasArt
                        ? DecorationImage(
                            image: FileImage(File(artPath)), fit: BoxFit.cover)
                        : null,
              ),
              child: !hasArt
                  ? Center(
                      child: FaIcon(FontAwesomeIcons.music,
                          size: 18,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.24)))
                  : null,
            ),
            title: Text(song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            subtitle: Text(song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withValues(alpha: 0.7),
                    fontSize: 12)),
            trailing: Text(
                song.duration == null || song.duration == Duration.zero
                    ? '--:--'
                    : '${song.duration!.inMinutes}:${song.duration!.inSeconds.remainder(60).toString().padLeft(2, '0')}',
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.38),
                    fontSize: 12)),
            onTap: () => audioSignal.playSong(song),
          );
        },
      );
    });

    return [
      resultsWidget,
    ];
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

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        ..._ResultsSliverList.buildSlivers(
          context,
          songs: songs,
          isSearching: isSearching,
          query: query,
          artDirPath: artDirPath,
          emptyMessage: emptyMessage,
        ),
      ],
    );
  }
}
