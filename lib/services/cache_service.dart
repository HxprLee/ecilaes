// Ecilaes - Cross-platform music player
// Copyright (C) 2024  Anton Borri
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
import 'song_cache.dart';

class CacheStats {
  final int sizeBytes;
  final int fileCount;

  CacheStats({required this.sizeBytes, required this.fileCount});
}

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  Future<CacheStats> getDirectoryStats(String path, {bool Function(File)? exclude}) async {
    final dir = Directory(path);
    if (!await dir.exists()) return CacheStats(sizeBytes: 0, fileCount: 0);

    int size = 0;
    int count = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          if (exclude == null || !exclude(entity)) {
            size += await entity.length();
            count++;
          }
        }
      }
    } catch (e) {
      print('Error calculating size for $path: $e');
    }
    return CacheStats(sizeBytes: size, fileCount: count);
  }

  Future<CacheStats> getAlbumArtStats() async {
    final cacheDir = await SongCache.cacheDir;
    return getDirectoryStats(
      '$cacheDir/album_art', 
      exclude: (f) => f.path.split('/').last.startsWith('playlist_'),
    );
  }

  Future<CacheStats> getArtistArtStats() async {
    final cacheDir = await SongCache.cacheDir;
    return getDirectoryStats('$cacheDir/artist_art');
  }

  Future<CacheStats> getLyricsStats() async {
    final cacheDir = await SongCache.cacheDir;
    return getDirectoryStats('$cacheDir/lyrics');
  }

  Future<CacheStats> getMetadataStats() async {
    final cacheDir = await SongCache.cacheDir;
    final file = File('$cacheDir/song_cache.json');
    if (await file.exists()) {
      return CacheStats(sizeBytes: await file.length(), fileCount: 1);
    }
    return CacheStats(sizeBytes: 0, fileCount: 0);
  }

  Future<void> clearDirectory(String path, {bool Function(File)? exclude}) async {
    final dir = Directory(path);
    if (await dir.exists()) {
      try {
        if (exclude == null) {
          await dir.delete(recursive: true);
          await dir.create(recursive: true);
        } else {
          await for (final entity in dir.list(recursive: true)) {
            if (entity is File && !exclude(entity)) {
              await entity.delete();
            }
          }
        }
      } catch (e) {
        print('Error clearing directory $path: $e');
      }
    }
  }

  Future<void> clearAlbumArt() async {
    final cacheDir = await SongCache.cacheDir;
    await clearDirectory(
      '$cacheDir/album_art',
      exclude: (f) => f.path.split('/').last.startsWith('playlist_'),
    );
  }

  Future<void> clearArtistArt() async {
    final cacheDir = await SongCache.cacheDir;
    await clearDirectory('$cacheDir/artist_art');
  }

  Future<void> clearLyrics() async {
    final cacheDir = await SongCache.cacheDir;
    await clearDirectory('$cacheDir/lyrics');
  }

  Future<void> clearMetadata() async {
    final cacheDir = await SongCache.cacheDir;
    final file = File('$cacheDir/song_cache.json');
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (e) {
        print('Error clearing metadata cache: $e');
      }
    }
  }

  Future<CacheStats> getAudioStats() async {
    final cacheDir = await SongCache.cacheDir;
    return getDirectoryStats('$cacheDir/songs');
  }

  Future<void> clearAudioCache() async {
    final cacheDir = await SongCache.cacheDir;
    await clearDirectory('$cacheDir/songs');
  }

  Future<void> clearAll() async {
    await clearAlbumArt();
    await clearArtistArt();
    await clearLyrics();
    await clearMetadata();
    await clearAudioCache();
  }
}

final cacheService = CacheService();
