import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';

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
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  top:
                      24.0 +
                      ((Platform.isAndroid || Platform.isIOS)
                          ? (50.0 + MediaQuery.of(context).padding.top)
                          : 50.0),
                  left: 24.0,
                  right: 24.0,
                  bottom: 24.0,
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Library',
                      style: TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFFCE7AC),
                      ),
                    ),
                    SizedBox(height: 32),
                    Text(
                      'Local library',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFFCE7AC),
                      ),
                    ),
                  ],
                ),
              ),
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
                    onTap: () {}, // TODO
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
                    onTap: () {}, // TODO
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
                color: const Color(0xFF1E222B).withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color.fromARGB(38, 255, 239, 175),
                ),
              ),
              child: Center(
                child: FaIcon(icon, color: const Color(0xFFFCE7AC), size: 48),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
