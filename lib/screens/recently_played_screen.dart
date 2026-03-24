import 'dart:io';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../signals/audio_signal.dart';
import '../services/song_cache.dart';
import '../models/song.dart';
import '../widgets/page_header.dart';
import '../widgets/song_list_view.dart';
import '../widgets/song_tile.dart';

class RecentlyPlayedScreen extends StatefulWidget {
  const RecentlyPlayedScreen({super.key});

  @override
  State<RecentlyPlayedScreen> createState() => _RecentlyPlayedScreenState();
}

class _RecentlyPlayedScreenState extends State<RecentlyPlayedScreen> {
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

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (diff.inDays >= 1) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes >= 1) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Watch((context) {
        final history = audioSignal.historySongs.value;
        final songs = audioSignal.allSongs.value;
        final isGrid = audioSignal.isHistoryGridView.value;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: 'Recently Played',
                actions: [
                  IconButton(
                    onPressed: () =>
                        audioSignal.isHistoryGridView.value = !isGrid,
                    icon: FaIcon(
                      isGrid
                          ? FontAwesomeIcons.list
                          : FontAwesomeIcons.borderAll,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            if (history.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No songs played yet',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.54),
                    ),
                  ),
                ),
              )
            else if (isGrid)
              SliverMainAxisGroup(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            mainAxisSpacing: 24,
                            crossAxisSpacing: 24,
                            childAspectRatio: 0.75,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final entry = history[index];
                        final song = songs.firstWhere(
                          (s) => s.path == entry.songPath,
                          orElse: () => Song.fromPath(entry.songPath),
                        );

                        return _GridSongCard(
                          song: song,
                          playCount: entry.playCount,
                          artPath: SongTile.getArtPath(song.path, _artDirPath),
                          onTap: () => audioSignal.playSong(song),
                        );
                      }, childCount: history.length),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Watch(
                      (context) =>
                          SizedBox(height: audioSignal.reservedHeight.value),
                    ),
                  ),
                ],
              )
            else
              SongListView(
                songs: history
                    .map(
                      (entry) => songs.firstWhere(
                        (s) => s.path == entry.songPath,
                        orElse: () => Song.fromPath(entry.songPath),
                      ),
                    )
                    .toList(),
                emptyMessage: 'No songs played yet',
                trailingBuilder: (context, song, index) {
                  final entry = history[index];
                  return Text(
                    _formatRelativeTime(entry.lastPlayed),
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.38),
                      fontSize: 12,
                    ),
                  );
                },
              ),
          ],
        );
      }),
    );
  }
}

class _GridSongCard extends StatelessWidget {
  final Song song;
  final int playCount;
  final String artPath;
  final VoidCallback onTap;

  const _GridSongCard({
    required this.song,
    required this.playCount,
    required this.artPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.0,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.15),
                ),
                image: artPath.isNotEmpty && song.hasAlbumArt
                    ? DecorationImage(
                        image: FileImage(File(artPath)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: !(artPath.isNotEmpty && song.hasAlbumArt)
                  ? Center(
                      child: FaIcon(
                        FontAwesomeIcons.music,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.24),
                        size: 48,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '${song.artist} • $playCount plays',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
