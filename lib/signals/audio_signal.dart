import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:signals/signals_flutter.dart';
import 'settings_signal.dart';
import 'package:uuid/uuid.dart';
import 'package:metadata_god/metadata_god.dart';

import '../models/song.dart';
import '../models/playlist.dart';
import '../services/audio_handler.dart';
import '../services/song_cache.dart';
import '../services/platform_service.dart';
import '../services/album_art_service.dart';
import '../services/playlist_service.dart';

class AudioSignal {
  static final AudioSignal _instance = AudioSignal._internal();
  factory AudioSignal() => _instance;
  AudioSignal._internal();

  late final AudioHandler _audioHandler;
  Timer? _discordTimer;

  // Signals
  final isPlaying = signal<bool>(false);
  final currentSong = signal<Song?>(null);
  final position = signal<Duration>(Duration.zero);
  final duration = signal<Duration>(Duration.zero);
  final allSongs = listSignal<Song>([]);
  final playlists = listSignal<Playlist>([]);
  final currentPlaylist = signal<Playlist?>(null);
  final isScanning = signal<bool>(false);
  final searchQuery = signal<String>('');
  final isShuffleMode = signal<bool>(false);
  final playerExpansion = signal<double>(0.0);
  final headerShowBlur = signal<bool>(false);
  late final showPlayer = computed(
    () => currentSong.value != null || isDesktop,
  );
  late final reservedHeight = computed(() {
    if (isDesktop) {
      return showPlayer.value ? 104.0 : 24.0;
    } else {
      return 56.0 + (showPlayer.value ? 80.0 : 0.0) + 24.0;
    }
  });

  // Caches
  final Map<String, Song> _explorerSongCache = {};

  // Computed for backward compatibility or simple checks
  late final isPlayerExpanded = computed(() => playerExpansion.value > 0.1);

  // Computed
  late final searchResults = computed(() {
    final query = searchQuery.value.toLowerCase();
    if (query.isEmpty) return <Song>[];
    return allSongs.value.where((song) {
      return song.title.toLowerCase().contains(query) ||
          song.artist.toLowerCase().contains(query) ||
          (song.album?.toLowerCase().contains(query) ?? false);
    }).toList();
  });

  late final recentlyAdded = computed(() {
    return allSongs.value.take(10).toList();
  });

  late final recentlyPlayed = computed(() {
    return allSongs.value.take(6).toList();
  });

  bool get isDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  Future<void> init(AudioHandler handler) async {
    _audioHandler = handler;

    if (isDesktop) {
      _discordTimer = Timer.periodic(const Duration(seconds: 7), (_) {
        _updateDiscordPresence();
      });
    }

    // Listen to streams
    _audioHandler.playbackState.listen((state) {
      isPlaying.value = state.playing;
      isShuffleMode.value = state.shuffleMode == AudioServiceShuffleMode.all;
    });

    _audioHandler.mediaItem.listen((item) {
      if (item != null) {
        duration.value = item.duration ?? Duration.zero;
        try {
          final song = allSongs.value.firstWhere((s) => s.path == item.id);
          currentSong.value = song;
        } catch (_) {}
      }
    });

    if (_audioHandler is MyAudioHandler) {
      _audioHandler.player.positionStream.listen((pos) {
        position.value = pos;
      });
    }

    // Load cache and start scan in background
    unawaited(_loadCacheAndScan());
    unawaited(_loadPlaylists());
  }

  // Discord RPC
  String? _lastDiscordSongPath;
  bool? _lastDiscordIsPlaying;
  int? _discordPlaybackStartTime;
  String? _cachedArtworkUrl;

  Future<void> _updateDiscordPresence() async {
    final song = currentSong.value;
    final playing = isPlaying.value;

    if (song == null || !isDesktop) return;

    // If nothing changed, we don't strictly need to update every time,
    // but the task asks for periodic updates. However, we should avoid
    // re-fetching artwork if not necessary.
    if (_lastDiscordSongPath == song.path && _lastDiscordIsPlaying == playing) {
      if (!playing)
        return; // If paused and already sent pause, no need to resend

      // If playing, we might want to resend to keep presence alive,
      // but only if we have the cached info.
      if (_cachedArtworkUrl != null) {
        await PlatformService().updatePresence(
          song,
          artworkUrl: _cachedArtworkUrl,
          isPlaying: true,
          startTimeStamp: _discordPlaybackStartTime,
        );
      }
      return;
    }

    // State changed
    if (_lastDiscordSongPath != song.path ||
        (playing && !_lastDiscordIsPlaying!)) {
      // New song or resumed playback
      _discordPlaybackStartTime = DateTime.now().millisecondsSinceEpoch;
    } else if (!playing) {
      // Paused
      _discordPlaybackStartTime = null;
    }

    _lastDiscordSongPath = song.path;
    _lastDiscordIsPlaying = playing;

    _cachedArtworkUrl = await AlbumArtService().getAlbumArtUrl(
      song.artist,
      song.album ?? '',
      song.title,
    );

    await PlatformService().updatePresence(
      song,
      artworkUrl: _cachedArtworkUrl,
      isPlaying: playing,
      startTimeStamp: _discordPlaybackStartTime,
    );
  }

