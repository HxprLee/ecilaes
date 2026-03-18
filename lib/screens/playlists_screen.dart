import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';
import '../widgets/page_header.dart';
import '../widgets/playlist_dialogs.dart';

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
            const SliverToBoxAdapter(
              child: PageHeader(
                title: 'Playlists',
                subtitle: 'Your music collections',
              ),
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
                      title: 'Create Playlist',
                      icon: FontAwesomeIcons.plus,
                      isAction: true,
                      onTap: () => CreatePlaylistDialog.show(context),
                    );
                  }
                  final playlist = allPlaylists[index];
                  return _PlaylistCard(
                    title: playlist.name,
                    icon: playlist.id == 'favorites'
                        ? FontAwesomeIcons.solidHeart
                        : FontAwesomeIcons.list,
                    imagePath: playlist.imagePath,
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
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isAction;
  final String? imagePath;

  const _PlaylistCard({
    required this.title,
    required this.icon,
    required this.onTap,
    this.isAction = false,
    this.imagePath,
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
            child: Container(
              decoration: BoxDecoration(
                color: isAction
                    ? Theme.of(context).colorScheme.onSurface.withOpacity(0.05)
                    : Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isAction
                      ? Theme.of(context).colorScheme.onSurface.withOpacity(0.1)
                      : Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.15),
                ),
                image: imagePath != null
                    ? DecorationImage(
                        image: FileImage(File(imagePath!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: imagePath == null
                  ? Center(
                      child: FaIcon(
                        icon,
                        color: isAction
                            ? Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.38)
                            : Theme.of(context).colorScheme.secondary,
                        size: 48,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
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
