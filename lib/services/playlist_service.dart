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
import 'package:path_provider/path_provider.dart';
import '../models/playlist.dart';

class PlaylistService {
  static const String _fileName = 'playlists.json';

  static Future<String> get _cacheDir async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/ecilaes_cache';
  }

  static Future<String> get _filePath async {
    final cache = await _cacheDir;
    return '$cache/$_fileName';
  }

  static Future<List<Playlist>> loadPlaylists() async {
    try {
      final file = File(await _filePath);
      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((json) => Playlist.fromJson(json)).toList();
    } catch (e) {
      print('Error loading playlists: $e');
      return [];
    }
  }

  static Future<void> savePlaylists(List<Playlist> playlists) async {
    try {
      final jsonList = playlists.map((p) => p.toJson()).toList();
      final file = File(await _filePath);

      // Ensure directory exists
      final dir = Directory(await _cacheDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print('Error saving playlists: $e');
    }
  }
}
