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

import 'song.dart';

class Artist {
  final String name;
  final List<Song> songs;
  final String? picturePath;

  Artist({required this.name, required this.songs, this.picturePath});

  int get songCount => songs.length;
  
  List<String> get albums {
    return songs
        .map((s) => s.album ?? 'Unknown Album')
        .where((a) => a.isNotEmpty)
        .toSet()
        .toList();
  }
}

class Album {
  final String name;
  final String artist;
  final List<Song> songs;

  Album({required this.name, required this.artist, required this.songs});

  int get songCount => songs.length;
  bool get hasAlbumArt => songs.any((s) => s.hasAlbumArt);
  
  String get firstSongPath => songs.firstWhere(
    (s) => s.hasAlbumArt,
    orElse: () => songs.first,
  ).path;
}
