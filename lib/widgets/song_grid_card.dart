import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/song.dart';

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
