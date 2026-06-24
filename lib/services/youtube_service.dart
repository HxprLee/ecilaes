// Ecilaes - Cross-platform music player
// Copyright (C) 2024  hxprlee
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

import 'package:youtube_explode_dart/youtube_explode_dart.dart'
    hide SearchFilter;
import '../models/song.dart';
import 'YoutubeDatasource.dart';

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

  /// Searches YouTube Music and maps the results to `Song` objects
  Future<List<Song>> searchSongs(String query) async {
    return youtubeDatasource.searchSongs(query);
  }

  /// Generic YouTube Music search with filter. Returns raw maps.
  /// Set [limit] to request more than the default 20 results.
  Future<List<Map<String, dynamic>>> search(
    String query, {
    SearchFilter? filter,
    int limit = 20,
  }) async {
    return youtubeDatasource.search(query, filter: filter, limit: limit);
  }

  /// Extracts the direct audio stream URL for a given YouTube Video ID.
  /// Uses iOS client first because it produces direct CDN URLs that MPV can
  /// stream natively without going through a localhost proxy.
  Future<String?> getAudioStreamUrl(String videoId) async {
    // ios is a `final` (not const) so we build the list at runtime
    final iosClient = YoutubeApiClient.ios;

    // Try clients from most to least MPV-compatible
    final clients = <YoutubeApiClient>[
      YoutubeApiClient.androidVr, // Usually direct and most reliable in logs
      iosClient, // Direct signed URLs, no proxy
      YoutubeApiClient.tv, // Also direct, no proxy
      YoutubeApiClient.android, // May use localhost proxy on v3
    ];

    for (final client in clients) {
      final clientName =
          (client.payload['context']?['client']?['clientName'] as String?) ??
          'Unknown';
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
        if (url.startsWith('http://127.') ||
            url.startsWith('http://localhost')) {
          print('YouTube: $clientName returned proxy URL, skipping...');
          continue;
        }

        print(
          'YouTube: ✓ using $clientName | ${chosen.codec.mimeType} @ ${chosen.bitrate}',
        );
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
