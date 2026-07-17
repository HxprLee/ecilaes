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
import '../signals/audio_signal.dart';
import '../models/library_models.dart';
import '../utils/navigation.dart';
import '../widgets/components/standard_sliver_list.dart';
import '../widgets/components/standard_sliver_grid.dart';
import '../widgets/components/song_tile.dart';
import '../widgets/components/sliver_page_header.dart';

class AlbumsScreen extends StatelessWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final albums = audioSignal.albums.value;
      final artDir = audioSignal.albumArtDir.value;
      final isGrid = audioSignal.isAlbumsGridView.value;

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            SliverPageHeader(
              title: 'Albums',
              subtitle: '${albums.length} albums',
              actions: [
                IconButton(
                  onPressed: () => audioSignal.isAlbumsGridView.value = !isGrid,
                  icon: FaIcon(
                    isGrid ? FontAwesomeIcons.list : FontAwesomeIcons.borderAll,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 18,
                  ),
                ),
              ],
            ),
            if (isGrid)
              StandardSliverGrid<Album>(
                items: albums,
                childAspectRatio: 0.8,
                itemBuilder: (context, album, index) {
                  final artPath = SongTile.getArtPath(album.firstSongPath, artDir);
                  return GestureDetector(
                    onTap: () => navigateGo(
                      context,
                      '/albums/${Uri.encodeComponent(album.artist)}/${Uri.encodeComponent(album.name)}',
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              image: album.hasAlbumArt
                                  ? DecorationImage(
                                      image: FileImage(File(artPath)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: !album.hasAlbumArt
                                ? Center(
                                    child: Icon(
                                      Icons.album,
                                      size: 48,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          album.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          album.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )
            else
              StandardSliverList<Album>(
                items: albums,
                emptyMessage: 'No albums found',
                itemBuilder: (context, album, index) {
                  final artPath = SongTile.getArtPath(album.firstSongPath, artDir);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 24,
                    ),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        image: album.hasAlbumArt
                            ? DecorationImage(
                                image: FileImage(File(artPath)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: !album.hasAlbumArt
                          ? Center(
                              child: Icon(
                                Icons.album,
                                size: 24,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      album.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '${album.artist} • ${album.songCount} songs',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                    ),
                    onTap: () => navigateGo(
                      context,
                      '/albums/${Uri.encodeComponent(album.artist)}/${Uri.encodeComponent(album.name)}',
                    ),
                  );
                },
              ),
          ],
        ),
      );
    });
  }
}
