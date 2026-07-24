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
import 'package:audio_service/audio_service.dart';
import '../../models/song.dart';
import '../../signals/audio_signal.dart';
import '../../services/album_art_cache.dart';
import '../../services/YoutubeDatasource.dart';

/// Sticky "Now playing" row at the top of the Up Next section. Renders the
/// current song with a mini-player style: artwork + title + artist + a small
/// "NOW PLAYING" badge, plus an optional repeat indicator chip.
class NowPlayingRow extends StatelessWidget {
  final Song song;

  /// When true, tapping the row collapses/minimizes the queue sheet
  /// (mobile) or minimizes the expanded player (desktop). Currently unused;
  /// the row is non-interactive.
  final bool tappable;

  const NowPlayingRow({
    super.key,
    required this.song,
    this.tappable = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SignalBuilder(builder: (context) {
      final repeatMode = audioSignal.repeatMode.value;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _Artwork(song: song, size: 48),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.equalizer,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'NOW PLAYING',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          fontSize: 10,
                        ),
                      ),
                      if (repeatMode != AudioServiceRepeatMode.none) ...[
                        const SizedBox(width: 8),
                        _RepeatChip(mode: repeatMode),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.secondary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _RepeatChip extends StatelessWidget {
  final AudioServiceRepeatMode mode;
  const _RepeatChip({required this.mode});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOne = mode == AudioServiceRepeatMode.one;
    return InkWell(
      onTap: () => audioSignal.toggleRepeat(),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOne ? Icons.repeat_one : Icons.repeat,
              size: 11,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 3),
            Text(
              isOne ? 'Repeat one' : 'Repeat all',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  final Song song;
  final double size;

  const _Artwork({required this.song, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[800],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildImage(context),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    final fallbackIcon = Icon(
      Icons.music_note,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
      size: size * 0.5,
    );
    if (!song.hasAlbumArt) return fallbackIcon;
    if (song.path.startsWith('yt:')) {
      final url = youtubeDatasource.getSongArtworkUrl(song);
      return Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: (size * 2).toInt(),
        cacheHeight: (size * 2).toInt(),
        errorBuilder: (_, _, _) => fallbackIcon,
      );
    }
    final known = audioSignal.songMap.value[song.path];
    if (known == null) {
      final cachedPath = AlbumArtCache().getArtPathSync(song.path);
      if (cachedPath == null) return fallbackIcon;
      return Image.file(
        File(cachedPath),
        fit: BoxFit.cover,
        cacheWidth: (size * 2).toInt(),
        cacheHeight: (size * 2).toInt(),
        errorBuilder: (_, _, _) => fallbackIcon,
      );
    }
    final artDir = audioSignal.albumArtDir.value;
    if (artDir == null) return fallbackIcon;
    return Image.file(
      File('$artDir/${song.path.hashCode.abs()}.jpg'),
      fit: BoxFit.cover,
      cacheWidth: (size * 2).toInt(),
      cacheHeight: (size * 2).toInt(),
      errorBuilder: (_, _, _) => fallbackIcon,
    );
  }
}
