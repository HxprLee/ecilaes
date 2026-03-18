import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path_provider/path_provider.dart';

/// LRU cache for album art - keeps only a limited number in memory
/// and loads from disk on-demand
class AlbumArtCache {
  static final AlbumArtCache _instance = AlbumArtCache._internal();
  factory AlbumArtCache() => _instance;
  AlbumArtCache._internal();

  // Pending loads to avoid duplicate requests
  final Map<String, Future<File?>> _pendingLoads = {};

  // Directory paths
  String? _artDirPath;

  // Static flag to prevent double MetadataGod initialization
  static bool _metadataInitialized = false;

  /// Initialize the cache directory
  Future<void> init() async {
    if (_artDirPath != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _artDirPath = '${dir.path}/music_app_cache/album_art';
    final artDir = Directory(_artDirPath!);
    if (!await artDir.exists()) {
      await artDir.create(recursive: true);
    }
    if (!_metadataInitialized) {
      MetadataGod.initialize();
      _metadataInitialized = true;
    }
  }

  /// Get the file path for a song's album art
  String _getArtPath(String songPath) {
    final hash = songPath.hashCode.abs();
    return '$_artDirPath/$hash.jpg';
  }

  /// Check if album art exists on disk for a song
  Future<bool> hasArt(String songPath) async {
    await init();
    final file = File(_getArtPath(songPath));
    return file.exists();
  }

  /// Get album art file for a song (from disk or extract)
  Future<File?> getArt(String songPath) async {
    await init();

    // Check if already loading
    if (_pendingLoads.containsKey(songPath)) {
      return _pendingLoads[songPath];
    }

    // Start loading
    final loadFuture = _loadArt(songPath);
    _pendingLoads[songPath] = loadFuture;

    try {
      return await loadFuture;
    } finally {
      _pendingLoads.remove(songPath);
    }
  }

  /// Load art from disk or extract from audio file
  Future<File?> _loadArt(String songPath) async {
    // YouTube paths don't have local art - thumbnail is fetched via NetworkImage
    if (songPath.startsWith('yt:')) return null;

    final artPath = _getArtPath(songPath);
    final artFile = File(artPath);

    // Try loading from disk cache
    if (await artFile.exists()) {
      return artFile;
    }

    // Fall back to extracting from audio file
    try {
      final metadata = await MetadataGod.readMetadata(file: songPath);
      if (metadata.picture != null) {
        final art = metadata.picture!.data;
        // Cache to disk for future use
        await _saveArtToDisk(songPath, art);
        return artFile;
      }
    } catch (e) {
      debugPrint('Error extracting art from $songPath: $e');
    }

    return null;
  }

  /// Save album art to disk cache
  Future<void> _saveArtToDisk(String songPath, Uint8List art) async {
    try {
      final artPath = _getArtPath(songPath);
      await File(artPath).writeAsBytes(art);
    } catch (e) {
      debugPrint('Error saving art to disk: $e');
    }
  }

  /// Get art file URI for MPRIS (returns file path, not bytes)
  Future<Uri?> getArtUri(String songPath) async {
    // YouTube paths use a remote thumbnail URL, not a local file
    if (songPath.startsWith('yt:')) {
      final videoId = songPath.substring(3);
      return Uri.parse('https://img.youtube.com/vi/$videoId/hqdefault.jpg');
    }

    await init();
    final artPath = _getArtPath(songPath);
    final artFile = File(artPath);

    // Check if already cached on disk
    if (await artFile.exists()) {
      return artFile.uri;
    }

    // Try to extract and cache
    try {
      final metadata = await MetadataGod.readMetadata(file: songPath);
      if (metadata.picture != null) {
        final art = metadata.picture!.data;
        await _saveArtToDisk(songPath, art);
        return artFile.uri;
      }
    } catch (e) {
      debugPrint('Error getting art URI for $songPath: $e');
    }

    return null;
  }

  /// Preload art for a list of songs (e.g., visible songs)
  Future<void> preloadArt(List<String> songPaths) async {
    for (final path in songPaths.take(10)) {
      getArt(path); // Fire and forget
    }
  }
}
