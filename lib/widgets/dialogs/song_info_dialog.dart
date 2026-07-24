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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import '../../models/song.dart';
import '../../signals/overlay_signal.dart';
import '../components/app_dialog.dart';
import 'edit_metadata_dialog.dart';

void showSongInfoDialog(BuildContext context, Song song) {
  overlaySignal.push(ActiveOverlay.songInfo);

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: AppDialog(
              titleIcon: Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.secondary,
                size: 24,
              ),
              title: 'Song info',
              maxWidth: 440,
              trailing: song.path.startsWith('yt:')
                  ? null
                  : IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        color: Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.6),
                        size: 14,
                      ),
                      tooltip: 'Edit info',
                      onPressed: () {
                        overlaySignal.pop(ActiveOverlay.songInfo);
                        Navigator.pop(context);
                        EditMetadataDialog.show(context, song: song);
                      },
                    ),
              trailingWidth: 0,
              content: SizedBox(
                height: 400,
                child: _SongInfoContent(song: song),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () {
                    overlaySignal.pop(ActiveOverlay.songInfo);
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.2),
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    'Close',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SongInfoContent extends StatelessWidget {
  final Song song;

  const _SongInfoContent({required this.song});

  Future<Map<String, String>> _fetchInfo() async {
    final info = <String, String>{};

    info['Title'] = song.title;
    info['Artist'] = song.artist;
    if (song.album != null) info['Album'] = song.album!;

    if (song.path.startsWith('yt:')) {
      info['Source'] = 'YouTube';
      info['Video ID'] = song.path.substring(3);
    } else {
      info['Source'] = 'Local File';
      final file = File(song.path);
      info['File Path'] = song.path;
      if (file.existsSync()) {
        final sizeBytes = file.lengthSync();
        final sizeMb = sizeBytes / (1024 * 1024);
        info['File Size'] = '${sizeMb.toStringAsFixed(2)} MB';

        try {
          final metadata = readMetadata(file, getImage: false);

          if (metadata.title != null) info['Title'] = metadata.title!;
          if (metadata.artist != null) info['Artist'] = metadata.artist!;
          if (metadata.album != null) info['Album'] = metadata.album!;

          if (metadata.year != null) info['Year'] = metadata.year.toString();

          if (metadata.genres.isNotEmpty) {
            info['Genre'] = metadata.genres.join(', ');
          }
          if (metadata.trackNumber != null) {
            info['Track Number'] = metadata.trackNumber.toString();
          }
          if (metadata.discNumber != null) {
            info['Disc Number'] = metadata.discNumber.toString();
          }
          if (metadata.duration != null) {
            final d = metadata.duration!;
            final mins = d.inMinutes;
            final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
            info['Duration'] = '$mins:$secs';
          }
          if (metadata.bitrate != null)
            info['Bitrate'] = '${(metadata.bitrate! / 1000).round()} kbps';
        } catch (e) {
          info['Error'] = 'Could not read detailed metadata';
        }
      }
    }

    return info;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _fetchInfo(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Error loading info',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }

        final info = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: info.length,
          itemBuilder: (context, index) {
            final key = info.keys.elementAt(index);
            final val = info.values.elementAt(index);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (index > 0)
                  Divider(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                    height: 1,
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        key,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        val,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
