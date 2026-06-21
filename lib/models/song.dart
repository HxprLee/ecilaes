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

class Song {
  final String path;
  final String title;
  final String artist;
  final String? album;
  final bool hasAlbumArt; // Lightweight flag instead of storing bytes
  final String? lyrics;
  final Duration? duration;
  final int? bitrate; // in kbps
  final int? size; // in bytes
  final DateTime? modifiedAt;
  final double gainDb; // ReplayGain track gain in dB (0.0 = no adjustment)
  final double trackPeak; // ReplayGain track peak
  final double albumGainDb; // ReplayGain album gain in dB
  final double albumPeak; // ReplayGain album peak
  /// Cached YouTube Music artwork URL — set when the song is fetched from YTM API.
  final String? thumbnailUrl;

  Song({
    required this.path,
    required this.title,
    this.artist = 'Unknown Artist',
    this.album,
    this.hasAlbumArt = false,
    this.lyrics,
    this.duration,
    this.bitrate,
    this.size,
    this.modifiedAt,
    this.gainDb = 0.0,
    this.trackPeak = 1.0,
    this.albumGainDb = 0.0,
    this.albumPeak = 1.0,
    this.thumbnailUrl,
  });

  // Extract title from filename
  factory Song.fromPath(String path) {
    final fileName = path.split('/').last;
    final lastDotIndex = fileName.lastIndexOf('.');
    final titleWithoutExt = lastDotIndex != -1
        ? fileName.substring(0, lastDotIndex)
        : fileName;

    return Song(path: path, title: titleWithoutExt, artist: 'Unknown Artist', modifiedAt: DateTime.now(), gainDb: 0.0, trackPeak: 1.0, albumGainDb: 0.0, albumPeak: 1.0);
  }

  Song copyWith({
    String? title,
    String? artist,
    String? album,
    bool? hasAlbumArt,
    String? lyrics,
    Duration? duration,
    int? bitrate,
    int? size,
    DateTime? modifiedAt,
    double? gainDb,
    double? trackPeak,
    double? albumGainDb,
    double? albumPeak,
    String? thumbnailUrl,
  }) {
    return Song(
      path: path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      hasAlbumArt: hasAlbumArt ?? this.hasAlbumArt,
      lyrics: lyrics ?? this.lyrics,
      duration: duration ?? this.duration,
      bitrate: bitrate ?? this.bitrate,
      size: size ?? this.size,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      gainDb: gainDb ?? this.gainDb,
      trackPeak: trackPeak ?? this.trackPeak,
      albumGainDb: albumGainDb ?? this.albumGainDb,
      albumPeak: albumPeak ?? this.albumPeak,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'title': title,
      'artist': artist,
      'album': album,
      'hasAlbumArt': hasAlbumArt,
      'lyrics': lyrics,
      'duration': duration?.inMilliseconds,
      'bitrate': bitrate,
      'size': size,
      'modifiedAt': modifiedAt?.toIso8601String(),
      'gainDb': gainDb,
      'trackPeak': trackPeak,
      'albumGainDb': albumGainDb,
      'albumPeak': albumPeak,
    };
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      path: json['path'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String? ?? 'Unknown Artist',
      album: json['album'] as String?,
      hasAlbumArt: json['hasAlbumArt'] as bool? ?? false,
      lyrics: json['lyrics'] as String?,
      duration: json['duration'] != null
          ? Duration(milliseconds: json['duration'] as int)
          : null,
      bitrate: json['bitrate'] as int?,
      size: json['size'] as int?,
      modifiedAt: json['modifiedAt'] != null
          ? DateTime.parse(json['modifiedAt'] as String)
          : null,
      gainDb: (json['gainDb'] as num?)?.toDouble() ?? 0.0,
      trackPeak: (json['trackPeak'] as num?)?.toDouble() ?? 1.0,
      albumGainDb: (json['albumGainDb'] as num?)?.toDouble() ?? 0.0,
      albumPeak: (json['albumPeak'] as num?)?.toDouble() ?? 1.0,
    );
  }
}
