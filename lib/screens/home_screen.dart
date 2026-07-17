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
import 'package:signals/signals_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../router/routes.dart';
import '../signals/audio_signal.dart';
import '../services/song_cache.dart';
import '../models/song.dart';
import '../widgets/components/sliver_page_header.dart';
import '../theme/app_theme_tokens.dart';
import '../utils/navigation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _artDirPath;

  @override
  void initState() {
    super.initState();
    _initArtDir();
  }

  Future<void> _initArtDir() async {
    final path = await SongCache.artDir;
    if (mounted) {
      setState(() {
        _artDirPath = path;
      });
    }
  }

  String _getArtPath(String songPath) {
    if (_artDirPath == null) return '';
    final fileName = '${songPath.hashCode.abs()}.jpg';
    return '$_artDirPath/$fileName';
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final recentAdded = audioSignal.recentlyAdded.value;
      final recentPlayed = audioSignal.recentlyPlayed.value;

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            // Header
            const SliverPageHeader(title: 'Home'),

            // Quick Access Row
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _QuickAccessCard(
                      title: 'Favorites',
                      icon: FontAwesomeIcons.solidHeart,
                      onTap: () => navigateGo(context, '${AppRoutes.playlists}/favorites'),
                    ),
                    const SizedBox(width: 8),
                    _QuickAccessCard(
                      title: 'Recently played',
                      icon: FontAwesomeIcons.clockRotateLeft,
                      onTap: () => navigateGo(context, AppRoutes.recentlyPlayed),
                    ),
                    const SizedBox(width: 8),
                    _QuickAccessCard(
                      title: 'Recently added',
                      icon: FontAwesomeIcons.bolt,
                      onTap: () => navigateGo(context, AppRoutes.recentlyAdded),
                    ),
                    const SizedBox(width: 8),
                    _QuickAccessCard(
                      title: 'Most played',
                      icon: FontAwesomeIcons.rotateLeft,
                      onTap: () {},
                    ),
                    const SizedBox(width: 8),
                    _QuickAccessCard(
                      title: 'Playlists',
                      icon: FontAwesomeIcons.list,
                      onTap: () => navigateGo(context, AppRoutes.playlists),
                    ),
                    const SizedBox(width: 8),
                    _QuickAccessCard(
                      title: 'Shuffle',
                      icon: FontAwesomeIcons.shuffle,
                      onTap: () => audioSignal.toggleShuffle(),
                    ),
                    const SizedBox(width: 8),
                    _AddCard(onTap: () {}),
                  ],
                ),
              ),
            ),

            // Recently Added
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recently added',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => navigateGo(context, AppRoutes.recentlyAdded),
                      icon: FaIcon(
                        FontAwesomeIcons.chevronRight,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: recentAdded.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final song = recentAdded[index];
                    return _LandscapeSongCard(
                      song: song,
                      artPath: _getArtPath(song.path),
                      onTap: () => audioSignal.playSong(song),
                    );
                  },
                ),
              ),
            ),

            // Recently Played
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recently played',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => navigateGo(context, AppRoutes.recentlyPlayed),
                      icon: FaIcon(
                        FontAwesomeIcons.chevronRight,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: recentPlayed.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final song = recentPlayed[index];
                    return _PortraitSongCard(
                      song: song,
                      artPath: _getArtPath(song.path),
                      onTap: () => audioSignal.playSong(song),
                    );
                  },
                ),
              ),
            ),
            // Bottom spacing
            SliverToBoxAdapter(
              child: SizedBox(height: audioSignal.reservedHeight.value),
            ),
          ],
        ),
      );
    });
  }
}

class _QuickAccessCard extends StatelessWidget {
  final String title;
  final FaIconData icon;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 155,
        height: 90,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.tokens.sidebarBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.accentBorder(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FaIcon(
              icon,
              color: context.colorScheme.secondary,
              size: 18,
            ),
            Text(
              title,
              style: TextStyle(
                color: context.colorScheme.secondary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 150,
        height: 90,
        decoration: BoxDecoration(
          color: context.tokens.sidebarBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.accentBorder(0.15)),
        ),
        child: Center(
          child: FaIcon(
            FontAwesomeIcons.plus,
            color: context.colorScheme.secondary,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _LandscapeSongCard extends StatelessWidget {
  final Song song;
  final String artPath;
  final VoidCallback onTap;

  const _LandscapeSongCard({
    required this.song,
    required this.artPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final overlayColor = context.isMaterial3
        ? context.colorScheme.onSurface.withValues(alpha: 0.3)
        : Colors.black.withValues(alpha: 0.3);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 230,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.15),
          ),
          image: DecorationImage(
            image: FileImage(File(artPath)),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              overlayColor,
              BlendMode.darken,
            ),
          ),
        ),
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            Positioned(
              bottom: 16,
              left: 18,
              right: 18,
              child: Column(
                spacing: 2,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 18,
              left: 18,
              child: FaIcon(
                FontAwesomeIcons.play,
                color: Theme.of(context).colorScheme.secondary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortraitSongCard extends StatelessWidget {
  final Song song;
  final String artPath;
  final VoidCallback onTap;

  const _PortraitSongCard({
    required this.song,
    required this.artPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: FileImage(File(artPath)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
