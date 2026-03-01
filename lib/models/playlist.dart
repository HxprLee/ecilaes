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
