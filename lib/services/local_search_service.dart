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

import '../models/song.dart';
import '../models/playlist.dart';
import '../models/library_models.dart';

class LocalSearchService {
  static bool _matches(String query, String text) {
    if (query.isEmpty) return true;
    final tokens = query.toLowerCase().trim().split(RegExp(r'\s+'));
    final t = text.toLowerCase();
    return tokens.every((token) => t.contains(token));
  }

  static List<Song> searchSongs(String query, List<Song> songs) {
    if (query.isEmpty) return [];
    return songs.where((song) {
      return _matches(query, '${song.title} ${song.artist} ${song.album ?? ""}');
    }).toList();
  }

  static List<Playlist> searchPlaylists(String query, List<Playlist> playlists) {
    if (query.isEmpty) return [];
    return playlists.where((p) => _matches(query, p.name)).toList();
  }

  static List<Album> searchAlbums(String query, List<Album> albums) {
    if (query.isEmpty) return [];
    return albums.where((a) => _matches(query, '${a.name} ${a.artist}')).toList();
  }

  static List<Artist> searchArtists(String query, List<Artist> artists) {
    if (query.isEmpty) return [];
    return artists.where((a) => _matches(query, a.name)).toList();
  }

  static List<String> searchFolders(String query, List<Song> allSongs) {
    if (query.isEmpty) return [];
    final dirs = allSongs
        .where((song) => !song.path.startsWith('yt:'))
        .map((s) => s.path.substring(0, s.path.lastIndexOf('/')))
        .where((dir) => _matches(query, dir))
        .toSet()
        .toList()
          ..sort();
    return dirs;
  }
}
