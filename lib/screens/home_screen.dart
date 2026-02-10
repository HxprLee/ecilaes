import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';
import '../models/song.dart';
import '../services/song_cache.dart';

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
                child: const Text(
                  'Home',
                  style: TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFCE7AC),
                  ),
                ),
              ),
            ),

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
                      onTap: () {},
                    ),
                    const SizedBox(width: 16),
                    _QuickAccessCard(
                      title: 'Recently played',
                      icon: FontAwesomeIcons.clockRotateLeft,
                      onTap: () {},
                    ),
                    const SizedBox(width: 16),
                    _QuickAccessCard(
                      title: 'Most played',
                      icon: FontAwesomeIcons.rotateLeft,
                      onTap: () {},
                    ),
                    const SizedBox(width: 16),
                    _QuickAccessCard(
                      title: 'Playlists',
                      icon: FontAwesomeIcons.list,
                      onTap: () {},
                    ),
                    const SizedBox(width: 16),
                    _QuickAccessCard(
                      title: 'Shuffle',
                      icon: FontAwesomeIcons.shuffle,
                      onTap: () => audioSignal.toggleShuffle(),
                    ),
                    const SizedBox(width: 16),
                    _AddCard(onTap: () {}),
                  ],
                ),
              ),
            ),

            // Recently Added
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                child: const Text(
                  'Recently added',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFCE7AC),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: recentAdded.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
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
                child: const Text(
                  'Recently played',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFCE7AC),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final song = recentPlayed[index];
                  return _PortraitSongCard(
                    song: song,
                    artPath: _getArtPath(song.path),
                    onTap: () => audioSignal.playSong(song),
                  );
                }, childCount: recentPlayed.length),
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
  final IconData icon;
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
        width: 130,
        height: 80,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E222B).withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color.fromARGB(38, 255, 239, 175)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FaIcon(icon, color: const Color(0xFFFCE7AC), size: 18),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
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
        width: 130,
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF1E222B).withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color.fromARGB(38, 255, 239, 175)),
        ),
        child: const Center(
          child: FaIcon(
            FontAwesomeIcons.plus,
            color: Color(0xFFFCE7AC),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: FileImage(File(artPath)),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.3),
              BlendMode.darken,
            ),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Positioned(
              top: 12,
              right: 12,
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 24,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: FileImage(File(artPath)),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
