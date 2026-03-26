import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';
import '../widgets/sliver_page_header.dart';
import '../widgets/song_tile.dart';

class AlbumsScreen extends StatelessWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final albums = audioSignal.albums.value;
      final artDir = audioSignal.albumArtDir.value;

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            SliverPageHeader(
              title: 'Albums',
              subtitle: '${albums.length} albums',
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 24,
                  childAspectRatio: 0.8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final album = albums[index];
                    final artPath = SongTile.getArtPath(album.firstSongPath, artDir);
                    
                    return GestureDetector(
                      onTap: () => context.go('/albums/${Uri.encodeComponent(album.artist)}/${Uri.encodeComponent(album.name)}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                image: album.hasAlbumArt
                                    ? DecorationImage(
                                        image: FileImage(File(artPath)),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: !album.hasAlbumArt
                                  ? Center(
                                      child: Icon(
                                        Icons.album,
                                        size: 48,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            album.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            album.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: albums.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: audioSignal.reservedHeight.value),
            ),
          ],
        ),
      );
    });
  }
}
