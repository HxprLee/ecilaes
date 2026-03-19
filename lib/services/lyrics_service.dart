import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:romanize/romanize.dart';
import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';

/// Service to fetch lyrics from embedded metadata or online sources.
class LyricsService {
  static final LyricsService _instance = LyricsService._internal();
  factory LyricsService() => _instance;
  LyricsService._internal();

  // In-memory cache to avoid redundant lookups within a session
  final Map<String, String?> _cache = {};

  /// Try to get lyrics for a song. Priority:
  /// 1. In-memory cache
  /// 2. Embedded metadata (LRC tags)
  /// 3. Online lookup via lrclib.net
  Future<String?> getLyrics({
    required String path,
    required String title,
    required String artist,
    Duration? duration,
  }) async {
    // 1. Cache hit
    if (_cache.containsKey(path)) {
      return _cache[path];
    }

    // 2. Try embedded lyrics from metadata using audio_metadata_reader
    if (!path.startsWith('yt:')) {
      try {
        final metadata = readMetadata(File(path), getImage: false);
        final embeddedLyrics = metadata.lyrics;
        if (embeddedLyrics != null && embeddedLyrics.trim().isNotEmpty) {
          debugPrint('LyricsService: Found embedded lyrics');
          _cache[path] = embeddedLyrics;
          return embeddedLyrics;
        }
      } catch (e) {
        debugPrint('LyricsService: Error reading embedded lyrics: $e');
      }
    }

    // 3. Online fallback via lrclib.net (free, no API key needed)
    try {
      final result = await _fetchFromLrclib(title, artist, duration);
      _cache[path] = result; // Cache even null to avoid re-fetching
      return result;
    } catch (e) {
      debugPrint('LyricsService: Online lyrics fetch error: $e');
      _cache[path] = null;
      return null;
    }
  }

  /// Fetch synced LRC lyrics from lrclib.net
  Future<String?> _fetchFromLrclib(
    String title,
    String artist,
    Duration? duration,
  ) async {
    // Clean title: remove bracketed info like [Official Video]
    final cleanTitle = title
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .trim();
    final cleanArtist = artist
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .trim();

    final query = Uri.encodeQueryComponent('$cleanArtist $cleanTitle');
    final url = 'https://lrclib.net/api/search?q=$query';

    debugPrint('LyricsService: Searching lrclib.net for "$cleanArtist - $cleanTitle"');

    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'MusicApp/1.0'},
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final List<dynamic> results = jsonDecode(response.body);
      if (results.isEmpty) {
        debugPrint('LyricsService: No results found on lrclib.net');
        return null;
      }

      // Prefer synced (LRC) lyrics over plain text
      for (final result in results) {
        final syncedLyrics = result['syncedLyrics'] as String?;
        if (syncedLyrics != null && syncedLyrics.trim().isNotEmpty) {
          debugPrint('LyricsService: Found synced lyrics on lrclib.net');
          return syncedLyrics;
        }
      }

      // Fall back to plain lyrics (wrap in a simple LRC format)
      for (final result in results) {
        final plainLyrics = result['plainLyrics'] as String?;
        if (plainLyrics != null && plainLyrics.trim().isNotEmpty) {
          debugPrint('LyricsService: Found plain lyrics on lrclib.net (no sync)');
          return _plainToLrc(plainLyrics);
        }
      }
    }

    debugPrint('LyricsService: lrclib.net returned ${response.statusCode}');
    return null;
  }

  /// Convert plain text lyrics to a basic LRC format
  /// Each line gets a timestamp spaced 5 seconds apart (approximation)
  String _plainToLrc(String plain) {
    final lines = plain.split('\n');
    final buffer = StringBuffer();
    for (int i = 0; i < lines.length; i++) {
      final seconds = i * 5;
      final min = (seconds ~/ 60).toString().padLeft(2, '0');
      final sec = (seconds % 60).toString().padLeft(2, '0');
      buffer.writeln('[$min:$sec.00] ${lines[i]}');
    }
    return buffer.toString();
  }

  /// Clear the in-memory cache (e.g., on library rescan)
  void clearCache() {
    _cache.clear();
  }
}

class LyricLine {
  final Duration time;
  final String content;
  final String? romanizedContent;

  LyricLine({required this.time, required this.content, this.romanizedContent});
}

/// Simple LRC parser
List<LyricLine> parseLyrics(String lyrics) {
  final lines = <LyricLine>[];
  final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

  for (final line in lyrics.split('\n')) {
    final match = regex.firstMatch(line);
    if (match != null) {
      final min = int.parse(match.group(1)!);
      final sec = int.parse(match.group(2)!);
      final msStr = match.group(3)!;
      // Handle 2-digit vs 3-digit ms
      final ms = msStr.length == 2 ? int.parse(msStr) * 10 : int.parse(msStr);
      final text = match.group(4)!.trim();

      // Only add if not empty or just spaces
      if (text.isNotEmpty) {
        String? romanized;
        try {
          final rom = TextRomanizer.romanize(text);
          if (rom != text && rom.isNotEmpty) {
            romanized = rom;
          }
        } catch (e) {
          // Ignore romanize errors
        }

        lines.add(
          LyricLine(
            time: Duration(minutes: min, seconds: sec, milliseconds: ms),
            content: text,
            romanizedContent: romanized,
          ),
        );
      }
    }
  }

  // If no synced lines were found, try to parse as plain text
  if (lines.isEmpty && lyrics.trim().isNotEmpty) {
    debugPrint('LyricsService: No synced tags found, parsing as plain text');
    final plainLines = lyrics.split('\n');
    for (final line in plainLines) {
      final text = line.trim();
      if (text.isNotEmpty) {
        lines.add(LyricLine(time: Duration.zero, content: text));
      }
    }
  }

  // Ensure sorted by time
  lines.sort((a, b) => a.time.compareTo(b.time));
  return lines;
}
