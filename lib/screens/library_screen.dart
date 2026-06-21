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
import '../widgets/sliver_page_header.dart';

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
                    onTap: () => context.go('/playlist/favorites'),
                  ),
                  _CategoryCard(
                    title: 'Albums',
                    icon: FontAwesomeIcons.compactDisc,
                    onTap: () => context.go('/albums'),
                  ),
                  _CategoryCard(
                    title: 'Songs',
                    icon: FontAwesomeIcons.music,
                    onTap: () => context.go('/songs'),
                  ),
                  _CategoryCard(
                    title: 'Playlists',
                    icon: FontAwesomeIcons.list,
                    onTap: () => context.go('/playlists'),
                  ),
                  _CategoryCard(
                    title: 'Artists',
                    icon: FontAwesomeIcons.user,
                    onTap: () => context.go('/artists'),
                  ),
                  _CategoryCard(
                    title: 'Downloaded',
                    icon: FontAwesomeIcons.circleCheck,
                    onTap: () {}, // TODO
                  ),
                  _CategoryCard(
                    title: 'Folders',
                    icon: FontAwesomeIcons.solidFolder,
                    onTap: () => context.go('/explorer'),
                  ),
                ]),
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
