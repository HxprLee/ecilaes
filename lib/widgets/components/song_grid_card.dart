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
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/song.dart';

class SongGridCard extends StatelessWidget {
  final Song song;
  final String? subtitle;
  final String artPath;
  final VoidCallback onTap;

  const SongGridCard({
    super.key,
    required this.song,
    this.subtitle,
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
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
                ),
                image: artPath.isNotEmpty && (song.hasAlbumArt || song.path.startsWith('yt:'))
                    ? DecorationImage(
                        image: song.path.startsWith('yt:')
                            ? NetworkImage(artPath)
                            : FileImage(File(artPath)) as ImageProvider,
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: !(artPath.isNotEmpty && (song.hasAlbumArt || song.path.startsWith('yt:')))
                  ? Center(
                      child: FaIcon(
                        FontAwesomeIcons.music,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
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
            color: Theme.of(context).colorScheme.secondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          subtitle ?? song.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
