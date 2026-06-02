import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';

class SongCache {
  static const String _cacheFileName = 'song_cache.json';
  static const String _artDirName = 'album_art';

  static Future<String> get cacheDir async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/ecilaes_cache';
  }

  static Future<String> get artDir async {
    final cache = await cacheDir;
    return '$cache/$_artDirName';
  }

  static Future<String> get _cacheFilePath async {
    final cache = await cacheDir;
    return '$cache/$_cacheFileName';
  }

  /// Initialize cache directories
  static Future<void> init() async {
    final cacheDirStr = await cacheDir;
    final artDirectory = Directory(await artDir);

    if (!await Directory(cacheDirStr).exists()) {
      await Directory(cacheDirStr).create(recursive: true);
    }
    if (!await artDirectory.exists()) {
      await artDirectory.create(recursive: true);
    }
  }

  /// Generate a unique filename for album art based on song path
  static String _artFileName(String songPath) {
    return '${songPath.hashCode.abs()}.jpg';
  }

  /// Load all cached songs (without loading album art bytes into memory)
  static Future<List<Song>> loadCache() async {
    try {
      final file = File(await _cacheFilePath);
      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      final artDirPath = await artDir;

      final songs = <Song>[];
      
      // Perform existence checks in parallel to avoid sequential IO bottlenecks
      final existenceChecks = jsonList.map((json) {
        final artPath = '$artDirPath/${_artFileName(json['path'])}';
        return File(artPath).exists();
      }).toList();
      
      final hasArtList = await Future.wait(existenceChecks);

      for (int i = 0; i < jsonList.length; i++) {
        final json = jsonList[i];
        final hasArt = hasArtList[i];

        songs.add(
          Song(
            path: json['path'],
            title: (json['title'] == null || json['title'] == 'Unknown')
                ? Song.fromPath(json['path']).title
                : json['title'],
            artist: json['artist'] ?? 'Unknown Artist',
            album: json['album'],
            hasAlbumArt: hasArt,
            lyrics: json['lyrics'],
            duration: json['durationMs'] != null
                ? Duration(milliseconds: json['durationMs'])
                : null,
            bitrate: json['bitrate'],
            size: json['size'],
            modifiedAt: json['modifiedAt'] != null
                ? DateTime.fromMillisecondsSinceEpoch(json['modifiedAt'])
                : null,
            gainDb: (json['gainDb'] as num?)?.toDouble() ?? 0.0,
            trackPeak: (json['trackPeak'] as num?)?.toDouble() ?? 1.0,
            albumGainDb: (json['albumGainDb'] as num?)?.toDouble() ?? 0.0,
            albumPeak: (json['albumPeak'] as num?)?.toDouble() ?? 1.0,
          ),
        );
      }

      return songs;
    } catch (e) {
      print('Error loading cache: $e');
      return [];
    }
  }

  /// Save all songs to cache (album art saved to disk separately)
  static Future<void> saveCache(List<Song> songs) async {
    try {
      await init();

      final jsonList = <Map<String, dynamic>>[];
      for (final song in songs) {
        jsonList.add({
          'path': song.path,
          'title': song.title,
          'artist': song.artist,
          'album': song.album,
          'hasAlbumArt': song.hasAlbumArt,
          'lyrics': song.lyrics,
          'durationMs': song.duration?.inMilliseconds,
          'bitrate': song.bitrate,
          'size': song.size,
          'modifiedAt': song.modifiedAt?.millisecondsSinceEpoch,
          'gainDb': song.gainDb,
          'trackPeak': song.trackPeak,
          'albumGainDb': song.albumGainDb,
          'albumPeak': song.albumPeak,
        });
      }

      final file = File(await _cacheFilePath);
      await file.writeAsString(jsonEncode(jsonList));
      print('Saved ${songs.length} songs to cache');
    } catch (e) {
      print('Error saving cache: $e');
    }
  }

  /// Save album art bytes to disk (called during metadata scan)
  static Future<void> saveAlbumArt(String songPath, Uint8List artBytes) async {
    try {
      await init();
      final artDirPath = await artDir;
      final artPath = '$artDirPath/${_artFileName(songPath)}';
      await File(artPath).writeAsBytes(artBytes);
    } catch (e) {
      print('Error saving album art: $e');
    }
  }

  /// Get set of cached song paths for quick lookup
  static Future<Set<String>> getCachedPaths() async {
    final songs = await loadCache();
    return songs.map((s) => s.path).toSet();
  }

  /// Get the album art file for a song
  static Future<File> getAlbumArtFile(String songPath) async {
    final artDirPath = await artDir;
    return File('$artDirPath/${_artFileName(songPath)}');
  }

  /// Clear the song cache file
  static Future<void> clearCache() async {
    try {
      final file = File(await _cacheFilePath);
      if (await file.exists()) {
        await file.delete();
      }

      final artDirectory = Directory(await artDir);
      if (await artDirectory.exists()) {
        await for (final entity in artDirectory.list()) {
          if (entity is File && !entity.path.split('/').last.startsWith('playlist_')) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
}
