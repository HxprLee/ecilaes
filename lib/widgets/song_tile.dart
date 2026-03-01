import 'dart:io';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/song.dart';
import '../signals/audio_signal.dart';
import '../services/song_cache.dart';
import 'song_actions_sheet.dart';

class SongTile extends StatefulWidget {
  final Song song;
  final int? index;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? playlistId;

  const SongTile({
    super.key,
    required this.song,
    this.index,
    this.trailing,
    this.onTap,
    this.playlistId,
  });

  static String getArtPath(String songPath, String? artDirPath) {
    if (artDirPath == null) return '';
    final fileName = '${songPath.hashCode.abs()}.jpg';
    return '$artDirPath/$fileName';
  }

  @override
  State<SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<SongTile> {
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

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '--:--';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final isCurrent = audioSignal.currentSong.value?.path == widget.song.path;
      final artPath = SongTile.getArtPath(widget.song.path, _artDirPath);
      final hasArt =
          widget.song.hasAlbumArt &&
          artPath.isNotEmpty &&
          File(artPath).existsSync();

      return ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 24),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.index != null)
              Container(
                width: 32,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${widget.index! + 1}',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.38),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                image: hasArt
                    ? DecorationImage(
                        image: FileImage(File(artPath)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: !hasArt
                  ? Center(
                      child: FaIcon(
                        FontAwesomeIcons.music,
                        size: 18,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.24),
                      ),
                    )
                  : null,
            ),
          ],
        ),
        title: Text(
          widget.song.title,
          style: TextStyle(
            color: isCurrent
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          widget.song.artist,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.54),
            fontSize: 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing:
            widget.trailing ??
            Text(
              _formatDuration(widget.song.duration ?? Duration.zero),
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.38),
                fontSize: 12,
              ),
            ),
        onTap: widget.onTap ?? () => audioSignal.playSong(widget.song),
        onLongPress: () {
          showSongMoreActionsSheet(
            context: context,
            song: widget.song,
            playlistId: widget.playlistId,
          );
        },
      );
    });
  }
}
