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

class HistoryEntry {
  final String songPath;
  final int playCount;
  final DateTime lastPlayed;

  HistoryEntry({
    required this.songPath,
    required this.playCount,
    required this.lastPlayed,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      songPath: json['songPath'],
      playCount: json['playCount'] ?? 0,
      lastPlayed: DateTime.parse(json['lastPlayed']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'songPath': songPath,
      'playCount': playCount,
      'lastPlayed': lastPlayed.toIso8601String(),
    };
  }

  HistoryEntry copyWith({
    String? songPath,
    int? playCount,
    DateTime? lastPlayed,
  }) {
    return HistoryEntry(
      songPath: songPath ?? this.songPath,
      playCount: playCount ?? this.playCount,
      lastPlayed: lastPlayed ?? this.lastPlayed,
    );
  }
}
