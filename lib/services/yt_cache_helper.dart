import 'dart:convert';
import 'dart:io';
import 'song_cache.dart';

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
    try {
      final dir = await _cacheDir;
      final file = File('$dir/$key.json');
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print('YTCacheHelper write error: $e');
    }
  }

  static Future<dynamic> readCache(String key) async {
    try {
      final dir = await _cacheDir;
      final file = File('$dir/$key.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content);
      }
    } catch (e) {
      print('YTCacheHelper read error: $e');
    }
    return null;
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
