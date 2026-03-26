import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../signals/audio_signal.dart';
import '../widgets/app_dialog.dart';
import '../widgets/sliver_page_header.dart';
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

      final screenWidth = MediaQuery.sizeOf(context).width;
      final isSmallScreen = screenWidth < 600;

      final playButton = ElevatedButton.icon(
        onPressed: () => audioSignal.playPlaylist(currentPlaylist),
        icon: const FaIcon(FontAwesomeIcons.play, size: 16),
        label: const Text('Play'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.secondary,
          foregroundColor: Theme.of(context).colorScheme.onSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      );

      final shuffleButton = OutlinedButton.icon(
        onPressed: () => audioSignal.playPlaylist(currentPlaylist, shuffle: true),
        icon: const FaIcon(FontAwesomeIcons.shuffle, size: 16),
        label: const Text('Shuffle'),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
          ),
          foregroundColor: Theme.of(context).colorScheme.secondary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      );

      final moreOptionsMenu = PopupMenuButton<String>(
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
              await audioSignal.setPlaylistCover(currentPlaylist.id, file.path);
            }
          } else if (value == 'delete') {
            showDialog(
              context: context,
              builder: (dialogContext) => AppDialog(
                titleIcon: const Icon(Icons.delete_outline, color: Colors.red),
                title: 'Delete Playlist',
                content: Text(
                  'Are you sure you want to delete "${currentPlaylist.name}"?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                ),
                actions: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.2),
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      'Cancel',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                    ),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(dialogContext); // Close dialog
                      context.go('/playlists'); // Go back from screen safely
                      audioSignal.deletePlaylist(currentPlaylist.id);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Delete'),
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
                  Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  SizedBox(width: 12),
                  Text('Delete Playlist', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.all(8),
          child: FaIcon(
            FontAwesomeIcons.ellipsisVertical,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
            size: 20,
          ),
        ),
      );

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            // Header
            SliverPageHeader(
              title: currentPlaylist.name,
              subtitle: '${songs.length} songs',
              leading: PlaylistCover(
                playlist: currentPlaylist,
                width: isSmallScreen ? 120 : 140,
                height: isSmallScreen ? 120 : 140,
                borderRadius: 12,
              ),
              topActions: isSmallScreen ? [moreOptionsMenu] : null,
              underTextActions: isSmallScreen
                  ? [
                    ElevatedButton.icon(
                      onPressed: () =>
                          audioSignal.playPlaylist(currentPlaylist),
                      icon: const FaIcon(FontAwesomeIcons.play, size: 14),
                      label: const Text('Play'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.secondary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onSecondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        shape: const StadiumBorder(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => audioSignal.playPlaylist(
                        currentPlaylist,
                        shuffle: true,
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: FaIcon(
                        FontAwesomeIcons.shuffle,
                        size: 14,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ]
                  : null,
              actions: isSmallScreen ? null : null, // Handled by Sliver below for desktop
            ),

            // Action Buttons (Desktop only or custom mobile row)
            if (!isSmallScreen)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      playButton,
                      const SizedBox(width: 12),
                      shuffleButton,
                      const Spacer(),
                      moreOptionsMenu,
                    ],
                  ),
                ),
              ),

            if (!isSmallScreen)
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
