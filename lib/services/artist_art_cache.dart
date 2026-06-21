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

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'song_cache.dart';

class ArtistArtCache {
  static final ArtistArtCache _instance = ArtistArtCache._internal();
  factory ArtistArtCache() => _instance;
  ArtistArtCache._internal();

  static const String _artistArtDirName = 'artist_art';
  String? _cachePath;

  Future<String> get _dirPath async {
    if (_cachePath != null) return _cachePath!;
    final base = await SongCache.cacheDir;
    final dir = Directory('$base/$_artistArtDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cachePath = dir.path;
    return _cachePath!;
  }

  String _getFileName(String artistName) {
    return '${artistName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}.jpg';
  }

  Future<String?> getArtPath(String artistName) async {
    final dir = await _dirPath;
    final file = File('$dir/${_getFileName(artistName)}');
    if (await file.exists()) {
      return file.path;
    }
    return null;
  }

  Future<String?> fetchAndCache(String artistName) async {
    if (artistName.isEmpty || artistName.toLowerCase() == 'unknown artist') return null;

    final existing = await getArtPath(artistName);
    if (existing != null) return existing;

    try {
      final query = Uri.encodeComponent(artistName);
      final response = await http.get(Uri.parse('https://api.deezer.com/search/artist?q=$query'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['data'] ?? [];
        if (results.isNotEmpty) {
          // Find closest match (first result)
          final artistData = results.first;
          final imageUrl = artistData['picture_medium'] ?? artistData['picture_big'];
          
          if (imageUrl != null) {
            final imgResponse = await http.get(Uri.parse(imageUrl));
            if (imgResponse.statusCode == 200) {
              final dir = await _dirPath;
              final file = File('$dir/${_getFileName(artistName)}');
              await file.writeAsBytes(imgResponse.bodyBytes);
              return file.path;
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching artist art for $artistName: $e');
    }
    return null;
  }
}
