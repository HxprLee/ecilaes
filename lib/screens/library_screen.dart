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
import '../utils/navigation.dart';
import '../widgets/components/sliver_page_header.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            // Header
            const SliverPageHeader(title: 'Library', subtitle: 'Local library'),

            // Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 24,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildListDelegate([
                  _CategoryCard(
                    title: 'Favorites',
                    icon: FontAwesomeIcons.solidHeart,
                    onTap: () => navigateGo(context, '${AppRoutes.playlists}/favorites'),
                  ),
                  _CategoryCard(
                    title: 'Most Played',
                    icon: FontAwesomeIcons.fireFlameCurved,
                    onTap: () => navigateGo(context, AppRoutes.mostPlayed),
                  ),
                  _CategoryCard(
                    title: 'Recently Played',
                    icon: FontAwesomeIcons.clockRotateLeft,
                    onTap: () => navigateGo(context, AppRoutes.recentlyPlayed),
                  ),
                  _CategoryCard(
                    title: 'Albums',
                    icon: FontAwesomeIcons.compactDisc,
                    onTap: () => navigateGo(context, AppRoutes.albums),
                  ),
                  _CategoryCard(
                    title: 'Songs',
                    icon: FontAwesomeIcons.music,
                    onTap: () => navigateGo(context, AppRoutes.songs),
                  ),
                  _CategoryCard(
                    title: 'Playlists',
                    icon: FontAwesomeIcons.list,
                    onTap: () => navigateGo(context, AppRoutes.playlists),
                  ),
                  _CategoryCard(
                    title: 'Artists',
                    icon: FontAwesomeIcons.user,
                    onTap: () => navigateGo(context, AppRoutes.artists),
                  ),
                  _CategoryCard(
                    title: 'Downloaded',
                    icon: FontAwesomeIcons.circleCheck,
                    onTap: () => navigateGo(context, AppRoutes.explorer),
                  ),
                  _CategoryCard(
                    title: 'Folders',
                    icon: FontAwesomeIcons.solidFolder,
                    onTap: () => navigateGo(context, AppRoutes.explorer),
                  ),
                ]),
              ),
            ),

            // Bottom spacing for player
            SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),

            const SliverPageHeader(title: 'YouTube Music', subtitle: 'Saved from YouTube'),

            // YouTube Grid
            Watch((context) {
              final hasCookie = settingsSignal.ytAuthCookie.value != null && settingsSignal.ytAuthCookie.value!.isNotEmpty;
              
              if (!hasCookie) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Center(
                      child: Column(
                        children: [
                          FaIcon(FontAwesomeIcons.youtube, size: 48, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text(
                            'Connect your account in Settings to access your YouTube Music library.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => navigateGo(context, AppRoutes.library),
                            child: const Text('Go to Settings'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 24,
                    childAspectRatio: 0.85,
                  ),
                  delegate: SliverChildListDelegate([
                    _CategoryCard(
                      title: 'Liked Songs',
                      icon: FontAwesomeIcons.solidThumbsUp,
                      onTap: () => navigateGo(context, AppRoutes.ytPlaylistLM),
                    ),
                    _CategoryCard(
                      title: 'Playlists',
                      icon: FontAwesomeIcons.list,
                      onTap: () => navigateGo(context, AppRoutes.ytLibraryPlaylists),
                    ),
                    _CategoryCard(
                      title: 'Albums',
                      icon: FontAwesomeIcons.compactDisc,
                      onTap: () => navigateGo(context, AppRoutes.ytLibraryAlbums),
                    ),
                    _CategoryCard(
                      title: 'Artists',
                      icon: FontAwesomeIcons.user,
                      onTap: () => navigateGo(context, AppRoutes.ytLibraryArtists),
                    ),
                  ]),
                ),
              );
            }),

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

class _CategoryCard extends StatelessWidget {
  final String title;
  final FaIconData icon;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.icon,
    required this.onTap,
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
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.15),
                ),
              ),
              child: Center(
                child: FaIcon(
                  icon,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
