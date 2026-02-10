import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../signals/audio_signal.dart';

class PlaylistScreen extends StatelessWidget {
  final Playlist playlist;

  const PlaylistScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      // We need to find the current version of this playlist from the signal
      // because the one passed in the constructor might be stale
      final currentPlaylist = audioSignal.playlists.value.firstWhere(
        (p) => p.id == playlist.id,
        orElse: () => playlist,
      );

      final allSongs = audioSignal.allSongs.value;
      final songs = currentPlaylist.songPaths.map((path) {
        try {
          return allSongs.firstWhere((s) => s.path == path);
        } catch (_) {
          return Song.fromPath(path);
        }
      }).toList();

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.only(
                top:
                    24.0 +
                    ((Platform.isAndroid || Platform.isIOS)
                        ? (50.0 + MediaQuery.of(context).padding.top)
                        : 50.0),
                left: 24.0,
                right: 24.0,
                bottom: 24.0,
              ),
              child: Row(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.deepPurple, Colors.indigo],
                      ),
                    ),
                    child: const Center(
                      child: FaIcon(
                        FontAwesomeIcons.list,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'PLAYLIST',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          currentPlaylist.name,
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFCE7AC),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${songs.length} songs',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => audioSignal.playPlaylist(currentPlaylist),
                    icon: const FaIcon(FontAwesomeIcons.play, size: 16),
                    label: const Text('Play'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFCE7AC),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Playlist'),
                          content: Text(
                            'Are you sure you want to delete "${currentPlaylist.name}"?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                audioSignal.deletePlaylist(currentPlaylist.id);
                                Navigator.pop(context); // Close dialog
                                Navigator.pop(context); // Go back from screen
                              },
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const FaIcon(
                      FontAwesomeIcons.trash,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Song List
            Expanded(
              child: songs.isEmpty
                  ? const Center(
                      child: Text(
                        'This playlist is empty',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(
                        bottom: audioSignal.reservedHeight.value,
                      ),
                      itemCount: songs.length,
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        return ListTile(
                          leading: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white54),
                          ),
                          title: Text(
                            song.title,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            song.artist,
                            style: const TextStyle(color: Colors.white54),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.white24,
                            ),
                            onPressed: () => audioSignal.removeSongFromPlaylist(
                              currentPlaylist.id,
                              song.path,
                            ),
                          ),
                          onTap: () => audioSignal.playSong(song),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    });
  }
}
