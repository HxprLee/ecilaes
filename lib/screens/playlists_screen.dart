// Ecilaes - Cross-platform music player
// Copyright (C) 2024  Anton Borri
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
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';
import '../signals/settings_signal.dart';
import '../theme/app_theme_style.dart';
import '../widgets/sliver_page_header.dart';
import '../widgets/playlist_dialogs.dart';
import '../widgets/playlist_cover.dart';
import '../widgets/standard_sliver_list.dart';
import '../widgets/standard_sliver_grid.dart';
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
                childAspectRatio: 0.85,
                leadingItems: [
                  _PlaylistCard(
                    playlist: Playlist(
                      id: 'create',
                      name: 'Create Playlist',
                      songPaths: [],
                      createdAt: DateTime.now(),
                    ),
                    icon: FontAwesomeIcons.plus,
                    isAction: true,
                    onTap: () => CreatePlaylistDialog.show(context),
                  ),
                ],
                itemBuilder: (context, playlist, index) {
                  return _PlaylistCard(
                    playlist: playlist,
                    icon: playlist.id == 'favorites'
                        ? FontAwesomeIcons.solidHeart
                        : FontAwesomeIcons.list,
                    onTap: () => context.go('/playlist/${playlist.id}'),
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
                    onTap: () => context.go('/playlist/${playlist.id}'),
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

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final FaIconData icon;
  final VoidCallback onTap;
  final bool isAction;

  const _PlaylistCard({
    required this.playlist,
    required this.icon,
    required this.onTap,
    this.isAction = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: PlaylistCover(
              playlist: playlist,
              borderRadius: 12,
              iconOverride: icon,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          playlist.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
