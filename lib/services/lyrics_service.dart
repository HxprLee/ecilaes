import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:romanize/romanize.dart';
import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import '../signals/settings_signal.dart';
import 'song_cache.dart';

/// Service to fetch lyrics from embedded metadata or online sources.
class LyricsService {
  static final LyricsService _instance = LyricsService._internal();
  factory LyricsService() => _instance;
  LyricsService._internal();

  // In-memory cache to avoid redundant lookups within a session
  final Map<String, String?> _cache = {};

  Future<String> get _cacheDir async {
    final baseDir = await SongCache.cacheDir;
    final dir = Directory('$baseDir/lyrics');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  String _getCacheFilename(String songPath) {
    return '${songPath.hashCode.abs()}.lrc';
  }

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

    // 2.5 Try persistent file cache
    try {
      final dir = await _cacheDir;
      final file = File('$dir/${_getCacheFilename(path)}');
      if (await file.exists()) {
        final content = await file.readAsString();
        _cache[path] = content;
        debugPrint('LyricsService: Found lyrics in persistent cache');
        return content;
      }
    } catch (e) {
      debugPrint('LyricsService: Error reading persistent cache: $e');
    }

    // 3. Fallback chain
    // We try multiple providers in order of reliability/quality
    final videoId = path.startsWith('yt:') ? path.substring(3) : null;

    final providersPref = settingsSignal.lyricsProviders.value;
    final enabledPrefs = settingsSignal.enabledLyricsProviders.value;

    for (final providerId in providersPref) {
      if (!enabledPrefs.contains(providerId)) continue;

      Future<String?> Function()? fetcher;
      switch (providerId) {
        case 'lrclib':
          fetcher = () => _fetchFromLrclib(title, artist, duration);
          break;
        case 'simpmusic':
          if (videoId != null) {
            fetcher = () => _fetchFromSimpMusic(videoId);
          }
          break;
        case 'better_lyrics':
          fetcher = () => _fetchFromBetterLyrics(title, artist);
          break;
        case 'kugou':
          fetcher = () => _fetchFromKuGou(title, artist, duration);
          break;
      }

      if (fetcher != null) {
        try {
          final result = await fetcher();
          if (result != null && result.trim().isNotEmpty) {
            _cache[path] = result;
            _saveToFileCache(path, result);
            return result;
          }
        } catch (e) {
          debugPrint('LyricsService: Provider $providerId error: $e');
        }
      }
    }

    _cache[path] = null;
    return null;
  }

