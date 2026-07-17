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
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:signals/signals_flutter.dart';
import '../router/routes.dart';
import '../signals/audio_signal.dart';
import '../signals/settings_signal.dart';
import '../theme/app_theme_style.dart';
import '../utils/navigation.dart';
import '../widgets/components/sliver_page_header.dart';
import '../widgets/playlist_dialogs.dart';
import '../widgets/components/playlist_cover.dart';
import '../widgets/components/standard_sliver_list.dart';
import '../widgets/components/standard_sliver_grid.dart';
import '../widgets/components/grid_card.dart';
import '../models/playlist.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final allPlaylists = audioSignal.playlists.value;
      final isGrid = audioSignal.isPlaylistsGridView.value;

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            // Header
            SliverPageHeader(
              title: 'Playlists',
              subtitle: 'Your music collections',
              actions: [
                IconButton(
                  onPressed: () =>
                      audioSignal.isPlaylistsGridView.value = !isGrid,
                  icon: FaIcon(
                    isGrid ? FontAwesomeIcons.list : FontAwesomeIcons.borderAll,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 18,
                  ),
                ),
              ],
            ),

            if (isGrid)
              StandardSliverGrid<Playlist>(
                items: allPlaylists,
                leadingItems: [
                  GridCard(
                    title: 'Create Playlist',
                    image: PlaylistCover(
                      playlist: Playlist(
                        id: 'create',
                        name: 'Create Playlist',
                        songPaths: [],
                        createdAt: DateTime.now(),
                      ),
                      borderRadius: 12,
                      iconOverride: FontAwesomeIcons.plus,
                    ),
                    onTap: () => CreatePlaylistDialog.show(context),
                  ),
                ],
                itemBuilder: (context, playlist, index) {
                  return GridCard(
                    title: playlist.name,
                    subtitle: '${playlist.songPaths.length} songs',
                    image: PlaylistCover(
                      playlist: playlist,
                      borderRadius: 12,
                      iconOverride: playlist.id == 'favorites'
                          ? FontAwesomeIcons.solidHeart
                          : FontAwesomeIcons.list,
                    ),
                    onTap: () => navigateGo(context, '${AppRoutes.playlists}/${playlist.id}'),
                  );
                },
              )
            else
              StandardSliverList<Playlist>(
                items: allPlaylists,
                emptyMessage: 'No playlists found',
                leadingItems: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: _buildIconBackground(context),
                      ),
                      child: Center(
                        child: FaIcon(
                          FontAwesomeIcons.plus,
                          color: Theme.of(context).colorScheme.secondary,
                          size: 20,
                        ),
                      ),
                    ),
                    title: Text(
                      'Create Playlist',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () => CreatePlaylistDialog.show(context),
                  ),
                ],
                itemBuilder: (context, playlist, index) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    leading: PlaylistCover(
                      playlist: playlist,
                      width: 48,
                      height: 48,
                      borderRadius: 8,
                      iconOverride: playlist.id == 'favorites'
                          ? FontAwesomeIcons.solidHeart
                          : FontAwesomeIcons.list,
                    ),
                    title: Text(
                      playlist.name,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '${playlist.songPaths.length} songs',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.38),
                    ),
                    onTap: () => navigateGo(context, '${AppRoutes.playlists}/${playlist.id}'),
                  );
                },
              ),

            // Bottom spacing for player
            SliverToBoxAdapter(
              child: SizedBox(height: audioSignal.reservedHeight.value),
            ),
          ],
        ),
      );
    });
  }

  static Color _buildIconBackground(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    if (settingsSignal.themeStyle.value == AppThemeStyle.signature) {
      return Color.lerp(surface, Colors.white, 0.05)!;
    }
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }
}
