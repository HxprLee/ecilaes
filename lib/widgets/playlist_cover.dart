import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:signals/signals_flutter.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../signals/audio_signal.dart';
import '../services/YoutubeDatasource.dart';
import 'song_tile.dart';

class PlaylistCover extends StatelessWidget {
  final Playlist playlist;
  final double? width;
  final double? height;
  final double borderRadius;
  final FaIconData? iconOverride;

  const PlaylistCover({
    super.key,
    required this.playlist,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.iconOverride,
  });

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      if (playlist.imagePath != null) {
        return _buildImage(FileImage(File(playlist.imagePath!)));
      }

      // If it's a special playlist or has no songs, use the icon placeholder.
      if (playlist.id == 'favorites' || 
          playlist.id == 'recently-played' || 
          playlist.id == 'recently-added' ||
          playlist.songPaths.isEmpty) {
        return _buildPlaceholder(context);
      }

      final allSongs = audioSignal.allSongs.value;
      final artDir = audioSignal.albumArtDir.value;

      // Find unique songs with artwork
      final songsWithArt = <Song>[];
      final seenArtKeys = <String>{};

      for (final path in playlist.songPaths) {
        final song = allSongs.firstWhere(
          (s) => s.path == path,
          orElse: () => Song.fromPath(path),
        );
        if (song.hasAlbumArt) {
          // Deduplicate by a semantic key.
          // We include file size because many songs (e.g. singles) might have 
          // different album tags but identical artwork files.
          String artKey;
          if (song.path.startsWith('yt:')) {
            artKey = song.path;
          } else {
            int? size;
            try {
              final artPath = SongTile.getArtPath(song.path, artDir);
              final file = File(artPath);
              if (file.existsSync()) {
                size = file.lengthSync();
              }
            } catch (_) {}
            
            artKey = '${song.artist}_$size';
          }
          
          if (!seenArtKeys.contains(artKey)) {
            songsWithArt.add(song);
            seenArtKeys.add(artKey);
            if (songsWithArt.length >= 4) break;
          }
        }
      }

      if (songsWithArt.isEmpty) {
        return _buildPlaceholder(context);
      }

      if (songsWithArt.length == 1) {
        return _buildSongArt(songsWithArt[0], artDir);
      }

      // Grid of 2, 3, or 4
      return _buildGrid(context, songsWithArt, artDir);
    });
  }

  Widget _buildImage(ImageProvider image) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        image: DecorationImage(image: image, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildSongArt(Song song, String? artDir) {
    if (song.path.startsWith('yt:')) {
      final videoId = song.path.substring(3);
      return _buildImage(
        NetworkImage(youtubeDatasource.getArtworkUrl(videoId)),
      );
    }
    final path = SongTile.getArtPath(song.path, artDir);
    return _buildImage(FileImage(File(path)));
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.7,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: FaIcon(
          iconOverride ??
              (playlist.id == 'favorites'
                  ? FontAwesomeIcons.solidHeart
                  : FontAwesomeIcons.list),
          color: Theme.of(context).colorScheme.secondary,
          size: (width != null && width! < 30) 
              ? width! * 0.7 
              : (width ?? 100) / 3,
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<Song> songs, String? artDir) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(borderRadius)),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildGridItem(songs[0], artDir)),
                Expanded(
                  child:
                      songs.length > 1
                          ? _buildGridItem(songs[1], artDir)
                          : Container(color: Colors.black.withValues(alpha: 0.1)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child:
                      songs.length > 2
                          ? _buildGridItem(songs[2], artDir)
                          : Container(color: Colors.black.withValues(alpha: 0.1)),
                ),
                Expanded(
                  child:
                      songs.length > 3
                          ? _buildGridItem(songs[3], artDir)
                          : Container(color: Colors.black.withValues(alpha: 0.1)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(Song song, String? artDir) {
    ImageProvider image;
    if (song.path.startsWith('yt:')) {
      final videoId = song.path.substring(3);
      image = NetworkImage(youtubeDatasource.getArtworkUrl(videoId));
    } else {
      image = FileImage(File(SongTile.getArtPath(song.path, artDir)));
    }
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(image: image, fit: BoxFit.cover),
      ),
    );
  }
}
