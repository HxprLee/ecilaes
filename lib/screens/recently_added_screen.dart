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

class RecentlyAddedScreen extends StatefulWidget {
  const RecentlyAddedScreen({super.key});

  @override
  State<RecentlyAddedScreen> createState() => _RecentlyAddedScreenState();
}

class _RecentlyAddedScreenState extends State<RecentlyAddedScreen> {
  String? _artDirPath;
  final _isGridView = signal<bool>(false);

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

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Watch((context) {
        final recentAdded = audioSignal.recentlyAdded.value;
        final isGrid = _isGridView.value;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: 'Recently Added',
                showBackButton: true,
                actions: [
                  IconButton(
                    onPressed: () => _isGridView.value = !isGrid,
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
            if (recentAdded.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No recently added songs',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.54),
                    ),
                  ),
                ),
              )
            else if (isGrid)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 24,
                    childAspectRatio: 0.75,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final song = recentAdded[index];

                    return _GridSongCard(
                      song: song,
                      artPath: SongTile.getArtPath(song.path, _artDirPath),
                      onTap: () => audioSignal.playSong(song),
                    );
                  }, childCount: recentAdded.length),
                ),
              )
            else
              SongListView(
                songs: recentAdded,
                emptyMessage: 'No recently added songs',
              ),
          ],
        );
      }),
    );
  }
}

class _GridSongCard extends StatelessWidget {
  final Song song;
  final String artPath;
  final VoidCallback onTap;

  const _GridSongCard({
    required this.song,
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
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          song.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
