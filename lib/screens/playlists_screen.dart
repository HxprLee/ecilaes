import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';
import '../widgets/sliver_page_header.dart';
import '../widgets/playlist_dialogs.dart';
import '../widgets/playlist_cover.dart';
import '../models/playlist.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final allPlaylists = audioSignal.playlists.value;

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            // Header
            const SliverPageHeader(
              title: 'Playlists',
              subtitle: 'Your music collections',
            ),

            // Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index == allPlaylists.length) {
                    return _PlaylistCard(
                      playlist: Playlist(
                        id: 'create',
                        name: 'Create Playlist',
                        songPaths: [],
                        createdAt: DateTime.now(),
                      ),
                      icon: FontAwesomeIcons.plus,
                      isAction: true,
                      onTap: () => CreatePlaylistDialog.show(context),
                    );
                  }
                  final playlist = allPlaylists[index];
                  return _PlaylistCard(
                    playlist: playlist,
                    icon: playlist.id == 'favorites'
                        ? FontAwesomeIcons.solidHeart
                        : FontAwesomeIcons.list,
                    onTap: () => context.go('/playlist/${playlist.id}'),
                  );
                }, childCount: allPlaylists.length + 1),
              ),
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
