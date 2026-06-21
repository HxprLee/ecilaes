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

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'youtube_service.dart';

/// Manages persistent disk caching of YouTube audio streams.
///
/// Cached files are stored as `<videoId>.m4a` in the
/// `ecilaes_cache/songs/` directory.
class AudioCacheService {
  static final AudioCacheService _instance = AudioCacheService._internal();
  factory AudioCacheService() => _instance;
  AudioCacheService._internal();

  String? _cacheDirPath;

  /// Video IDs currently being downloaded.
  final Map<String, Future<File?>> _activeDownloads = {};

  /// Initialize the cache directory.
  Future<void> init() async {
    if (_cacheDirPath != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _cacheDirPath = '${dir.path}/ecilaes_cache/songs';
    final cacheDir = Directory(_cacheDirPath!);
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
  }

  /// Returns the cache directory path (after init).
  Future<String> get cacheDirPath async {
    await init();
    return _cacheDirPath!;
  }

  /// Returns the expected file path for a cached song.
  String _filePath(String videoId) => '$_cacheDirPath/$videoId.m4a';

  /// Check if a song is already fully cached on disk.
  /// Returns the file path if cached, null otherwise.
  String? getCachedPath(String videoId) {
    if (_cacheDirPath == null) return null;
    final path = _filePath(videoId);
    if (File(path).existsSync()) return path;
    return null;
  }

  /// Async version of getCachedPath.
  Future<String?> getCachedPathAsync(String videoId) async {
    await init();
    return getCachedPath(videoId);
  }

  /// Whether a download for [videoId] is currently in progress.
  bool isCaching(String videoId) => _activeDownloads.containsKey(videoId);

  /// Start caching an audio stream for [videoId].
  ///
  /// If no [streamUrl] is provided, it will be resolved via [YoutubeService].
  /// Returns the cached [File] on success, or null on failure.
  /// Deduplicates concurrent requests for the same videoId.
  Future<File?> cacheStream(String videoId, {String? streamUrl}) async {
    await init();

    // Already cached
    final existing = getCachedPath(videoId);
    if (existing != null) return File(existing);

    // Already downloading
    if (_activeDownloads.containsKey(videoId)) {
      return _activeDownloads[videoId];
    }

    final future = _downloadStream(videoId, streamUrl: streamUrl);
    _activeDownloads[videoId] = future;

    try {
      return await future;
    } finally {
      _activeDownloads.remove(videoId);
    }
  }

  Future<File?> _downloadStream(String videoId, {String? streamUrl}) async {
    try {
      // Resolve URL if not provided
      final url = streamUrl ?? await youtubeService.getAudioStreamUrl(videoId);
      if (url == null) {
        debugPrint('AudioCache: Failed to resolve stream URL for $videoId');
        return null;
      }

      debugPrint('AudioCache: Downloading $videoId...');
      final tempPath = '${_cacheDirPath!}/$videoId.temp';
      final finalPath = _filePath(videoId);

      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(url));
        request.headers.set('User-Agent',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
        final response = await request.close();

        if (response.statusCode != 200) {
          debugPrint('AudioCache: HTTP ${response.statusCode} for $videoId');
          await response.drain();
          return null;
        }

        final file = File(tempPath);
        final sink = file.openWrite();
        int bytesWritten = 0;

        await for (final chunk in response) {
          sink.add(chunk);
          bytesWritten += chunk.length;
        }

        await sink.flush();
        await sink.close();

        // Atomic rename from temp to final
        await File(tempPath).rename(finalPath);
        final sizeMb = (bytesWritten / (1024 * 1024)).toStringAsFixed(2);
        debugPrint('AudioCache: ✓ Cached $videoId ($sizeMb MB)');
        return File(finalPath);
      } finally {
        client.close();
        // Clean up temp file if it still exists
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          try {
            await tempFile.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('AudioCache: Error caching $videoId: $e');
      return null;
    }
  }

  /// Cancel all active downloads (e.g. on dispose).
  void cancelAll() {
    _activeDownloads.clear();
  }
}

final audioCacheService = AudioCacheService();
