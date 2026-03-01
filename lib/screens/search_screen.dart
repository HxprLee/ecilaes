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

  String _getArtPath(String songPath) {
    if (_artDirPath == null) return '';
    final fileName = '${songPath.hashCode.abs()}.jpg';
    return '$_artDirPath/$fileName';
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final searchResults = audioSignal.searchResults.value;
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
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: PageHeader(
                    title: isSearching
                        ? 'Search results for "$query"'
                        : 'Search',
                    subtitle: '${searchResults.length} songs found',
                  ),
                ),

                // Results List
                if (searchResults.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FaIcon(
                            isSearching
                                ? FontAwesomeIcons.magnifyingGlass
                                : FontAwesomeIcons.music,
                            size: 48,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.1),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isSearching
                                ? 'No results found for "$query"'
                                : 'Start typing to search',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.24),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SuperSliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final song = searchResults[index];
                      final isCurrent =
                          audioSignal.currentSong.value?.path == song.path;
                      final artPath = _getArtPath(song.path);
                      final hasArt = song.hasAlbumArt && artPath.isNotEmpty;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 24,
                        ),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                            image: hasArt
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
                                    ).colorScheme.onSurface.withOpacity(0.24),
                                  ),
                                )
                              : null,
                        ),
                        title: Text(
                          song.title,
                          style: TextStyle(
                            color: isCurrent
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          song.artist,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.54),
                          ),
                        ),
                        trailing: Text(
                          _formatDuration(song.duration ?? Duration.zero),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.38),
                            fontSize: 12,
                          ),
                        ),
                        onTap: () => audioSignal.playSong(song),
                      );
                    }, childCount: searchResults.length),
                  ),
                // Bottom padding for player bar
                SliverToBoxAdapter(
                  child: SizedBox(height: audioSignal.reservedHeight.value),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '--:--';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${twoDigits(seconds)}';
  }
}
