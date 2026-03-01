import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';
import '../widgets/page_header.dart';

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
            const SliverToBoxAdapter(
              child: PageHeader(title: 'Library', subtitle: 'Local library'),
            ),

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
                    onTap: () {}, // TODO
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
                    onTap: () {}, // TODO
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
  final IconData icon;
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
                ).colorScheme.surfaceContainerHighest.withOpacity(0.7),
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
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
