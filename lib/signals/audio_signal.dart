import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:signals/signals_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:http/http.dart' as http;
import 'settings_signal.dart';
import 'package:uuid/uuid.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';

import '../models/song.dart';
import '../models/playlist.dart';
import '../services/audio_handler.dart';
import '../services/song_cache.dart';
import '../services/platform_service.dart';
import '../services/album_art_service.dart';
import '../services/playlist_service.dart';
import '../services/playback_history_service.dart';
import '../services/youtube_service.dart';
import '../models/history_entry.dart';
import '../services/metadata_service.dart';
import '../services/album_art_cache.dart';
import '../services/lyrics_service.dart';

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
  final historySongs = listSignal<HistoryEntry>([]);
  final queue = listSignal<MediaItem>([]);
  final isHistoryGridView = signal<bool>(false);
  final currentPlaylist = signal<Playlist?>(null);
  final isScanning = signal<bool>(false);
  final scanProgress = signal<double>(0.0);
  final searchQuery = signal<String>('');
  final isShuffleMode = signal<bool>(false);
  final repeatMode = signal<AudioServiceRepeatMode>(AudioServiceRepeatMode.none);
  final shuffledIndices = listSignal<int>([]);
  final playerExpansion = signal<double>(0.0);
  final headerShowBlur = signal<bool>(false);
  final headerTitleProgress = signal<double>(0.0);
  final headerArtCover = signal<String?>(null);
  late final showPlayer = computed(
    () => currentSong.value != null || isDesktop,
  );
  final dynamicThemeSeed = signal<Color?>(null);
  final dominantColor = signal<Color?>(null);
  final mutedColor = signal<Color?>(null);
  final sleepTimerRemaining = signal<Duration?>(null);
  Timer? _sleepInternalTimer;
  final bottomPadding = signal<double>(0.0);
  final minimizePlayerTrigger = signal<int>(0);
  final albumArtDir = signal<String?>(null);
  final currentLyrics = signal<String?>(null);
  final showLyrics = signal<bool>(false);

  late final songMap = computed(() {
    return {for (var s in allSongs.value) s.path: s};
  });
  late final reservedHeight = computed(() {
    if (isDesktop) {
      // 80.0 is Player Bar, 24.0 is Player Margin
      final playerHeight = showPlayer.value ? (80.0 + 24.0) : 0.0;
      return playerHeight + 24.0; // User safety gap
    } else {
      // 56.0 is Nav Bar, 80.0 is Player Bar, 18.0 is Player Margin
      final navBarHeight = 56.0 + bottomPadding.value;
      final playerHeight = showPlayer.value ? (80.0 + 18.0) : 0.0;
      return navBarHeight + playerHeight + 24.0; // User safety gap
    }
  });

  // Caches
  final Map<String, Song> _explorerSongCache = {};

  final youtubeSearchResults = listSignal<Song>([]);
  final isSearchingYoutube = signal<bool>(false);
  Timer? _searchDebounce;

  // Computed for backward compatibility or simple checks
  late final isPlayerExpanded = computed(() => playerExpansion.value > 0.1);

  // Computed
  late final localSearchResults = computed(() {
    final query = searchQuery.value.toLowerCase();
    if (query.isEmpty) return <Song>[];
    return allSongs.value.where((song) {
      return song.title.toLowerCase().contains(query) ||
          song.artist.toLowerCase().contains(query) ||
          (song.album?.toLowerCase().contains(query) ?? false);
    }).toList();
  });

  late final searchResults = computed(() {
    return [...localSearchResults.value, ...youtubeSearchResults.value];
  });

  late final recentlyAdded = computed(() {
    final songs = List<Song>.from(allSongs.value);
    songs.sort((a, b) {
      final aDate = a.modifiedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.modifiedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return songs.take(50).toList();
  });

  late final recentlyPlayed = computed(() {
    final map = songMap.value;
    return historySongs.value.take(10).map((h) => map[h.songPath]).whereType<Song>().toList();
  });

  late final effectiveQueue = computed(() {
    final q = queue.value;
    final indices = shuffledIndices.value;

    if (indices.isNotEmpty && q.isNotEmpty && indices.length == q.length) {
      try {
        return indices.map((i) => q[i]).toList();
      } catch (_) {
        return q;
      }
    }
    return q;
  });

  late final currentQueueIndex = computed(() {
    final q = effectiveQueue.value;
    final current = currentSong.value;
    if (current == null || q.isEmpty) return -1;
    return q.indexWhere((item) => item.id == current.path);
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
    // Initialize album art directory
    unawaited(SongCache.artDir.then((path) {
      albumArtDir.value = path;
    }));

    // Listen to streams
    _audioHandler.playbackState.listen((state) {
      isPlaying.value = state.playing;
      isShuffleMode.value = state.shuffleMode == AudioServiceShuffleMode.all;
      repeatMode.value = state.repeatMode;
    });
    _audioHandler.mediaItem.listen((item) {
      if (item != null) {
        duration.value = item.duration ?? Duration.zero;
        try {
          // First try local song map
          Song? song = songMap.value[item.id];

          // For YouTube songs (yt: prefix), look up in youtubeSearchResults
          if (song == null && item.id.startsWith('yt:')) {
            song = youtubeSearchResults.value.firstWhere(
              (s) => s.path == item.id,
              orElse: () => Song(
                path: item.id,
                title: item.title,
                artist: item.artist ?? 'YouTube',
                duration: item.duration,
                hasAlbumArt: true,
              ),
            );
          }

          if (song != null) {
            currentSong.value = song;
            _updateDynamicTheme(song);
            _loadLyricsForSong(song);

            // Lazy metadata fix for untagged local songs
            if (!song.path.startsWith('yt:') &&
                (song.artist == 'Unknown Artist' || song.album == null)) {
              unawaited(_refreshMetadata(song));
            }
          }
        } catch (_) {}
      }
    });

    _audioHandler.queue.listen((items) {
      queue.value = items;
    });

    if (_audioHandler is MyAudioHandler) {
      final myHandler = _audioHandler;
      myHandler.player.positionStream.listen((pos) {
        position.value = pos;
      });
      myHandler.shuffleIndicesStream.listen((indices) {
        shuffledIndices.value = indices;
      });
    }

    // YouTube search effect
    effect(() {
      final query = searchQuery.value;
      _searchDebounce?.cancel();

      if (query.isEmpty) {
        youtubeSearchResults.value = [];
        return;
      }

      _searchDebounce = Timer(const Duration(milliseconds: 700), () async {
        try {
          final trimmedQuery = query.trim();
          if (trimmedQuery.isEmpty) return;

          isSearchingYoutube.value = true;
          debugPrint(
              'AudioSignal: Debounced search for "$trimmedQuery" starting...');
          final results = await youtubeService.searchSongs(trimmedQuery);
          youtubeSearchResults.value = results;
          debugPrint(
              'AudioSignal: Search results updated (${results.length} songs)');
        } catch (e) {
          debugPrint('AudioSignal: YouTube search error: $e');
        } finally {
          isSearchingYoutube.value = false;
        }
      });
    });

    // Load cache and start scan in background
    unawaited(_loadCacheAndScan());
    unawaited(_loadPlaylists());
    unawaited(_loadHistory());
  }

  Future<void> _refreshMetadata(Song song) async {
    final parsed = MetadataService().parseFromFilename(song.path);
    final online = await MetadataService().fetchOnlineMetadata(
      parsed['artist'] ?? song.artist,
      parsed['title'] ?? song.title,
    );

    if (online != null) {
      final updatedSong = song.copyWith(
        title: online['title'] ?? song.title,
        artist: online['artist'] ?? song.artist,
        album: online['album'] ?? song.album,
        duration: online['duration'] ?? song.duration,
      );

      // Update in all signals/maps
      batch(() {
        if (this.currentSong.value?.path == song.path) {
          this.currentSong.value = updatedSong;
        }

        final index = allSongs.value.indexWhere((s) => s.path == song.path);
        if (index != -1) {
          final newList = List<Song>.from(allSongs.value);
          newList[index] = updatedSong;
          allSongs.value = newList;
        }

        final newMap = Map<String, Song>.from(songMap.value);
        newMap[song.path] = updatedSong;
        // songMap is a Computed, it updates automatically when allSongs changes
      });

      // Persist to cache
      await SongCache.saveCache(allSongs.value);

      // If we found a new artwork URL and the song didn't have art, we could fetch it too
      if (!song.hasAlbumArt && online['artworkUrl'] != null) {
        try {
          final artResponse = await http.get(Uri.parse(online['artworkUrl']));
          if (artResponse.statusCode == 200) {
            final artDir = await SongCache.artDir;
            final artPath = '$artDir/${song.path.hashCode.abs()}.jpg';
            await File(artPath).writeAsBytes(artResponse.bodyBytes);

            // Mark as having art and update again
            final withArt = updatedSong.copyWith(hasAlbumArt: true);
            batch(() {
              if (currentSong.value?.path == song.path) {
                currentSong.value = withArt;
              }
              final idx = allSongs.value.indexWhere((s) => s.path == song.path);
              if (idx != -1) {
                final newList = List<Song>.from(allSongs.value);
                newList[idx] = withArt;
                allSongs.value = newList;
              }
            });
            await SongCache.saveCache(allSongs.value);
            _updateDynamicTheme(withArt);
          }
        } catch (e) {
          debugPrint('Error fetching online artwork: $e');
        }
      }
    }
  }

  Future<void> _loadHistory() async {
    final history = await PlaybackHistoryService.loadHistory();
    historySongs.value = [...history];
  }

  Future<void> refreshHistory() async {
    await _loadHistory();
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
      print('SCAN_DEBUG: Music path: "$musicPath"');

      if (musicPath.isEmpty) {
        print('SCAN_DEBUG: Music path is empty. Aborting.');
        isScanning.value = false;
        return;
      }

      final musicDir = Directory(musicPath);
      if (!await musicDir.exists()) {
        print('SCAN_DEBUG: Music directory does not exist: $musicPath');
        isScanning.value = false;
        return;
      }

      // Check permissions on Android before proceeding
      if (Platform.isAndroid) {
        final storageStatus = await Permission.storage.status;
        final audioStatus = await Permission.audio.status;
        print(
          'SCAN_DEBUG: Permissions - Storage: $storageStatus, Audio: $audioStatus',
        );

        if (!storageStatus.isGranted && !audioStatus.isGranted) {
          print(
            'Scan aborted: Neither Storage nor Audio permission is granted.',
          );
          isScanning.value = false;
          return;
        }
      }

      // Ensure cache directories are initialized (Art directory must exist!)
      await SongCache.init();

      final cachedPaths = allSongs.value.map((s) => s.path).toSet();
      final artDir = await SongCache.artDir;

      print(
        'SCAN_DEBUG: Starting background scan. cachedCount=${cachedPaths.length}, artDir=$artDir',
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
          if (message.containsKey('total') && message['total'] > 0) {
            scanProgress.value = (message['count'] / message['total']).clamp(
              0.0,
              1.0,
            );
          }
          print('Scan progress: ${message['count']} / ${message['total']}');
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
    currentSong.value = null; // Update immediately for UI spacing
    isPlaying.value = false;
    position.value = Duration.zero;
    await _audioHandler.stop();
  }

  Future<void> playSong(Song song, {List<Song>? fromList}) async {
    if (_audioHandler is MyAudioHandler) {
      final handler = _audioHandler;

      if (fromList != null) {
        // Use the provided list as the new queue context
        await handler.setPlaylist(fromList);
      } else {
        final queue = handler.queue.value;
        final isInQueue = queue.any((item) => item.id == song.path);

        if (!isInQueue) {
          // Song not in current queue, fallback to library or single song
          final isInLibrary = allSongs.value.any((s) => s.path == song.path);
          if (isInLibrary) {
            await handler.setPlaylist(allSongs.value);
          } else {
            await handler.setPlaylist([song]);
          }
        }
      }

      await handler.playSong(song);
      _updateDynamicTheme(song);
    }
  }

  Future<void> playNext(Song song) async {
    if (_audioHandler is MyAudioHandler) {
      final handler = _audioHandler;

      final mediaItem = MediaItem(
        id: song.path,
        album: song.album ?? "Unknown Album",
        title: song.title,
        artist: song.artist,
        artUri: null,
        extras: {'path': song.path, 'hasAlbumArt': song.hasAlbumArt},
      );

      // Remove existing instances of this song first
      await handler.removeQueueItem(mediaItem);

      final currentIndex = handler.playbackState.value.queueIndex ?? 0;
      await handler.insertQueueItem(currentIndex + 1, mediaItem);
    }
  }

  Future<void> addToQueue(Song song) async {
    if (_audioHandler is MyAudioHandler) {
      final handler = _audioHandler;

      final mediaItem = MediaItem(
        id: song.path,
        album: song.album ?? "Unknown Album",
        title: song.title,
        artist: song.artist,
        artUri: null,
        extras: {'path': song.path, 'hasAlbumArt': song.hasAlbumArt},
      );

      await handler.addQueueItem(mediaItem);
    }
  }

  Future<void> _updateDynamicTheme(Song song) async {
    if (!song.hasAlbumArt) {
      dynamicThemeSeed.value = null;
      return;
    }

    try {
      ImageProvider? imageProvider;

      if (song.path.startsWith('yt:')) {
        // Use YouTube thumbnail for palette generation
        final videoId = song.path.substring(3);
        imageProvider = NetworkImage(
          'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
        );
      } else {
        // Use AlbumArtCache to get the file (handles extraction if needed)
        final file = await AlbumArtCache().getArt(song.path);
        if (file != null && await file.exists() && await file.length() > 0) {
          imageProvider = FileImage(file);
        }
      }

      if (imageProvider == null) {
        _resetTheme();
        return;
      }

      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 16,
      );

      final color = _selectBestSeedColor(palette);

      batch(() {
        dominantColor.value = palette.dominantColor?.color;
        mutedColor.value =
            palette.mutedColor?.color ?? palette.darkMutedColor?.color;
        dynamicThemeSeed.value = color;
      });
    } catch (e) {
      debugPrint('Error updating dynamic theme for ${song.title}: $e');
      _resetTheme();
    }
  }

  void _resetTheme() {
    batch(() {
      dynamicThemeSeed.value = null;
      dominantColor.value = null;
      mutedColor.value = null;
    });
  }

  Future<void> _loadLyricsForSong(Song song) async {
    // Reset state initially
    currentLyrics.value = null;

    final lyrics = await LyricsService().getLyrics(
      path: song.path,
      title: song.title,
      artist: song.artist,
      duration: song.duration,
    );

    // Ensure the song hasn't changed while we were fetching
    if (currentSong.value?.path == song.path) {
      currentLyrics.value = lyrics;
    }
  }

  /// Picks the most dominant color from a palette to use as a theme seed.
  Color? _selectBestSeedColor(PaletteGenerator palette) {
    final dominant = palette.dominantColor?.color;
    if (dominant == null) return null;
    return _boostSaturation(dominant);
  }

  Color _boostSaturation(Color color) {
    final hsl = HSLColor.fromColor(color);
    // If saturation is low but not gray, boost it for a more vibrant theme
    if (hsl.saturation > 0.1 && hsl.saturation < 0.4) {
      return hsl.withSaturation((hsl.saturation * 1.5).clamp(0.0, 1.0)).toColor();
    }
    return color;
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

  Future<void> toggleRepeat() async {
    final currentMode = repeatMode.value;
    AudioServiceRepeatMode newMode;

    switch (currentMode) {
      case AudioServiceRepeatMode.none:
        newMode = AudioServiceRepeatMode.all;
        break;
      case AudioServiceRepeatMode.all:
        newMode = AudioServiceRepeatMode.one;
        break;
      case AudioServiceRepeatMode.one:
        newMode = AudioServiceRepeatMode.none;
        break;
      default:
        newMode = AudioServiceRepeatMode.none;
    }

    await _audioHandler.setRepeatMode(newMode);
  }

  // Playlist Management
  Future<void> _loadPlaylists() async {
    final loaded = await PlaylistService.loadPlaylists();
    // Ensure "Favorites" persistent playlist exists
    if (!loaded.any((p) => p.id == 'favorites')) {
      loaded.insert(
        0,
        Playlist(
          id: 'favorites',
          name: 'Favorites',
          songPaths: [],
          createdAt: DateTime.now(),
        ),
      );
      await PlaylistService.savePlaylists(loaded);
    }
    playlists.value = loaded;
  }

  Future<Playlist> createPlaylist(String name) async {
    final playlist = Playlist(
      id: const Uuid().v4(),
      name: name,
      songPaths: [],
      createdAt: DateTime.now(),
    );
    playlists.add(playlist);
    await PlaylistService.savePlaylists(playlists.value);
    return playlist;
  }

  Future<void> deletePlaylist(String id) async {
    // 1. Clear current if active
    if (currentPlaylist.value?.id == id) {
      currentPlaylist.value = null;
    }

    // 2. Unpin from sidebar
    await settingsSignal.unpinPlaylist(id);

    // 3. Remove and save
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

  Future<void> toggleFavorite(String songPath) async {
    final index = playlists.value.indexWhere((p) => p.id == 'favorites');
    if (index != -1) {
      final playlist = playlists[index];
      final newPaths = List<String>.from(playlist.songPaths);
      if (newPaths.contains(songPath)) {
        newPaths.remove(songPath);
      } else {
        newPaths.add(songPath);
      }
      playlists[index] = playlist.copyWith(songPaths: newPaths);
      await PlaylistService.savePlaylists(playlists.value);
    }
  }

  bool isFavorite(String songPath) {
    final favorites = playlists.value.firstWhere(
      (p) => p.id == 'favorites',
      orElse: () => Playlist(
        id: 'favorites',
        name: 'Favorites',
        songPaths: [],
        createdAt: DateTime.now(),
      ),
    );
    return favorites.songPaths.contains(songPath);
  }

  void setCurrentPlaylist(Playlist? playlist) {
    currentPlaylist.value = playlist;
  }

  Future<void> setPlaylistCover(
    String playlistId,
    String imageSourcePath,
  ) async {
    try {
      final index = playlists.value.indexWhere((p) => p.id == playlistId);
      if (index == -1) return;

      final sourceFile = File(imageSourcePath);
      if (!await sourceFile.exists()) return;

      // Copy to app dir so we don't lose it if user deletes original
      final ext = imageSourcePath.split('.').last;
      final cacheDir = await SongCache.artDir; // using same dir for simplicity
      final destPath = '$cacheDir/playlist_${playlistId}_cover.$ext';

      await sourceFile.copy(destPath);

      final playlist = playlists[index];
      playlists[index] = playlist.copyWith(imagePath: destPath);
      await PlaylistService.savePlaylists(playlists.value);

      // Update currentPlaylist if it's the active one
      if (currentPlaylist.value?.id == playlistId) {
        currentPlaylist.value = playlists[index];
      }
    } catch (e) {
      print('Error setting playlist cover: $e');
    }
  }

  Future<void> playPlaylist(Playlist playlist, {bool shuffle = false}) async {
    final songs = playlist.songPaths
        .map(
          (path) => allSongs.value.firstWhere(
            (s) => s.path == path,
            orElse: () => Song.fromPath(path),
          ),
        )
        .toList();

    if (songs.isNotEmpty && _audioHandler is MyAudioHandler) {
      if (shuffle) {
        await _audioHandler.setShuffleMode(AudioServiceShuffleMode.all);
      } else {
        await _audioHandler.setShuffleMode(AudioServiceShuffleMode.none);
      }
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
      return '/storage/emulated/0';
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
        modifiedAt: await file.lastModified(),
      );
      _explorerSongCache[file.path] = song;
      return song;
    } catch (_) {
      return Song.fromPath(file.path);
    }
  }

  void setSleepTimer(Duration? duration) {
    _sleepInternalTimer?.cancel();
    _sleepInternalTimer = null;
    sleepTimerRemaining.value = duration;

    if (duration != null && duration.inSeconds > 0) {
      _sleepInternalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final current = sleepTimerRemaining.value;
        if (current == null || current.inSeconds <= 0) {
          timer.cancel();
          _sleepInternalTimer = null;
          sleepTimerRemaining.value = null;
          pause(); // Pause playback instead of stopping
        } else {
          sleepTimerRemaining.value = current - const Duration(seconds: 1);
        }
      });
    }
  }

  void dispose() {
    _discordTimer?.cancel();
    _sleepInternalTimer?.cancel();
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
    print('ISOLATE_DEBUG: Indexing initialized');

    final dir = Directory(musicPath);
    print('ISOLATE_DEBUG: Scanning directory: $musicPath');

    if (!dir.existsSync()) {
      print('ISOLATE_DEBUG: Directory does not exist. Done.');
      sendPort.send('done');
      return;
    }

    // 1. Discover files ASYNCHRONOUSLY to avoid blocking
    final List<String> filesToProcess = [];
    int foundCount = 0;

    print('ISOLATE_DEBUG: Starting discovery...');
    try {
      await for (final entity
          in dir.list(recursive: true, followLinks: false).handleError((e) {
            // print('ISOLATE_DEBUG: Skipping restricted folder/file: $e');
          })) {
        if (entity is File && _isSupportedAudio(entity.path)) {
          if (!cachedPaths.contains(entity.path)) {
            filesToProcess.add(entity.path);
            foundCount++;

            // Periodic progress update during discovery
            if (foundCount % 50 == 0) {
              print('ISOLATE_DEBUG: Discovered $foundCount files...');
              sendPort.send({'type': 'progress', 'count': foundCount});
            }
          }
        }
      }
    } catch (e) {
      print('ISOLATE_DEBUG: Fatal error during discovery: $e');
    }

    print(
      'ISOLATE_DEBUG: Discovery complete. Found $foundCount new files to process.',
    );

    if (filesToProcess.isEmpty) {
      print('ISOLATE_DEBUG: No new files to process. Done.');
      sendPort.send('done');
      return;
    }

    // 2. Process files sequentially to avoid memory spikes
    for (int i = 0; i < filesToProcess.length; i++) {
      final path = filesToProcess[i];
      try {
        // Send progress
        sendPort.send({
          'type': 'progress',
          'count': i + 1,
          'total': filesToProcess.length,
        });

        final metadata = readMetadata(File(path));

        bool hasArt = false;
        if (metadata.pictures.isNotEmpty) {
          try {
            final artPath = '$artDir/${path.hashCode.abs()}.jpg';
            final artFile = File(artPath);
            if (!await artFile.exists()) {
              await artFile.writeAsBytes(metadata.pictures.first.bytes);
            }
            hasArt = true;
          } catch (e) {
            // Silently fail artwork, but song is still indexed
          }
        }

        // Use bitrate from metadata if available, otherwise calculate from file size
        int? bitrate = metadata.bitrate != null ? (metadata.bitrate! / 1000).round() : null;
        if (bitrate == null && metadata.duration != null && metadata.duration!.inSeconds > 0) {
          final fileSizeBytes = await File(path).length();
          final durationSeconds = metadata.duration!.inSeconds;
          bitrate = ((fileSizeBytes * 8) / durationSeconds / 1000).round();
        }

        final parsed = MetadataService().parseFromFilename(path);
        final hasTitle = metadata.title != null && metadata.title!.trim().isNotEmpty;
        final hasArtist = metadata.artist != null && metadata.artist != 'Unknown Artist';

        final song = Song(
          path: path,
          title: hasTitle ? metadata.title! : parsed['title']!,
          artist: hasArtist ? metadata.artist! : parsed['artist']!,
          album: metadata.album,
          hasAlbumArt: hasArt,
          duration: metadata.duration,
          bitrate: bitrate,
          modifiedAt: File(path).lastModifiedSync(),
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
    final metadata = readMetadata(File(path));

    if (metadata.pictures.isNotEmpty && artDir != null) {
      try {
        final artPath = '$artDir/${path.hashCode.abs()}.jpg';
        await File(artPath).writeAsBytes(metadata.pictures.first.bytes);
      } catch (_) {}
    }

    return {
      'title': (metadata.title != null && metadata.title!.trim().isNotEmpty)
          ? metadata.title
          : null,
      'artist': metadata.artist,
      'album': metadata.album,
      'duration': metadata.duration,
    };
  } catch (_) {
    return {};
  }
}