  Future<void> _loadCacheAndScan() async {
    final cachedSongs = await SongCache.loadCache();
    if (cachedSongs.isNotEmpty) {
      allSongs.value = cachedSongs;
      // Don't auto-load playlist on startup - wait for user to play
    }
    await scanMusicDirectory();
  }

  Future<void> scanMusicDirectory() async {
    if (isScanning.value) return;
    isScanning.value = true;

    final receivePort = ReceivePort();
    final exitPort = ReceivePort();
    Isolate? isolate;

    try {
      final musicPath = await getMusicPath();
      if (musicPath.isEmpty) {
        isScanning.value = false;
        return;
      }

      final musicDir = Directory(musicPath);
      if (!await musicDir.exists()) {
        isScanning.value = false;
        return;
      }

      final cachedPaths = allSongs.value.map((s) => s.path).toSet();
      final artDir = await SongCache.artDir;

      print(
        'Starting rock-solid streaming background directory scan: $musicPath',
      );

      isolate = await Isolate.spawn(_indexingIsolateEntry, {
        'sendPort': receivePort.sendPort,
        'musicPath': musicPath,
        'cachedPaths': cachedPaths,
        'artDir': artDir,
      });

      // Robust monitoring: if isolate exits unexpectedly, we still clear isScanning
      isolate.addOnExitListener(exitPort.sendPort);

      final List<Song> batch = [];
      final stopwatch = Stopwatch()..start();

      bool isolateDone = false;

      // Listen for exit in the background
      exitPort.first.then((_) {
        if (!isolateDone) {
          print('Isolate exited unexpectedly');
          isScanning.value = false;
          receivePort.close();
          exitPort.close();
        }
      });

      await for (final message in receivePort) {
        if (message is Song) {
          batch.add(message);

          if (batch.length >= 20 || stopwatch.elapsedMilliseconds > 500) {
            allSongs.addAll(batch);
            batch.clear();
            stopwatch.reset();
          }
        } else if (message == 'done') {
          print('Background scan complete.');
          isolateDone = true;
          break;
        } else if (message is Map && message['type'] == 'progress') {
          print('Scan progress: ${message['count']} found');
        } else if (message is Map && message['type'] == 'error') {
          print('Isolate error: ${message['message']}');
        }
      }

      // Add remaining songs
      if (batch.isNotEmpty) {
        allSongs.addAll(batch);
      }

      if (allSongs.value.isNotEmpty) {
        await SongCache.saveCache(allSongs.value);
        // Don't auto-load playlist - wait for user to play a song
      }
    } catch (e) {
      print('Error during scan: $e');
    } finally {
      receivePort.close();
      exitPort.close();
      isolate?.kill(priority: Isolate.immediate);
      isScanning.value = false;
    }
  }

  Future<void> reindexLibrary() async {
    allSongs.value = []; // Clear in-memory
    await SongCache.clearCache(); // Clear disk cache
    await scanMusicDirectory(); // Rescan
  }

  // Removed _scanDirectory in favor of _performFullScan in isolate

  // Playback Control
  Future<void> play() => _audioHandler.play();
  Future<void> pause() => _audioHandler.pause();
  Future<void> seek(Duration pos) => _audioHandler.seek(pos);
  Future<void> skipNext() => _audioHandler.skipToNext();
  Future<void> skipPrevious() => _audioHandler.skipToPrevious();
  Future<void> stop() async {
    await _audioHandler.stop();
    currentSong.value = null;
    isPlaying.value = false;
    position.value = Duration.zero;
  }

  Future<void> playSong(Song song) async {
    if (_audioHandler is MyAudioHandler) {
      final queue = _audioHandler.queue.value;
      final isInQueue = queue.any((item) => item.id == song.path);

      if (!isInQueue) {
        // Song not in current queue (playlist), switch context
        final isInLibrary = allSongs.value.any((s) => s.path == song.path);

        if (isInLibrary) {
          // Switch to All Songs
          await _audioHandler.setPlaylist(allSongs.value);
        } else {
          // Play just this song (external file)
          await _audioHandler.setPlaylist([song]);
        }
      }

      await _audioHandler.playSong(song);
    }
  }

