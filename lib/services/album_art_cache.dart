import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'YoutubeDatasource.dart';

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

  /// Initialize the cache directory
  Future<void> init() async {
    if (_artDirPath != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _artDirPath = '${dir.path}/music_app_cache/album_art';
    final artDir = Directory(_artDirPath!);
    if (!await artDir.exists()) {
      await artDir.create(recursive: true);
    }
  }

  /// Get the file path for a song's album art
  String _getArtPath(String songPath) {
    final hash = songPath.hashCode.abs();
    return '$_artDirPath/$hash.jpg';
  }

  /// Get the file path for a song's album art (synchronous check)
  String? getArtPathSync(String songPath) {
    if (_artDirPath == null) return null;
    final path = _getArtPath(songPath);
    if (File(path).existsSync()) {
      return path;
    }
    return null;
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
    final artPath = _getArtPath(songPath);
    final artFile = File(artPath);

    // Try loading from disk cache
    if (await artFile.exists()) {
      return artFile;
    }

    // YouTube paths don't have local art - download it
    if (songPath.startsWith('yt:')) {
      try {
        final videoId = songPath.substring(3);
        final url = youtubeDatasource.getArtworkUrl(videoId);
        if (url.isEmpty) return null;

        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          await artFile.writeAsBytes(response.bodyBytes);
          return artFile;
        }
      } catch (e) {
        debugPrint('Error downloading YouTube art: $e');
      }
      return null;
    }

    // Fall back to extracting from audio file
    try {
      final bytes = await Isolate.run(() {
        final file = File(songPath);
        if (!file.existsSync()) return null;
        // Use a robust metadata reader that ensures file handles are closed
        try {
          final reader = file.openSync();
          try {
            if (ID3v2Parser.canUserParser(reader)) {
              final mp3Meta = ID3v2Parser(fetchImage: true).parse(reader) as Mp3Metadata;
              
              Picture? selectedPic;
              if (mp3Meta.pictures.isNotEmpty) {
                try {
                  selectedPic = mp3Meta.pictures.firstWhere(
                    (p) => p.pictureType == PictureType.coverFront,
                  );
                } catch (_) {
                  selectedPic = mp3Meta.pictures.first;
                }
              }

              // Fallback for ID3v2.2 PIC frame
              if (selectedPic == null) {
                try {
                  reader.setPositionSync(0);
                  final header = reader.readSync(10);
                  if (header[3] == 2) { // ID3v2.2
                    final bytes = reader.lengthSync() < 128000 
                        ? reader.readSync(reader.lengthSync())
                        : reader.readSync(128000);
                    int picIndex = -1;
                    for (int j = 0; j < bytes.length - 3; j++) {
                      if (bytes[j] == 80 && bytes[j+1] == 73 && bytes[j+2] == 67) {
                        picIndex = j;
                        break;
                      }
                    }
                    if (picIndex != -1) {
                      final size = (bytes[picIndex+3] << 16) | (bytes[picIndex+4] << 8) | bytes[picIndex+5];
                      if (size > 0 && picIndex + 6 + size <= bytes.length) {
                        final frameData = bytes.sublist(picIndex + 6, picIndex + 6 + size);
                        // Search for magic bytes in frameData
                        int imgStart = -1;
                        for (int k = 0; k < frameData.length - 4; k++) {
                          if ((frameData[k] == 0xFF && frameData[k+1] == 0xD8 && frameData[k+2] == 0xFF) ||
                              (frameData[k] == 0x89 && frameData[k+1] == 0x50 && frameData[k+2] == 0x4E && frameData[k+3] == 0x47)) {
                            imgStart = k;
                            break;
                          }
                        }
                        if (imgStart != -1) return frameData.sublist(imgStart);
                      }
                    }
                  }
                } catch (_) {}
              }

              if (selectedPic != null) {
                final bytes = selectedPic.bytes;
                int imgStart = -1;
                for (int k = 0; k < bytes.length - 4; k++) {
                   if ((bytes[k] == 0xFF && bytes[k+1] == 0xD8 && bytes[k+2] == 0xFF) ||
                       (bytes[k] == 0x89 && bytes[k+1] == 0x50 && bytes[k+2] == 0x4E && bytes[k+3] == 0x47)) {
                     imgStart = k;
                     break;
                   }
                }
                return imgStart != -1 ? bytes.sublist(imgStart) : bytes;
              }
              return null;
            } else if (FlacParser.canUserParser(reader)) {
              final vorbisMeta = FlacParser(fetchImage: true).parse(reader) as VorbisMetadata;
              if (vorbisMeta.pictures.isEmpty) return null;
              return (vorbisMeta.pictures.firstWhere(
                (p) => p.pictureType == PictureType.coverFront,
                orElse: () => vorbisMeta.pictures.first,
              )).bytes;
            } else if (MP4Parser.canUserParser(reader)) {
              final mp4Meta = MP4Parser(fetchImage: true).parse(reader) as Mp4Metadata;
              return mp4Meta.picture?.bytes;
            } else if (OGGParser.canUserParser(reader)) {
              final oggMeta = OGGParser(fetchImage: true).parse(reader) as VorbisMetadata;
              if (oggMeta.pictures.isEmpty) return null;
              return oggMeta.pictures.first.bytes;
            } else {
              // Fallback to default
              reader.closeSync();
              final metadata = readMetadata(file, getImage: true);
              if (metadata.pictures.isEmpty) return null;
              return (metadata.pictures.firstWhere(
                (p) => p.pictureType == PictureType.coverFront,
                orElse: () => metadata.pictures.first,
              )).bytes;
            }
          } finally {
            try { reader.closeSync(); } catch (_) {}
          }
        } catch (e) {
          // Final fallback
          try {
            final metadata = readMetadata(file, getImage: true);
            if (metadata.pictures.isEmpty) return null;
            return metadata.pictures.first.bytes;
          } catch (_) {
            return null;
          }
        }
      });

      if (bytes != null) {
        // Cache to disk for future use
        await _saveArtToDisk(songPath, bytes);
        return artFile;
      }

      // Fallback to sidecar (also can be heavy if directory has many files)
      final sidecar = await Isolate.run(() => _findSidecarArt(songPath));
      if (sidecar != null) {
        await sidecar.copy(artPath);
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
    // YouTube paths use YouTube Music thumbnail (square, hi-res)
    if (songPath.startsWith('yt:')) {
      final videoId = songPath.substring(3);
      return Uri.parse(youtubeDatasource.getArtworkUrl(videoId));
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
      final bytes = await Isolate.run(() {
        final file = File(songPath);
        if (!file.existsSync()) return null;
        // Use a robust metadata reader that ensures file handles are closed
        try {
          final reader = file.openSync();
          try {
            if (ID3v2Parser.canUserParser(reader)) {
              final mp3Meta = ID3v2Parser(fetchImage: true).parse(reader) as Mp3Metadata;
              if (mp3Meta.pictures.isEmpty) return null;
              
              Picture selectedPic;
              try {
                selectedPic = mp3Meta.pictures.firstWhere(
                  (p) => p.pictureType == PictureType.coverFront,
                );
              } catch (_) {
                selectedPic = mp3Meta.pictures.first;
              }
              return selectedPic.bytes;
            } else if (FlacParser.canUserParser(reader)) {
              final vorbisMeta = FlacParser(fetchImage: true).parse(reader) as VorbisMetadata;
              if (vorbisMeta.pictures.isEmpty) return null;
              return (vorbisMeta.pictures.firstWhere(
                (p) => p.pictureType == PictureType.coverFront,
                orElse: () => vorbisMeta.pictures.first,
              )).bytes;
            } else if (MP4Parser.canUserParser(reader)) {
              final mp4Meta = MP4Parser(fetchImage: true).parse(reader) as Mp4Metadata;
              return mp4Meta.picture?.bytes;
            } else if (OGGParser.canUserParser(reader)) {
              final oggMeta = OGGParser(fetchImage: true).parse(reader) as VorbisMetadata;
              if (oggMeta.pictures.isEmpty) return null;
              return oggMeta.pictures.first.bytes;
            } else {
              // Fallback to default
              reader.closeSync();
              final metadata = readMetadata(file, getImage: true);
              if (metadata.pictures.isEmpty) return null;
              return (metadata.pictures.firstWhere(
                (p) => p.pictureType == PictureType.coverFront,
                orElse: () => metadata.pictures.first,
              )).bytes;
            }
          } finally {
            try { reader.closeSync(); } catch (_) {}
          }
        } catch (e) {
          // Final fallback
          try {
            final metadata = readMetadata(file, getImage: true);
            if (metadata.pictures.isEmpty) return null;
            return metadata.pictures.first.bytes;
          } catch (_) {
            return null;
          }
        }
      });

      if (bytes != null) {
        await _saveArtToDisk(songPath, bytes);
        return artFile.uri;
      }

      // Sidecar fallback
      final sidecar = await Isolate.run(() => _findSidecarArt(songPath));
      if (sidecar != null) {
        await sidecar.copy(artPath);
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

  File? _findSidecarArt(String audioPath) {
    try {
      final file = File(audioPath);
      final directory = file.parent;
      if (!directory.existsSync()) return null;

      final sidecarNames = [
        'cover.jpg',
        'cover.png',
        'cover.jpeg',
        'folder.jpg',
        'folder.png',
        'folder.jpeg',
        'album.jpg',
        'album.png',
        '.folder.jpg',
        '.folder.png',
      ];

      for (final name in sidecarNames) {
        final sidecar = File('${directory.path}/$name');
        if (sidecar.existsSync()) return sidecar;
      }

      // Case-insensitive fallback
      final list = directory.listSync();
      for (final entity in list) {
        if (entity is File) {
          final name = entity.path.split('/').last.toLowerCase();
          if (name == 'cover.jpg' ||
              name == 'cover.png' ||
              name == 'folder.jpg' ||
              name == 'folder.png' ||
              name == 'album.jpg' ||
              name == 'album.png') {
            return entity;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
