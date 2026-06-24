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

import 'dart:convert';
import 'package:http/http.dart' as http;

class AlbumArtService {
  static final AlbumArtService _instance = AlbumArtService._internal();
  factory AlbumArtService() => _instance;
  AlbumArtService._internal();

  final Map<String, String> _urlCache = {};

  // MusicBrainz requires a descriptive User-Agent
  static const String _userAgent =
      'Ecilaes/1.0.0 ( https://github.com/lee/ecilaes )';

  Future<String?> getAlbumArtUrl(
    String artist,
    String album,
    String songTitle,
  ) async {
    final cacheKey = '$artist - $album'.toLowerCase();
    if (_urlCache.containsKey(cacheKey)) {
      return _urlCache[cacheKey];
    }

    try {
      // Strategy 1: Deezer (Fast, high coverage, no key)
      print('AlbumArtService: Trying Deezer for $artist - $songTitle');
      final deezerQuery = Uri.encodeComponent(
        'artist:"$artist" track:"$songTitle"',
      );
      final deezerUrl = Uri.parse(
        'https://api.deezer.com/search?q=$deezerQuery&limit=1',
      );
      final deezerResponse = await http.get(deezerUrl);

      if (deezerResponse.statusCode == 200) {
        final data = json.decode(deezerResponse.body);
        final results = data['data'] as List?;
        if (results != null && results.isNotEmpty) {
          final artworkUrl =
              results[0]['album']?['cover_xl'] ??
              results[0]['album']?['cover_big'];
          if (artworkUrl != null) {
            _urlCache[cacheKey] = artworkUrl;
            print('AlbumArtService: Found artwork on Deezer: $artworkUrl');
            return artworkUrl;
          }
        }
      }

      // Strategy 2: iTunes (Alternative)
      print(
        'AlbumArtService: Deezer failed, trying iTunes for $artist - $songTitle',
      );
      final iTunesQuery = Uri.encodeComponent('$artist $songTitle');
      final iTunesUrl = Uri.parse(
        'https://itunes.apple.com/search?term=$iTunesQuery&media=music&limit=1',
      );
      final iTunesResponse = await http.get(iTunesUrl);

      if (iTunesResponse.statusCode == 200) {
        final data = json.decode(iTunesResponse.body);
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final artworkUrl = results[0]['artworkUrl100']?.replaceAll(
            '100x100',
            '1000x1000',
          );
          if (artworkUrl != null) {
            _urlCache[cacheKey] = artworkUrl;
            print('AlbumArtService: Found artwork on iTunes: $artworkUrl');
            return artworkUrl;
          }
        }
      }

      print('AlbumArtService: iTunes failed, trying MusicBrainz...');

      // Strategy 3: MusicBrainz (Last resort)
      final searchStrategies = [
        'artist:"$artist" AND release:"$album"',
        'artist:"$artist" AND "$album"',
        '$artist $album',
      ];

      for (final queryText in searchStrategies) {
        final query = Uri.encodeComponent(queryText);
        final searchUrl = Uri.parse(
          'https://musicbrainz.org/ws/2/release/?query=$query&fmt=json',
        );

        final searchResponse = await http.get(
          searchUrl,
          headers: {'User-Agent': _userAgent},
        );
        if (searchResponse.statusCode == 200) {
          final searchData = json.decode(searchResponse.body);
          final releases = searchData['releases'] as List?;

          if (releases != null && releases.isNotEmpty) {
            final mbid = releases[0]['id'];
            var caaJsonUrl = Uri.parse(
              'https://coverartarchive.org/release/$mbid',
            );
            var caaResponse = await http.get(
              caaJsonUrl,
              headers: {'User-Agent': _userAgent},
            );

            if (caaResponse.statusCode == 307 ||
                caaResponse.statusCode == 302 ||
                caaResponse.statusCode == 301) {
              final location = caaResponse.headers['location'];
              if (location != null) {
                caaResponse = await http.get(
                  Uri.parse(location),
                  headers: {'User-Agent': _userAgent},
                );
              }
            }

            if (caaResponse.statusCode == 200) {
              final caaData = json.decode(caaResponse.body);
              final images = caaData['images'] as List?;
              if (images != null && images.isNotEmpty) {
                final frontImage = images.firstWhere(
                  (img) => img['front'] == true,
                  orElse: () => images[0],
                );
                final artworkUrl =
                    frontImage['thumbnails']?['500'] ?? frontImage['image'];
                if (artworkUrl != null) {
                  _urlCache[cacheKey] = artworkUrl;
                  print(
                    'AlbumArtService: Found artwork on MusicBrainz: $artworkUrl',
                  );
                  return artworkUrl;
                }
              }
            }
          }
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      print('AlbumArtService: Error fetching artwork: $e');
    }

    return null;
  }
}
