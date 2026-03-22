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
    );
  }
}
