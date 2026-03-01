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
