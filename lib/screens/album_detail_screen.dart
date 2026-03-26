import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';
import '../models/song.dart';
import '../models/library_models.dart';
import '../widgets/sliver_page_header.dart';
import '../widgets/song_list_view.dart';
import '../widgets/song_actions_sheet.dart';
import '../widgets/song_tile.dart';

class AlbumDetailScreen extends StatefulWidget {
  final String albumName;
  final String artistName;

  const AlbumDetailScreen({
    super.key,
    required this.albumName,
    required this.artistName,
  });

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  @override
  void initState() {
    super.initState();
    _updateHeaderArt();
  }

  @override
  void dispose() {
    audioSignal.headerArtCover.value = null;
    super.dispose();
  }

  void _updateHeaderArt() {
    final albums = audioSignal.albums.value;
    final album = albums.firstWhere(
      (a) => a.name == widget.albumName && a.artist == widget.artistName,
      orElse: () => Album(name: widget.albumName, artist: widget.artistName, songs: []),
    );

    if (album.songs.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        audioSignal.headerArtCover.value = album.songs.first.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final albums = audioSignal.albums.value;
      final album = albums.firstWhere(
        (a) => a.name == widget.albumName && a.artist == widget.artistName,
        orElse: () => Album(name: widget.albumName, artist: widget.artistName, songs: []),
      );

      final artDir = audioSignal.albumArtDir.value;
      final artPath = album.songs.isNotEmpty 
          ? SongTile.getArtPath(album.firstSongPath, artDir)
          : '';

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            SliverPageHeader(
              title: album.name,
              subtitle: album.artist,
              leading: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  image: artPath.isNotEmpty && File(artPath).existsSync()
                      ? DecorationImage(
                          image: ResizeImage(FileImage(File(artPath)), width: 300),
                          fit: BoxFit.cover,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: artPath.isEmpty || !File(artPath).existsSync()
                    ? Center(
                        child: Icon(
                          Icons.album, 
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                        ),
                      )
                    : null,
              ),
            ),
            
            // Actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => audioSignal.playSong(album.songs.first, fromList: album.songs),
                      icon: const FaIcon(FontAwesomeIcons.play, size: 16),
                      label: const Text('Play'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.secondary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onSecondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        final shuffled = List<Song>.from(album.songs)..shuffle();
                        audioSignal.playSong(shuffled.first, fromList: shuffled);
                      },
                      icon: const FaIcon(FontAwesomeIcons.shuffle, size: 16),
                      label: const Text('Shuffle'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.2),
                        ),
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.secondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Track List
            SongListView(
              songs: album.songs,
              showIndex: true,
              trailingBuilder: (context, song, index) => IconButton(
                onPressed: () => showSongMoreActionsSheet(context: context, song: song),
                icon: FaIcon(
                  FontAwesomeIcons.ellipsisVertical, 
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
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
