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