  /// Fetch synced LRC lyrics from lrclib.net
  Future<String?> _fetchFromLrclib(
    String title,
    String artist,
    Duration? duration,
  ) async {
    // Clean title: remove bracketed info like [Official Video]
    final cleanTitle = _cleanQuery(title);
    final cleanArtist = _cleanQuery(artist);

    final query = Uri.encodeQueryComponent('$cleanArtist $cleanTitle');
    final url = 'https://lrclib.net/api/search?q=$query';

    debugPrint(
      'LyricsService: Searching lrclib.net for "$cleanArtist - $cleanTitle"',
    );

    final response = await http
        .get(Uri.parse(url), headers: {'User-Agent': 'MusicApp/1.0'})
        .timeout(const Duration(seconds: 8));

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
          debugPrint(
            'LyricsService: Found plain lyrics on lrclib.net (no sync)',
          );
          return _plainToLrc(plainLyrics);
        }
      }
    }

    debugPrint('LyricsService: lrclib.net returned ${response.statusCode}');
    return null;
  }

  /// Fetch from SimpMusic API (videoId based)
  Future<String?> _fetchFromSimpMusic(String videoId) async {
    final url = 'https://api.simpmusic.org/lyrics?videoId=$videoId';

    debugPrint('LyricsService: Searching SimpMusic for videoId: $videoId');

    try {
      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'MusicApp/1.0'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final lyrics = data['syncedLyrics'] as String?;
        if (lyrics != null && lyrics.trim().isNotEmpty) {
          debugPrint('LyricsService: Found lyrics on SimpMusic');
          return lyrics;
        }
      }
    } catch (e) {
      debugPrint('LyricsService: SimpMusic error: $e');
    }
    return null;
  }

  /// Fetch from KuGou API
  Future<String?> _fetchFromKuGou(
    String title,
    String artist,
    Duration? duration,
  ) async {
    final cleanTitle = _cleanQuery(title);
    final cleanArtist = _cleanQuery(artist);
    final keyword = Uri.encodeQueryComponent('$cleanArtist - $cleanTitle');
    final durationMs = duration?.inMilliseconds ?? 0;

    // 1. Search for candidates
    final searchUrl =
        'http://lyrics.kugou.com/search?ver=1&man=yes&client=pc&keyword=$keyword&duration=$durationMs&hash=';

    debugPrint(
      'LyricsService: Searching KuGou for "$cleanArtist - $cleanTitle"',
    );

    try {
      final searchResponse = await http
          .get(Uri.parse(searchUrl), headers: {'User-Agent': 'MusicApp/1.0'})
          .timeout(const Duration(seconds: 8));

      if (searchResponse.statusCode == 200) {
        final searchData = jsonDecode(searchResponse.body);
        final List<dynamic> candidates = searchData['candidates'] ?? [];
        if (candidates.isEmpty) return null;

        // Pick the first candidate (usually the best match)
        final candidate = candidates.first;
        final id = candidate['id'];
        final accesskey = candidate['accesskey'];

        if (id == null || accesskey == null) return null;

        // 2. Download lyrics
        final downloadUrl =
            'http://lyrics.kugou.com/download?ver=1&client=pc&id=$id&accesskey=$accesskey&fmt=lrc&charset=utf8';

        debugPrint('LyricsService: Downloading from KuGou id=$id');

        final downloadResponse = await http
            .get(
              Uri.parse(downloadUrl),
              headers: {'User-Agent': 'MusicApp/1.0'},
            )
            .timeout(const Duration(seconds: 8));

        if (downloadResponse.statusCode == 200) {
          final downloadData = jsonDecode(downloadResponse.body);
          final base64Content = downloadData['content'] as String?;
          if (base64Content != null && base64Content.isNotEmpty) {
            final decoded = utf8.decode(base64.decode(base64Content));
            debugPrint('LyricsService: Found lyrics on KuGou');
            return decoded;
          }
        }
      }
    } catch (e) {
      debugPrint('LyricsService: KuGou error: $e');
    }
    return null;
  }

  /// Fetch from BetterLyrics API
  Future<String?> _fetchFromBetterLyrics(String title, String artist) async {
    final cleanTitle = _cleanQuery(title);
    final cleanArtist = _cleanQuery(artist);

    final query = Uri.encodeQueryComponent('a=$cleanArtist&s=$cleanTitle');
    final url = 'https://better-lyrics.vercel.app/api/getLyrics?$query';

    debugPrint(
      'LyricsService: Searching BetterLyrics for "$cleanArtist - $cleanTitle"',
    );

    try {
      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'MusicApp/1.0'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final lyrics = data['lyrics'] as String?;
        if (lyrics != null && lyrics.trim().isNotEmpty) {
          debugPrint('LyricsService: Found lyrics on BetterLyrics');
          return lyrics;
        }
      }
    } catch (e) {
      debugPrint('LyricsService: BetterLyrics error: $e');
    }
    return null;
  }

  String _cleanQuery(String text) {
    return text
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .trim();
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

  Future<void> _saveToFileCache(String songPath, String content) async {
    try {
      final dir = await _cacheDir;
      final file = File('$dir/${_getCacheFilename(songPath)}');
      await file.writeAsString(content);
    } catch (e) {
      debugPrint('LyricsService: Error saving to persistent cache: $e');
    }
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
