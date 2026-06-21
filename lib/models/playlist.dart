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

class Playlist {
  final String id;
  final String name;
  final List<String> songPaths;
  final DateTime createdAt;
  final String? imagePath;

  Playlist({
    required this.id,
    required this.name,
    required this.songPaths,
    required this.createdAt,
    this.imagePath,
  });

  Playlist copyWith({
    String? name,
    List<String>? songPaths,
    String? imagePath,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      songPaths: songPaths ?? this.songPaths,
      createdAt: createdAt,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'songPaths': songPaths,
      'createdAt': createdAt.toIso8601String(),
      'imagePath': imagePath,
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'],
      name: json['name'],
      songPaths: List<String>.from(json['songPaths']),
      createdAt: DateTime.parse(json['createdAt']),
      imagePath: json['imagePath'],
    );
  }
}
