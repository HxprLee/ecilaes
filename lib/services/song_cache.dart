import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';

class SongCache {
  static const String _cacheFileName = 'song_cache.json';
  static const String _artDirName = 'album_art';

  static Future<String> get _cacheDir async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/music_app_cache';
  }

  static Future<String> get artDir async {
    final cache = await _cacheDir;
    return '$cache/$_artDirName';
  }

  static Future<String> get _cacheFilePath async {
    final cache = await _cacheDir;
    return '$cache/$_cacheFileName';
  }

  /// Initialize cache directories
  static Future<void> init() async {
    final cacheDir = Directory(await _cacheDir);
    final artDirectory = Directory(await artDir);

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
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
      for (final json in jsonList) {
        // Just check if album art file exists - don't load bytes
        final artPath = '$artDirPath/${_artFileName(json['path'])}';
        final artFile = File(artPath);
        final hasArt = await artFile.exists();

        songs.add(
          Song(
            path: json['path'],
            title: (json['title'] == null || json['title'] == 'Unknown')
                ? Song.fromPath(json['path']).title
                : json['title'],
            artist: json['artist'] ?? 'Unknown Artist',
            album: json['album'],
            hasAlbumArt: hasArt, // Lightweight flag
            lyrics: json['lyrics'],
            duration: json['durationMs'] != null
                ? Duration(milliseconds: json['durationMs'])
                : null,
            bitrate: json['bitrate'],
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
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
}
