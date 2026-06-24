// Ecilaes - Cross-platform music player
// Copyright (C) 2024  hxprlee
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';
import '../models/song.dart';
import 'components/app_dialog.dart';

class PlaylistPickerDialog extends StatelessWidget {
  final Song? song;
  final String? folderPath;

  const PlaylistPickerDialog({super.key, this.song, this.folderPath})
    : assert(song != null || folderPath != null);

  static void show(BuildContext context, {Song? song, String? folderPath}) {
    showDialog(
      context: context,
      builder: (dialogContext) =>
          PlaylistPickerDialog(song: song, folderPath: folderPath),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      titleIcon: Icon(
        Icons.playlist_add,
        color: Theme.of(context).colorScheme.secondary,
        size: 24,
      ),
      title: 'Add to playlist',
      maxHeight: 450,
      content: Watch((context) {
        final playlists = audioSignal.playlists.value;
        if (playlists.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'No playlists found',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.5),
                ),
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return ListTile(
              dense: true,
              leading: Icon(
                Icons.playlist_play,
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.7),
              ),
              title: Text(
                playlist.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              subtitle: Text(
                '${playlist.songPaths.length} songs',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
              onTap: () async {
                if (song != null) {
                  await audioSignal.addSongToPlaylist(playlist.id, song!.path);
                } else if (folderPath != null) {
                  await audioSignal.addFolderToPlaylist(
                    playlist.id,
                    folderPath!,
                  );
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added to ${playlist.name}'),
                      behavior: SnackBarBehavior.floating,
                      width: 300,
                    ),
                  );
                }
              },
            );
          },
        );
      }),
      actions: [
        FilledButton.icon(
          onPressed: () {
            CreatePlaylistDialog.show(
              context,
              song: song,
              folderPath: folderPath,
            );
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New playlist'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.8),
            foregroundColor: Theme.of(context).colorScheme.surface,
            shape: const StadiumBorder(),
          ),
        ),
      ],
    );
  }
}

class CreatePlaylistDialog extends StatefulWidget {
  final Song? song;
  final String? folderPath;

  const CreatePlaylistDialog({super.key, this.song, this.folderPath});

  static void show(BuildContext context, {Song? song, String? folderPath}) {
    showDialog(
      context: context,
      builder: (dialogContext) =>
          CreatePlaylistDialog(song: song, folderPath: folderPath),
    );
  }

  @override
  State<CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<CreatePlaylistDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      titleIcon: Icon(
        Icons.add_box_outlined,
        color: Theme.of(context).colorScheme.secondary,
        size: 24,
      ),
      title: 'New playlist',
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.secondary,
        ),
        decoration: InputDecoration(
          hintText: 'Playlist name',
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.4),
          ),
          filled: true,
          fillColor: Theme.of(
            context,
          ).colorScheme.secondary.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
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
          onPressed: () async {
            final name = _controller.text.trim();
            if (name.isNotEmpty) {
              try {
                final newPlaylist = await audioSignal.createPlaylist(name);
                if (widget.song != null) {
                  await audioSignal.addSongToPlaylist(
                    newPlaylist.id,
                    widget.song!.path,
                  );
                } else if (widget.folderPath != null) {
                  await audioSignal.addFolderToPlaylist(
                    newPlaylist.id,
                    widget.folderPath!,
                  );
                }
                if (context.mounted) {
                  Navigator.of(context).pop(); // Close create dialog
                  if (widget.song != null || widget.folderPath != null) {
                    // If we came from the picker, close it too.
                    // We use Navigator.of(context) again which is safe
                    // as long as the state is still mounted.
                    Navigator.of(context).pop(); // Close add dialog
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Created and added to $name'),
                      behavior: SnackBarBehavior.floating,
                      width: 300,
                    ),
                  );
                }
              } catch (e) {
                print('Error creating playlist: $e');
              }
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.8),
            foregroundColor: Theme.of(context).colorScheme.surface,
            shape: const StadiumBorder(),
          ),
          child: const Text('Create'),
        ),
      ],
    );
  }
}
