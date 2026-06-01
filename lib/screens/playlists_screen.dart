import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';
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
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
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
