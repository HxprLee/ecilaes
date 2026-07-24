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
import 'package:signals/signals_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/song.dart';
import '../../signals/audio_signal.dart';
import '../song_actions_sheet.dart';
import '../../services/YoutubeDatasource.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final int? index;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? playlistId;
  final List<Song>? fromList;
  /// Override the art directory path (used by callers that don't have access to
  /// audioSignal.albumArtDir, e.g. search tabs).
  final String? artDirPath;

  const SongTile({
    super.key,
    required this.song,
    this.index,
    this.trailing,
    this.onTap,
    this.playlistId,
    this.fromList,
    this.artDirPath,
  });

  static String getArtPath(String songPath, String? artDirPath) {
    if (artDirPath == null) return '';
    final fileName = '${songPath.hashCode.abs()}.jpg';
    return '$artDirPath/$fileName';
  }


  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '--:--';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(builder: (context) {
      final isCurrent = audioSignal.currentSong.value?.path == song.path;
      final artDir = artDirPath ?? audioSignal.albumArtDir.value;
      final isYoutube = song.path.startsWith('yt:');
      final hasArt = song.hasAlbumArt && (artDir != null || isYoutube);
      final artPath = hasArt && !isYoutube ? SongTile.getArtPath(song.path, artDir) : '';
      final ytThumbnailUrl = isYoutube ? youtubeDatasource.getSongArtworkUrl(song) : null;

      return ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 24),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index != null)
              Container(
                width: 32,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${index! + 1}',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.38),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                image: isYoutube && hasArt
                    ? DecorationImage(
                        image: NetworkImage(ytThumbnailUrl!),
                        fit: BoxFit.cover,
                      )
                    : hasArt && !isYoutube
                        ? DecorationImage(
                            image: FileImage(
                              File(artPath),
                            ),
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
                        ).colorScheme.onSurface.withValues(alpha: 0.24),
                      ),
                    )
                  : null,
            ),
          ],
        ),
        title: Text(
          song.title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          song.artist,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.7),
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing:
            trailing ??
            Text(
              _formatDuration(song.duration ?? Duration.zero),
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.38),
                fontSize: 12,
              ),
            ),
        onTap: onTap ?? () {
          if (playlistId != null) {
            final playlist = audioSignal.playlists.value.firstWhere((p) => p.id == playlistId);
            final resolvedSongs = playlist.songPaths.map(audioSignal.resolveSong).toList();
            audioSignal.playSong(song, fromList: resolvedSongs);
          } else {
            audioSignal.playSong(song, fromList: fromList);
          }
        },
        onLongPress: () {
          showSongMoreActionsSheet(
            context: context,
            song: song,
            playlistId: playlistId,
          );
        },
      );
    });
  }
}
