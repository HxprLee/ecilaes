class Song {
  final String path;
  final String title;
  final String artist;
  final String? album;
  final bool hasAlbumArt; // Lightweight flag instead of storing bytes
  final String? lyrics;
  final Duration? duration;
  final int? bitrate; // in kbps

  Song({
    required this.path,
    required this.title,
    this.artist = 'Unknown Artist',
    this.album,
    this.hasAlbumArt = false,
    this.lyrics,
    this.duration,
    this.bitrate,
  });

  // Extract title from filename
  factory Song.fromPath(String path) {
    final fileName = path.split('/').last;
    final lastDotIndex = fileName.lastIndexOf('.');
    final titleWithoutExt = lastDotIndex != -1
        ? fileName.substring(0, lastDotIndex)
        : fileName;

    return Song(path: path, title: titleWithoutExt, artist: 'Unknown Artist');
  }

  Song copyWith({
    String? title,
    String? artist,
    String? album,
    bool? hasAlbumArt,
    String? lyrics,
    Duration? duration,
    int? bitrate,
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
    );
  }
}
