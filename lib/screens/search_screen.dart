import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:signals/signals_flutter.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../signals/audio_signal.dart';
import '../signals/navigation_signal.dart';
import '../services/song_cache.dart';
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
        final query = audioSignal.searchQuery.value;
        final isSearching = query.isNotEmpty;

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
                        ? '${localResults.length} local, ${youtubeResults.length} youtube'
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
                        _ResultsList(
                          songs: youtubeResults,
                          isSearching: isSearching,
                          query: query,
                          artDirPath: _artDirPath,
                          emptyMessage: 'No YouTube results found',
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
                ? 'https://img.youtube.com/vi/${song.path.substring(3)}/hqdefault.jpg'
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
