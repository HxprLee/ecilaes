import 'dart:convert';
import 'dart:io';
import 'song_cache.dart';

/// A stamped cache entry wrapping data with a write timestamp.
typedef StampedCacheEntry = ({dynamic data, DateTime timestamp});

class YTCacheHelper {
  static Future<String> get _cacheDir async {
    final baseDir = await SongCache.cacheDir;
    final dir = Directory('$baseDir/yt_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  static Future<void> writeCache(String key, dynamic data) async {
    // Fire-and-forget: don't await so callers (e.g. getHomeSections) stay non-blocking.
    YTCacheHelper.writeStampedCache(key, data);
  }

  static Future<dynamic> readCache(String key) async {
    final entry = await readStampedCache(key);
    return entry?.data;
  }

  static Future<void> writeStampedCache(String key, dynamic data) async {
    try {
      final dir = await _cacheDir;
      final envelope = {
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      };
      final file = File('$dir/$key.json');
      await file.writeAsString(jsonEncode(envelope));
    } catch (e) {
      print('YTCacheHelper write error: $e');
    }
  }

  static Future<StampedCacheEntry?> readStampedCache(String key, {Duration? maxAge}) async {
    try {
      final dir = await _cacheDir;
      final file = File('$dir/$key.json');
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      final decoded = jsonDecode(content);

      // Support both the stamped envelope {data, timestamp} and legacy flat files.
      dynamic data;
      DateTime timestamp;

      if (decoded is Map && decoded.containsKey('data') && decoded.containsKey('timestamp')) {
        data = decoded['data'];
        timestamp = DateTime.parse(decoded['timestamp'] as String);
      } else {
        // Legacy flat file — use the file's modified time as a proxy timestamp.
        final stat = await file.stat();
        data = decoded;
        timestamp = stat.modified;
      }

      if (maxAge != null && DateTime.now().difference(timestamp) > maxAge) {
        return null;
      }
      return (data: data, timestamp: timestamp);
    } catch (e) {
      print('YTCacheHelper read error: $e');
      return null;
    }
  }

  static Future<void> clearCache() async {
    try {
      final dir = await _cacheDir;
      final directory = Directory(dir);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (e) {
      print('YTCacheHelper clear error: $e');
    }
  }
}