  Future<void> playFile(File file) async {
    try {
      final song = allSongs.value.firstWhere((s) => s.path == file.path);
      await playSong(song);
    } catch (_) {
      final song = Song.fromPath(file.path);
      await playSong(song);
    }
  }

  Future<void> toggleShuffle() async {
    final currentMode = _audioHandler.playbackState.value.shuffleMode;
    final newMode = currentMode == AudioServiceShuffleMode.all
        ? AudioServiceShuffleMode.none
        : AudioServiceShuffleMode.all;
    await _audioHandler.setShuffleMode(newMode);
  }

  // Playlist Management
  Future<void> _loadPlaylists() async {
    playlists.value = await PlaylistService.loadPlaylists();
  }

  Future<void> createPlaylist(String name) async {
    final playlist = Playlist(
      id: const Uuid().v4(),
      name: name,
      songPaths: [],
      createdAt: DateTime.now(),
    );
    playlists.add(playlist);
    await PlaylistService.savePlaylists(playlists.value);
  }

  Future<void> deletePlaylist(String id) async {
    playlists.removeWhere((p) => p.id == id);
    await PlaylistService.savePlaylists(playlists.value);
  }

  Future<void> addSongToPlaylist(String playlistId, String songPath) async {
    final index = playlists.value.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final playlist = playlists[index];
      if (!playlist.songPaths.contains(songPath)) {
        final updated = playlist.copyWith(
          songPaths: [...playlist.songPaths, songPath],
        );
        playlists[index] = updated;
        await PlaylistService.savePlaylists(playlists.value);
      }
    }
  }

  Future<void> removeSongFromPlaylist(
    String playlistId,
    String songPath,
  ) async {
    final index = playlists.value.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final playlist = playlists[index];
      final newPaths = List<String>.from(playlist.songPaths)..remove(songPath);
      playlists[index] = playlist.copyWith(songPaths: newPaths);
      await PlaylistService.savePlaylists(playlists.value);
    }
  }

  void setCurrentPlaylist(Playlist? playlist) {
    currentPlaylist.value = playlist;
  }

  Future<void> playPlaylist(Playlist playlist) async {
    final songs = playlist.songPaths
        .map(
          (path) => allSongs.value.firstWhere(
            (s) => s.path == path,
            orElse: () => Song.fromPath(path),
          ),
        )
        .toList();

    if (songs.isNotEmpty && _audioHandler is MyAudioHandler) {
      await _audioHandler.setPlaylist(songs);
      await _audioHandler.playSong(songs.first);
    }
  }

  // File Explorer Helpers
  Future<String> getMusicPath() async {
    return (await _getMusicPath()) ?? '';
  }

  Future<String?> _getMusicPath() async {
    final customPath = settingsSignal.musicDirectory.value;
    if (customPath != null && customPath.isNotEmpty) {
      final dir = Directory(customPath);
      if (await dir.exists()) {
        return customPath;
      }
    }

    if (Platform.isAndroid) {
      return '/storage/emulated/0/Music';
    } else {
      final home = Platform.environment['HOME'];
      if (home != null) {
        return '$home/Music';
      }
    }
    return null;
  }

  Future<List<FileSystemEntity>> fetchExplorerItems(String path) async {
    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        final List<FileSystemEntity> items = [];
        await for (final entity in dir.list()) {
          if (entity is Directory) {
            if (await _hasMusic(entity)) items.add(entity);
          } else if (entity is File) {
            if (_isSupportedAudio(entity.path)) items.add(entity);
          }
        }
        items.sort((a, b) {
          if (a is Directory && b is File) return -1;
          if (a is File && b is Directory) return 1;
          return a.path.toLowerCase().compareTo(b.path.toLowerCase());
        });
        return items;
      }
    } catch (_) {}
    return [];
  }

  // Removed _isSupportedAudio from class

  Future<bool> _hasMusic(Directory dir) async {
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && _isSupportedAudio(entity.path)) return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> addFolderToPlaylist(String playlistId, String folderPath) async {
    final dir = Directory(folderPath);
    if (await dir.exists()) {
      final List<String> songsToAdd = [];
      try {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File && _isSupportedAudio(entity.path)) {
            songsToAdd.add(entity.path);
          }
        }
      } catch (_) {}

      if (songsToAdd.isNotEmpty) {
        final index = playlists.value.indexWhere((p) => p.id == playlistId);
        if (index != -1) {
          final playlist = playlists[index];
          final newPaths = List<String>.from(playlist.songPaths);
          for (final path in songsToAdd) {
            if (!newPaths.contains(path)) {
              newPaths.add(path);
            }
          }
          playlists[index] = playlist.copyWith(songPaths: newPaths);
          await PlaylistService.savePlaylists(playlists.value);
        }
      }
    }
  }

  Future<Song> getExplorerSong(File file) async {
    // 1. Check library
    try {
      return allSongs.value.firstWhere((s) => s.path == file.path);
    } catch (_) {}

    // 2. Check explorer cache
    if (_explorerSongCache.containsKey(file.path)) {
      return _explorerSongCache[file.path]!;
    }

    // 3. Extract metadata
    try {
      final metadata = await Isolate.run(
        () => _extractMetadata(file.path, null),
      );
      final song = Song(
        path: file.path,
        title: (metadata['title'] as String?)?.isNotEmpty == true
            ? metadata['title']
            : Song.fromPath(file.path).title,
        artist: metadata['artist'] ?? 'Unknown Artist',
        album: metadata['album'],
        duration: metadata['duration'],
      );
      _explorerSongCache[file.path] = song;
      return song;
    } catch (_) {
      return Song.fromPath(file.path);
    }
  }

  void dispose() {
    _discordTimer?.cancel();
  }
}

