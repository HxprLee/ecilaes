import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

class YoutubeService {
  static final YoutubeService _instance = YoutubeService._internal();
  factory YoutubeService() => _instance;
  YoutubeService._internal();

  final YoutubeExplode _yt = YoutubeExplode();

  /// Info about the last successfully resolved audio stream.
  /// Used by the player UI to display quality information.
  String? lastStreamMimeType;
  int? lastStreamBitrateKbps; // e.g. 127

  void dispose() {
    _yt.close();
  }

  /// Searches YouTube and maps the results to `Song` objects
  Future<List<Song>> searchSongs(String query) async {
    try {
      final results = await _yt.search.search(query);
      debugPrint('YouTube: Found ${results.length} results for "$query"');
      return results.map((video) {
        return Song(
          path: 'yt:${video.id.value}',
          title: video.title,
          artist: video.author,
          duration: video.duration,
          hasAlbumArt: true,
        );
      }).toList();
    } catch (e) {
      debugPrint('YouTube: Search error for "$query": $e');
      rethrow;
    }
  }

  /// Extracts the direct audio stream URL for a given YouTube Video ID.
  /// Uses iOS client first because it produces direct CDN URLs that MPV can
  /// stream natively without going through a localhost proxy.
  Future<String?> getAudioStreamUrl(String videoId) async {
    // ios is a `final` (not const) so we build the list at runtime
    final iosClient = YoutubeApiClient.ios;

    // Try clients from most to least MPV-compatible
    final clients = <YoutubeApiClient>[
      YoutubeApiClient.androidVr,      // Usually direct and most reliable in logs
      iosClient,                       // Direct signed URLs, no proxy
      YoutubeApiClient.tv,             // Also direct, no proxy
      YoutubeApiClient.android,        // May use localhost proxy on v3
    ];

    for (final client in clients) {
      final clientName =
          (client.payload['context']?['client']?['clientName'] as String?) ?? 'Unknown';
      try {
        print('YouTube: trying client $clientName...');
        final manifest = await _yt.videos.streamsClient.getManifest(
          videoId,
          ytClients: [client],
        );
        final audioStreams = manifest.audioOnly.toList();

        if (audioStreams.isEmpty) continue;

        // Sort by bitrate descending
        audioStreams.sort((a, b) => b.bitrate.compareTo(a.bitrate));

        // Prefer MP4/AAC (more MPV-compatible) over WebM/Opus
        final chosen = audioStreams.firstWhere(
          (s) =>
              s.codec.mimeType.contains('mp4') ||
              s.codec.mimeType.contains('aac'),
          orElse: () => audioStreams.first,
        );

        final url = chosen.url.toString();
        // Reject localhost proxy URLs — they won't work with MPV
        if (url.startsWith('http://127.') || url.startsWith('http://localhost')) {
          print('YouTube: $clientName returned proxy URL, skipping...');
          continue;
        }

        print('YouTube: ✓ using $clientName | ${chosen.codec.mimeType} @ ${chosen.bitrate}');
        // Store for UI display in the player badge
        lastStreamMimeType = chosen.codec.mimeType;
        // Bitrate comes as bps e.g. 127520 -> 127 kbps
        lastStreamBitrateKbps = chosen.bitrate.bitsPerSecond ~/ 1000;
        return url;
      } catch (e) {
        print('YouTube: $clientName failed: $e');
      }
    }

    print('YouTube: all clients failed for $videoId');
    return null;
  }
}

final youtubeService = YoutubeService();
