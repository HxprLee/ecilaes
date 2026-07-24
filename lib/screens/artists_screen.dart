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
import 'package:signals/signals_flutter.dart';
import '../router/routes.dart';
import '../signals/audio_signal.dart';
import '../utils/navigation.dart';
import '../widgets/components/sliver_page_header.dart';
import '../widgets/components/standard_sliver_list.dart';
import '../widgets/components/standard_sliver_grid.dart';
import '../models/library_models.dart';

class ArtistsScreen extends StatelessWidget {
  const ArtistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(builder: (context) {
      final artists = audioSignal.artists.value;
      final isGrid = audioSignal.isArtistsGridView.value;

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            SliverPageHeader(
              title: 'Artists',
              subtitle: '${artists.length} artists',
              actions: [
                IconButton(
                  onPressed: () => audioSignal.isArtistsGridView.value = !isGrid,
                  icon: FaIcon(
                    isGrid ? FontAwesomeIcons.list : FontAwesomeIcons.borderAll,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 18,
                  ),
                ),
              ],
            ),
            if (isGrid)
              StandardSliverGrid<Artist>(
                items: artists,
                childAspectRatio: 0.8,
                itemBuilder: (context, artist, index) {
                  return GestureDetector(
                    onTap: () => navigatePush(
                      context,
                      '/artists/${Uri.encodeComponent(artist.name)}',
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              image: artist.picturePath != null
                                  ? DecorationImage(
                                      image: FileImage(File(artist.picturePath!)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: artist.picturePath == null
                                ? Center(
                                    child: FaIcon(
                                      FontAwesomeIcons.user,
                                      size: 32,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            artist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            '${artist.songCount} songs',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )
            else
              StandardSliverList<Artist>(
                items: artists,
                emptyMessage: 'No artists found',
                itemBuilder: (context, artist, index) {
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 24,
                  ),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      image: artist.picturePath != null
                          ? DecorationImage(
                              image: FileImage(File(artist.picturePath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: artist.picturePath == null
                        ? Center(
                            child: FaIcon(
                              FontAwesomeIcons.user,
                              size: 18,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    artist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    '${artist.songCount} songs • ${artist.albums.length} albums',
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
                  onTap: () => navigatePush(context, '${AppRoutes.artists}/${Uri.encodeComponent(artist.name)}'),
                );
              },
            ),
          ],
        ),
      );
    });
  }
}