final audioSignal = AudioSignal();

bool _isSupportedAudio(String path) {
  final p = path.toLowerCase();
  return p.endsWith('.mp3') ||
      p.endsWith('.m4a') ||
      p.endsWith('.wav') ||
      p.endsWith('.flac') ||
      p.endsWith('.ogg');
}

/// Entry point for the streaming indexing isolate
Future<void> _indexingIsolateEntry(Map<String, dynamic> params) async {
  final SendPort sendPort = params['sendPort'];
  final String musicPath = params['musicPath'];
  final Set<String> cachedPaths = params['cachedPaths'];
  final String artDir = params['artDir'];

  try {
    MetadataGod.initialize();
    final dir = Directory(musicPath);
    if (!dir.existsSync()) {
      sendPort.send('done');
      return;
    }

    // 1. Discover files ASYNCHRONOUSLY to avoid blocking
    final List<String> filesToProcess = [];
    int foundCount = 0;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && _isSupportedAudio(entity.path)) {
        if (!cachedPaths.contains(entity.path)) {
          filesToProcess.add(entity.path);
          foundCount++;

          // Periodic progress update during discovery
          if (foundCount % 50 == 0) {
            sendPort.send({'type': 'progress', 'count': foundCount});
          }
        }
      }
    }

    if (filesToProcess.isEmpty) {
      sendPort.send('done');
      return;
    }

    // 2. Process files sequentially to avoid memory spikes
    for (final path in filesToProcess) {
      try {
        final metadata = await MetadataGod.readMetadata(file: path);

        bool hasArt = false;
        if (metadata.picture != null) {
          try {
            final artPath = '$artDir/${path.hashCode.abs()}.jpg';
            await File(artPath).writeAsBytes(metadata.picture!.data);
            hasArt = true;
          } catch (_) {}
        }

        // Calculate bitrate from file size and duration (lightweight)
        int? bitrate;
        if (metadata.durationMs != null && metadata.durationMs! > 0) {
          final fileSizeBytes = await File(path).length();
          final durationSeconds = metadata.durationMs! / 1000;
          bitrate = ((fileSizeBytes * 8) / durationSeconds / 1000).round();
        }

        final song = Song(
          path: path,
          title: (metadata.title != null && metadata.title!.trim().isNotEmpty)
              ? metadata.title!
              : Song.fromPath(path).title,
          artist: metadata.artist ?? 'Unknown Artist',
          album: metadata.album,
          hasAlbumArt: hasArt,
          duration: metadata.durationMs != null
              ? Duration(milliseconds: metadata.durationMs!.toInt())
              : null,
          bitrate: bitrate,
        );

        sendPort.send(song);
      } catch (e) {
        sendPort.send(Song.fromPath(path));
      }
    }
  } catch (e) {
    sendPort.send({'type': 'error', 'message': e.toString()});
  } finally {
    sendPort.send('done');
  }
}

/// Top-level helper for isolate-based metadata extraction
Future<Map<String, dynamic>> _extractMetadata(
  String path,
  String? artDir,
) async {
  try {
    MetadataGod.initialize();
    final metadata = await MetadataGod.readMetadata(file: path);

    if (metadata.picture != null && artDir != null) {
      try {
        final artPath = '$artDir/${path.hashCode.abs()}.jpg';
        await File(artPath).writeAsBytes(metadata.picture!.data);
      } catch (_) {}
    }

    return {
      'title': (metadata.title != null && metadata.title!.trim().isNotEmpty)
          ? metadata.title
          : null,
      'artist': metadata.artist,
      'album': metadata.album,
      'duration': metadata.durationMs != null
          ? Duration(milliseconds: metadata.durationMs!.toInt())
          : null,
    };
  } catch (_) {
    return {};
  }
}
