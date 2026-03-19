import 'dart:convert';
import 'package:http/http.dart' as http;

class MetadataService {
  static final MetadataService _instance = MetadataService._internal();
  factory MetadataService() => _instance;
  MetadataService._internal();

  /// Basic regex-based filename parser.
  Map<String, String> parseFromFilename(String path) {
    final fileName = path.split('/').last;
    final lastDotIndex = fileName.lastIndexOf('.');
    final baseName = lastDotIndex != -1
        ? fileName.substring(0, lastDotIndex)
        : fileName;

    // Try splitting by common delimiters
    final separators = [' - ', ' – ', ' — ', ' -', '- ', ' | '];

    for (final sep in separators) {
      if (baseName.contains(sep)) {
        final parts = baseName.split(sep);
        if (parts.length >= 2) {
          final artist = parts[0].trim();
          final title = parts.sublist(1).join(sep).trim();

          if (artist.isNotEmpty && title.isNotEmpty) {
            return {
              'artist': artist,
              'title': _cleanTitle(title),
            };
          }
        }
      }
    }

    // Single dash fallback
    if (baseName.contains('-')) {
      final parts = baseName.split('-');
      if (parts.length == 2) {
        return {
          'artist': parts[0].trim(),
          'title': _cleanTitle(parts[1].trim()),
        };
      }
    }

    return {
      'title': _cleanTitle(baseName),
      'artist': 'Unknown Artist',
    };
  }

  /// Fetches missing metadata from Deezer API
  Future<Map<String, dynamic>?> fetchOnlineMetadata(
    String artist,
    String title,
  ) async {
    try {
      final query = Uri.encodeComponent('artist:"$artist" track:"$title"');
      final url = Uri.parse('https://api.deezer.com/search?q=$query&limit=1');

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['data'] as List?;

        if (results != null && results.isNotEmpty) {
          final track = results[0];
          return {
            'title': track['title'],
            'artist': track['artist']?['name'],
            'album': track['album']?['title'],
            'duration': Duration(seconds: track['duration']),
            'artworkUrl': track['album']?['cover_xl'] ?? track['album']?['cover_big'],
          };
        }
      }
    } catch (_) {}
    return null;
  }

  String _cleanTitle(String title) {
    // Remove bracketed info common in downloads (e.g. [Official Video], (Live at ...))
    return title
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .trim();
  }
}
