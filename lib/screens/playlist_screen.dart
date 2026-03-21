import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../signals/audio_signal.dart';
import '../widgets/page_header.dart';
import '../widgets/playlist_cover.dart';
import '../widgets/song_actions_sheet.dart';
import '../widgets/song_list_view.dart';

class PlaylistScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistScreen({super.key, required this.playlist});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      audioSignal.headerArtCover.value = widget.playlist.imagePath;
    });
  }

  @override
  void dispose() {
    audioSignal.headerArtCover.value = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      // We need to find the current version of this playlist from the signal
      // because the one passed in the constructor might be stale
      final currentPlaylist = audioSignal.playlists.value.firstWhere(
        (p) => p.id == widget.playlist.id,
        orElse: () => widget.playlist,
      );

      // Update header art in case it changed (e.g. user set a new cover)
      if (audioSignal.headerArtCover.value != currentPlaylist.imagePath) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            audioSignal.headerArtCover.value = currentPlaylist.imagePath;
          }
        });
      }

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
        body: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: PageHeader(
                title: currentPlaylist.name,
                subtitle: '${songs.length} songs',
                leading: PlaylistCover(
                  playlist: currentPlaylist,
                  width: 140,
                  height: 140,
                  borderRadius: 12,
                ),
              ),
            ),

            // Action Buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () =>
                          audioSignal.playPlaylist(currentPlaylist),
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
                      onPressed: () => audioSignal.playPlaylist(
                        currentPlaylist,
                        shuffle: true,
                      ),
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
                    const Spacer(),
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'change_cover') {
                          const typeGroup = XTypeGroup(
                            label: 'images',
                            extensions: <String>['jpg', 'jpeg', 'png'],
                          );
                          final file = await openFile(
                            acceptedTypeGroups: <XTypeGroup>[typeGroup],
                          );
                          if (file != null) {
                            await audioSignal.setPlaylistCover(
                              currentPlaylist.id,
                              file.path,
                            );
                          }
                        } else if (value == 'delete') {
                          showDialog(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Delete Playlist'),
                              content: Text(
                                'Are you sure you want to delete "${currentPlaylist.name}"?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(dialogContext); // Close dialog
                                    context.go('/playlists'); // Go back from screen safely
                                    audioSignal.deletePlaylist(
                                      currentPlaylist.id,
                                    );
                                  },
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'change_cover',
                          child: Row(
                            children: [
                              Icon(Icons.image_outlined, size: 20),
                              SizedBox(width: 12),
                              Text('Change Cover'),
                            ],
                          ),
                        ),
                        if (currentPlaylist.id != 'favorites')
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Delete Playlist',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: FaIcon(
                          FontAwesomeIcons.ellipsisVertical,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.54),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Song List
            SongListView(
              songs: songs,
              showIndex: false,
              trailingBuilder: (context, song, index) {
                return IconButton(
                  onPressed: () {
                    showSongMoreActionsSheet(
                      context: context,
                      song: song,
                      playlistId: currentPlaylist.id,
                    );
                  },
                  icon: FaIcon(
                    FontAwesomeIcons.ellipsisVertical,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.38),
                    size: 16,
                  ),
                );
              },
              emptyMessage: 'This playlist is empty',
              playlistId: currentPlaylist.id,
            ),
          ],
        ),
      );
    });
  }
}
