import 'dart:io';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import '../signals/audio_signal.dart';
import '../services/song_cache.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SongsListContent extends StatefulWidget {
  const SongsListContent({super.key});

  @override
  State<SongsListContent> createState() => _SongsListContentState();
}

class _SongsListContentState extends State<SongsListContent> {
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
      final displaySongs = audioSignal.allSongs.value;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Songs',
                          style: TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFFCE7AC),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Songs List
            if (displaySongs.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No songs found',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SuperSliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final song = displaySongs[index];
                    final isCurrent =
                        audioSignal.currentSong.value?.path == song.path;
                    final artPath = _getArtPath(song.path);
                    final hasArt = song.hasAlbumArt && artPath.isNotEmpty;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E222B),
                          borderRadius: BorderRadius.circular(4),
                          image: hasArt
                              ? DecorationImage(
                                  image: FileImage(File(artPath)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: !hasArt
                            ? const Center(
                                child: FaIcon(
                                  FontAwesomeIcons.music,
                                  size: 18,
                                  color: Colors.white24,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        song.title,
                        style: TextStyle(
                          color: isCurrent
                              ? const Color(0xFFFCE7AC)
                              : Colors.white,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        song.artist,
                        style: const TextStyle(color: Colors.white54),
                      ),
                      trailing: Text(
                        _formatDuration(song.duration ?? Duration.zero),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () => audioSignal.playSong(song),
                    );
                  }, childCount: displaySongs.length),
                ),
              ),
            // Bottom padding for player bar
            SliverToBoxAdapter(
              child: SizedBox(height: audioSignal.reservedHeight.value),
            ),
          ],
        ),
      );
    });
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '--:--';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${twoDigits(seconds)}';
  }
}
