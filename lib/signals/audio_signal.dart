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

import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:signals/signals_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:palette_generator_master/palette_generator_master.dart';
import 'package:http/http.dart' as http;
import 'settings_signal.dart';
import 'search_signal.dart';
import '../services/scrobble_service.dart';
import '../theme/app_theme_style.dart';
import '../utils/platform_utils.dart';
import 'package:uuid/uuid.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';

import '../models/song.dart';
import '../models/playlist.dart';
import '../services/audio_handler.dart';
import '../services/song_cache.dart';
import '../services/platform_service.dart';
import '../services/album_art_service.dart';
import '../services/playlist_service.dart';
import '../services/palette_cache_service.dart';
import '../services/playback_history_service.dart';
import '../services/YoutubeDatasource.dart';
import '../models/history_entry.dart';
import '../services/metadata_service.dart';
import '../services/album_art_cache.dart';
import '../services/audio_cache_service.dart';
import '../services/lyrics_service.dart';
import '../signals/queue_signal.dart' as q;
import '../models/library_models.dart';
import '../services/artist_art_cache.dart';

class AudioSignal {
  static final AudioSignal _instance = AudioSignal._internal();
  factory AudioSignal() => _instance;
  AudioSignal._internal();

  late final AudioHandler _audioHandler;
  MyAudioHandler get audioHandler => _audioHandler as MyAudioHandler;
  final List<StreamSubscription> _subscriptions = [];
  final List<void Function()> _effectDisposals = [];

  // Signals
  final isPlaying = signal<bool>(false);
  final currentSong = signal<Song?>(null);
  final position = signal<Duration>(Duration.zero);
  final duration = signal<Duration>(Duration.zero);
  final isBuffering = signal<bool>(false);
  final allSongs = listSignal<Song>([]);
  final playlists = listSignal<Playlist>([]);
  final historySongs = listSignal<HistoryEntry>([]);
  final isHistoryGridView = signal<bool>(false);
  final isArtistsGridView = signal<bool>(false);
  final isAlbumsGridView = signal<bool>(true); // Default albums to grid
  final isSongsGridView = signal<bool>(false);
  final isArtistDetailGridView = signal<bool>(false);
  final isAlbumDetailGridView = signal<bool>(false);
  final isPlaylistsGridView = signal<bool>(true); // Default playlists to grid
  final isPlaylistDetailGridView = signal<bool>(false);
  final isYtLibraryGridView = signal<bool>(true); // Default YT library to grid
  final currentPlaylist = signal<Playlist?>(null);
  final isRadioMode = signal<bool>(false);
  final isScanning = signal<bool>(false);
  final scanProgress = signal<double>(0.0);
  final repeatMode = signal<AudioServiceRepeatMode>(
    AudioServiceRepeatMode.none,
  );
  final playerExpansion = signal<double>(0.0);
  final headerShowBlur = signal<bool>(false);
  final headerTitleProgress = signal<double>(0.0);
  final headerArtCover = signal<String?>(null);
  final headerArtCoverIsNetwork = signal<bool>(false);
  final headerPageTitle = signal<String?>(null);
  late final showPlayer = computed(
    () => currentSong.value != null || isDesktop,
  );
  final dynamicThemeSeed = signal<Color?>(null);
  final dominantColor = signal<Color?>(null);
  final mutedColor = signal<Color?>(null);
  final sleepTimerRemaining = signal<Duration?>(null);
  Timer? _sleepInternalTimer;
  final Map<String, bool> _hasMusicCache = {};
  final bottomPadding = signal<double>(0.0);
  final minimizePlayerTrigger = signal<int>(0);
  final albumArtDir = signal<String?>(null);
  final currentLyrics = signal<String?>(null);
  final showLyrics = signal<bool>(false);
  final showQueueInPlayer = signal<bool>(false);
  final artistPictures = mapSignal<String, String?>(
    {},
  ); // artistName -> localPath
  final artistArtCache = ArtistArtCache();

  List<LyricLine> _lyricsLines = const [];
  bool _lyricsSynced = false;

  late final lyricsActiveIndex = computed<int>(() {
    final lines = _lyricsLines;
    if (!_lyricsSynced || lines.isEmpty) return -1;
    final pos = position.value;
    int low = 0;
    int high = lines.length - 1;
    int idx = -1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (lines[mid].time.compareTo(pos) <= 0) {
        idx = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return idx;
  });

  bool _hasScrobbledCurrentSong = false;
  int _currentSongStartTime = 0;
  bool _hasUpdatedNowPlaying = false;

  late final songMap = computed(() {
    return {for (var s in allSongs.value) s.path: s};
  });

  /// Resolve a song path to a Song object.
  /// Checks: local library (songMap) → YouTube radio cache → YouTube browse/search results (yt: paths) → Song.fromPath fallback.
  Song resolveSong(String path) {
    return songMap.value[path] ??
        (path.startsWith('yt:')
            ? [
                ...ytRadioSongs.value,
                ...searchSignal.ytBrowseResults.value,
                ...searchSignal.youtubeSearchResults.value,
              ].firstWhere(
                (s) => s.path == path,
                orElse: () {
                  // Try restoring from the persisted YouTube cache so queue
                  // entries survive app restarts.
                  final json = q.queueSignal.service.getYtSongJson(path);
                  if (json != null) {
                    try {
                      return _songFromJson(
                        path,
                        jsonDecode(json) as Map<String, dynamic>,
                      );
                    } catch (_) {}
                  }
                  return Song.fromPath(path);
                },
              )
            : Song.fromPath(path));
  }

  late final storageStats = computed(() {
    int totalSize = 0;
    for (final song in allSongs.value) {
      totalSize += song.size ?? 0;
    }
    return {'count': allSongs.value.length, 'size': totalSize};
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

  /// Cache of all songs fetched from YouTube radio/playlists — indexed by path.
  /// Used by [resolveSong] so queue items show proper title/artist/artwork.
  final ytRadioSongs = listSignal<Song>([]);

  /// Prefetch buffer for radio: the next batch of songs fetched ahead of the queue.
  /// When the queue runs low, the prefetch batch is drained first before hitting the API.
  final radioPrefetchBatch = listSignal<Song>([]);

  // Computed for backward compatibility or simple checks

  late final recentlyAdded = computed(() {
    final start = DateTime.now();
    final songs = allSongs.value;
    if (songs.isEmpty) return <Song>[];

    final sorted = List<Song>.from(songs);
    sorted.sort((a, b) {
      final aDate = a.modifiedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.modifiedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    final result = sorted.take(50).toList();

    final elapsed = DateTime.now().difference(start).inMilliseconds;
    if (elapsed > 50) {
      debugPrint(
        'PERF: recentlyAdded recomputed in ${elapsed}ms for ${songs.length} songs',
      );
    }
    return result;
  });

  late final recentlyPlayed = computed(() {
    final map = songMap.value;
    return historySongs.value
        .take(10)
        .map((h) => map[h.songPath])
        .whereType<Song>()
        .toList();
  });

  late final artists = computed(() {
    final start = DateTime.now();
    final map = <String, List<Song>>{};
    final songs = allSongs.value;

    for (final song in songs) {
      if (song.path.startsWith('yt:')) continue;

      final parts = song.artist.split(RegExp(r'[,&]'));
      for (final part in parts) {
        final name = part.trim();
        if (name.isNotEmpty && name.toLowerCase() != 'unknown artist') {
          map.putIfAbsent(name, () => []).add(song);
        }
      }
    }

    final pics = artistPictures.value;
    final result =
        map.entries.map((e) {
          final name = e.key;
          return Artist(name: name, songs: e.value, picturePath: pics[name]);
        }).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    final elapsed = DateTime.now().difference(start).inMilliseconds;
    if (elapsed > 50) {
      debugPrint(
        'PERF: artists recomputed in ${elapsed}ms for ${songs.length} songs',
      );
    }
    return result;
  });

  late final albums = computed(() {
    final start = DateTime.now();
    final map = <String, List<Song>>{};
    final songs = allSongs.value;

    for (final song in songs) {
      if (song.path.startsWith('yt:')) continue;
      final key = "${song.artist}__${song.album ?? 'Unknown Album'}";
      map.putIfAbsent(key, () => []).add(song);
    }

    final result =
        map.entries.map((e) {
          final songs = e.value;
          return Album(
            name: songs.first.album ?? 'Unknown Album',
            artist: songs.first.artist,
            songs: songs,
          );
        }).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    final elapsed = DateTime.now().difference(start).inMilliseconds;
    if (elapsed > 50) {
      debugPrint(
        'PERF: albums recomputed in ${elapsed}ms for ${songs.length} songs',
      );
    }
    return result;
  });

  Future<void> init(AudioHandler handler) async {
    // Cleanup any existing state if called again
    dispose();

    _audioHandler = handler;

    if (isDesktop) {
      unawaited(_updateDiscordPresence(force: true));
    }
    // Initialize album art directory
    unawaited(
      SongCache.artDir.then((path) {
        albumArtDir.value = path;
      }),
    );

    // Initialize queue service
    await q.queueSignal.init();
    _loadCachedYtSongs();
    // Remove YouTube queue entries that cannot be resolved (e.g., from a
    // previous session whose radio cache is gone).
    _clearOrphanedYtEntries();

    // Refresh Discord presence when buttons/toggle change
    settingsSignal.onDiscordRpcChanged = () {
      if (isDesktop) unawaited(_updateDiscordPresence(force: true));
    };

    // Listen to streams
    _subscriptions.add(
      _audioHandler.playbackState.listen((state) {
        isPlaying.value = state.playing;
        repeatMode.value = state.repeatMode;
        isBuffering.value =
            state.processingState == AudioProcessingState.buffering;
      }),
    );
    _subscriptions.add(
      _audioHandler.mediaItem.listen((item) {
        if (item != null) {
          duration.value = item.duration ?? Duration.zero;
          try {
            // Resolve the canonical Song via the same lookup the queue UI
            // uses so the player's artwork matches the queue item's
            // artwork. Without this, songs that aren't currently in
            // `youtubeSearchResults` (e.g. after navigating away from the
            // search screen) get reconstructed as a Song with no
            // `thumbnailUrl`, which makes the expanded player fall back
            // to a generic YouTube CDN thumbnail while the queue item
            // keeps the YT Music square art from the cached Song.
            var song = resolveSong(item.id);

            // If the resolved Song is the empty fallback (no cached
            // metadata), overlay the MediaItem's title/artist/album so
            // the player UI doesn't show "yt:<id>" as the title.
            final looksLikeFallback = song.title == song.path ||
                song.artist == 'Unknown Artist';
            if (looksLikeFallback) {
              song = song.copyWith(
                title: item.title.isNotEmpty ? item.title : song.title,
                artist: (item.artist != null && item.artist!.isNotEmpty)
                    ? item.artist
                    : song.artist,
                album: item.album,
              );
            }

            if (song.path.isNotEmpty) {
              final isSameSong = currentSong.value?.path == song.path;
              currentSong.value = song;

              if (!isSameSong) {
                _hasScrobbledCurrentSong = false;
                _hasUpdatedNowPlaying = false;
                _currentSongStartTime =
                    DateTime.now().millisecondsSinceEpoch ~/ 1000;
                _updateDynamicTheme(song);
                _loadLyricsForSong(song);
                if (isDesktop) unawaited(_updateDiscordPresence(force: true));

                // Lazy metadata fix for untagged local songs
                if (!song.path.startsWith('yt:') &&
                    (song.artist == 'Unknown Artist' || song.album == null)) {
                  unawaited(_refreshMetadata(song));
                }
              } else {
                // If it's the same song but duration was just resolved and we still have no lyrics, try again
                if ((currentLyrics.value == null ||
                        currentLyrics.value == '') &&
                    song.duration != null &&
                    song.duration!.inSeconds > 0) {
                  _loadLyricsForSong(song);
                }
              }
            }
          } catch (_) {}
        }
      }),
    );

    if (_audioHandler is MyAudioHandler) {
      final myHandler = _audioHandler;
      _subscriptions.add(
        myHandler.player.positionStream.listen((pos) {
          position.value = pos;

          final sessionKey = settingsSignal.lastFmSessionKey.value;
          if (sessionKey != null && sessionKey.isNotEmpty) {
            final song = currentSong.value;
            if (song != null && !_hasScrobbledCurrentSong && isPlaying.value) {
              final dur = duration.value.inSeconds;
              final played = pos.inSeconds;
              if (played > 0 && dur > 0) {
                if (!_hasUpdatedNowPlaying) {
                  _hasUpdatedNowPlaying = true;
                  scrobbleService.updateNowPlaying(
                    sessionKey,
                    song.title,
                    song.artist,
                    album: song.album,
                  );
                }
                if (played >= dur / 2 || played >= 240) {
                  _hasScrobbledCurrentSong = true;
                  scrobbleService.scrobble(
                    sessionKey,
                    song.title,
                    song.artist,
                    _currentSongStartTime,
                    album: song.album,
                  );
                }
              }
            }
          }
        }),
      );
    }

    // Recompute parsed lyric lines only when the lyrics text changes —
    // the per-tick `lyricsActiveIndex` computed reuses the cached list.
    _effectDisposals.add(
      effect(() {
        final lyrics = currentLyrics.value;
        if (lyrics == null || lyrics.isEmpty) {
          _lyricsLines = const [];
          _lyricsSynced = false;
        } else {
          _lyricsLines = parseLyrics(lyrics);
          _lyricsSynced = _lyricsLines.any((l) => l.time != Duration.zero);
        }
      }),
    );

    // Push settings → audio handler whenever the user changes speed/pitch.
    _effectDisposals.add(
      effect(() {
        final s = settingsSignal.playbackSpeed.value;
        audioHandler.setPlaybackSpeed(s);
      }),
    );
    _effectDisposals.add(
      effect(() {
        final p = settingsSignal.playbackPitch.value;
        audioHandler.setPlaybackPitch(p);
      }),
    );

    // 1. Initial Load (Delayed to allow UI and Debugger to settle)
    Future.delayed(const Duration(seconds: 1), () async {
      final start = DateTime.now();

      // Batch initialization tasks
      await Future.wait([
        _loadCacheAndScanOnly(),
        _loadPlaylists(),
        _loadHistory(),
      ]);

      final elapsed = DateTime.now().difference(start).inMilliseconds;
      debugPrint('PERF: Initial state loaded in ${elapsed}ms');

      // 2. Trigger background scan after 2 more seconds
      Future.delayed(const Duration(seconds: 2), () {
        unawaited(scanMusicDirectory());
      });

      // 3. Trigger artist art fetching (deferred even further)
      unawaited(_fetchArtistPictures());
    });
  }

  Future<void> _fetchArtistPictures() async {
    // Wait for allSongs to be populated and for UI to settle fully
    // Increased delay to avoid competing with launch frames
    await Future.delayed(const Duration(seconds: 5));

    if (allSongs.value.isEmpty) return;

    final uniqueArtists = artists.peek().map((a) => a.name).toSet();
    final Map<String, String> results = {};

    // 1. Check local cache in parallel (fast)
    final cacheChecks = uniqueArtists.map((name) async {
      final path = await artistArtCache.getArtPath(name);
      if (path != null) results[name] = path;
    });
    await Future.wait(cacheChecks);

    // Update with what we found locally first
    batch(() {
      for (final entry in results.entries) {
        artistPictures[entry.key] = entry.value;
      }
    });

    // 2. Fetch missing from Deezer sequentially (to be nice to API)
    for (final name in uniqueArtists) {
      if (results.containsKey(name)) continue;

      final newPath = await artistArtCache.fetchAndCache(name);
      if (newPath != null) {
        artistPictures[name] = newPath;
      }
      // Small delay between network requests
      await Future.delayed(const Duration(milliseconds: 500));
    }
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
        if (currentSong.value?.path == song.path) {
          currentSong.value = updatedSong;
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
    // History is now owned by QueueSignal and persisted to queue.json.
    // The legacy `historySongs` analytics list still powers play counts
    // and "Recently Played" until callers migrate.
    final history = await PlaybackHistoryService.loadHistory();
    historySongs.value = [...history];
  }

  Future<void> refreshHistory() async {
    await _loadHistory();
  }

  // Discord RPC
  String? _lastDiscordSongPath;
  bool? _lastDiscordIsPlaying;
  String? _cachedArtworkUrl;

  Future<void> _updateDiscordPresence({bool force = false}) async {
    if (!isDesktop) return;

    final song = currentSong.value;
    final playing = isPlaying.value;

    if (song == null) return;

    if (!settingsSignal.enableDiscordRpc.value) {
      if (_lastDiscordSongPath != null) {
        await PlatformService().clearPresence();
        _lastDiscordSongPath = null;
        _lastDiscordIsPlaying = null;
      }
      return;
    }

    int? start;
    int? end;
    if (playing) {
      final posMs = audioHandler.playbackState.value.position.inMilliseconds;
      start = DateTime.now().millisecondsSinceEpoch - posMs;

      final currentMediaItem = audioHandler.mediaItem.value;
      final durationMs =
          currentMediaItem?.duration?.inMilliseconds ??
          song.duration?.inMilliseconds;
      end = durationMs != null ? start + durationMs : null;
    }

    if (!force &&
        _lastDiscordSongPath == song.path &&
        _lastDiscordIsPlaying == playing) {
      return;
    }

    _lastDiscordSongPath = song.path;
    _lastDiscordIsPlaying = playing;

    if (song.path.startsWith('yt:')) {
      final videoId = song.path.substring(3);
      _cachedArtworkUrl = YoutubeDatasource().getArtworkUrl(videoId);
    } else {
      _cachedArtworkUrl = await AlbumArtService().getAlbumArtUrl(
        song.artist,
        song.album ?? '',
        song.title,
      );
    }

    await PlatformService().updatePresence(
      song,
      artworkUrl: _cachedArtworkUrl,
      isPlaying: playing,
      startTimeStamp: start,
      endTimeStamp: end,
    );
  }

  Future<void> _loadCacheAndScanOnly() async {
    final cachedSongs = await SongCache.loadCache();
    if (cachedSongs.isNotEmpty) {
      allSongs.value = cachedSongs;
      debugPrint('PERF: allSongs initialized with ${cachedSongs.length} songs');
    }
  }

  Future<void> scanMusicDirectory() async {
    if (isScanning.value) return;
    isScanning.value = true;
    _hasMusicCache.clear();

    final receivePort = ReceivePort();
    final exitPort = ReceivePort();
    Isolate? isolate;
    StreamSubscription? exitSub;

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
      final excludedPaths = settingsSignal.excludedPaths.value
          .map((e) => e.substring(2)) // strip 'f:' or 'd:' prefix
          .toSet();

      print(
        'SCAN_DEBUG: Starting background scan. cachedCount=${cachedPaths.length}, artDir=$artDir, excludedCount=${excludedPaths.length}',
      );

      isolate = await Isolate.spawn(_indexingIsolateEntry, {
        'sendPort': receivePort.sendPort,
        'musicPath': musicPath,
        'cachedPaths': cachedPaths,
        'excludedPaths': excludedPaths,
        'artDir': artDir,
      });

      // Robust monitoring: if isolate exits unexpectedly, we still clear isScanning
      isolate.addOnExitListener(exitPort.sendPort);

      final List<Song> batch = [];
      final stopwatch = Stopwatch()..start();

      bool isolateDone = false;

      // Listen for exit in the background
      exitSub = exitPort.listen((_) {
        if (!isolateDone) {
          print('Isolate exited unexpectedly');
          isScanning.value = false;
          receivePort.close();
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
      exitSub?.cancel();
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

  Future<void> clearMissingFiles() async {
    if (isScanning.value) return;

    final currentSongs = List<Song>.from(allSongs.value);
    final List<Song> existingSongs = [];
    bool changed = false;

    for (final song in currentSongs) {
      if (song.path.startsWith('yt:') || File(song.path).existsSync()) {
        existingSongs.add(song);
      } else {
        changed = true;
        debugPrint('AudioSignal: Removing missing file: ${song.path}');
      }
    }

    if (changed) {
      allSongs.value = existingSongs;
      await SongCache.saveCache(allSongs.value);
    }
  }

  // Removed _scanDirectory in favor of _performFullScan in isolate

  // Playback Control
  Future<void> play() async {
    await _audioHandler.play();
    if (isDesktop) unawaited(_updateDiscordPresence(force: true));
  }

  Future<void> pause() async {
    await _audioHandler.pause();
    if (isDesktop) unawaited(_updateDiscordPresence(force: true));
  }

  Future<void> seek(Duration pos) async {
    await _audioHandler.seek(pos);
    if (isDesktop) unawaited(_updateDiscordPresence(force: true));
  }

  Future<void> skipNext() => _audioHandler.skipToNext();
  Future<void> skipPrevious() => _audioHandler.skipToPrevious();
  Future<void> stop() async {
    currentSong.value = null;
    isPlaying.value = false;
    position.value = Duration.zero;
    await _audioHandler.stop();
    if (isDesktop) unawaited(_updateDiscordPresence(force: true));
  }

  Future<void> disposePlayer() async {
    if (_audioHandler is MyAudioHandler) {
      await _audioHandler.player.dispose();
    }
  }

  Future<void> playSong(Song song, {List<Song>? fromList}) async {
    if (_audioHandler is! MyAudioHandler) return;
    final handler = _audioHandler;

    if (fromList != null) {
      cacheRadioSongs(fromList);
    }

    // Auto-stop radio when a non-YouTube song starts playing.
    if (!song.path.startsWith('yt:') && isRadioMode.value) {
      stopRadio();
    }

    // Auto-start radio when a YouTube song is played (if not already in radio mode)
    if (song.path.startsWith('yt:') && !isRadioMode.value) {
      await startRadio(song);
    }

    // Decide the queue contents: explicit fromList > current queue
    // containing the song > full library > single song.
    List<String> paths;
    bool fromListSupplied = fromList != null;
    if (fromList != null) {
      paths = fromList.map((s) => s.path).toList();
    } else if (handler.queue.value.any((item) => item.id == song.path)) {
      paths = handler.queue.value.map((item) => item.id).toList();
    } else if (allSongs.value.any((s) => s.path == song.path)) {
      paths = allSongs.value.map((s) => s.path).toList();
    } else {
      paths = [song.path];
    }

    // Materialize a Song list in the right order so the handler can build
    // MediaItems. resolveSong() handles library lookups, YT caches, and
    // the Song.fromPath fallback.
    final songs = paths.map(resolveSong).toList();

    if (fromListSupplied) {
      // An explicit list was supplied. If shuffle is on, shuffle that list
      // and put the tapped song at shuffle-position 0; otherwise play
      // the list sequentially from the tapped song.
      if (q.queueSignal.isShuffleEnabled.value) {
        q.queueSignal.shuffleFrom(paths, playPath: song.path);
        final shuffledSongs = paths.map(resolveSong).toList()..shuffle();
        // Re-order so the tapped song is first.
        shuffledSongs.remove(song);
        shuffledSongs.insert(0, song);
        await handler.setPlaylist(shuffledSongs);
        await handler.playSong(song);
      } else {
        q.queueSignal.setPlaylist(paths, playPath: song.path);
        await handler.setPlaylist(songs);
        await handler.playSong(song);
      }
    } else {
      // No explicit list — reuse the existing queue but jump to the song.
      q.queueSignal.setPlaylist(paths, playPath: song.path);
      await handler.setPlaylist(songs);
      await handler.playSong(song);
    }
    _updateDynamicTheme(song);
    if (isDesktop) unawaited(_updateDiscordPresence(force: true));
  }

  /// Play [songs] as a freshly shuffled queue. The first song is the one
  /// at index 0 after shuffling; pass [start] to bias the start of the
  /// shuffle (the song at [start] is placed at shuffle-position 0).
  Future<void> playShuffledFromList(List<Song> songs, {Song? start}) async {
    if (_audioHandler is! MyAudioHandler || songs.isEmpty) return;
    final handler = _audioHandler;

    cacheRadioSongs(songs);

    final paths = songs.map((s) => s.path).toList();
    final playPath = start?.path ?? paths.first;

    // Stop any active radio when playing local / non-yt sources via this
    // entry point.
    if (!playPath.startsWith('yt:') && isRadioMode.value) {
      stopRadio();
    }
    if (playPath.startsWith('yt:') && !isRadioMode.value) {
      await startRadio(resolveSong(playPath));
    }

    q.queueSignal.shuffleFrom(paths, playPath: playPath);
    // Build the actual play order for the handler.
    final shuffled = List<String>.from(paths)..shuffle();
    shuffled.remove(playPath);
    shuffled.insert(0, playPath);
    final resolvedSongs = shuffled.map(resolveSong).toList();
    await handler.setPlaylist(resolvedSongs);
    await handler.playSong(resolveSong(playPath));
    _updateDynamicTheme(resolveSong(playPath));
    if (isDesktop) unawaited(_updateDiscordPresence(force: true));
  }

  // ─── Playback control ────────────────────────────────────────────────────

  Future<void> playNext(Song song) async {
    if (_audioHandler is! MyAudioHandler) return;
    final handler = _audioHandler;

    q.queueSignal.playNext(song);

    // Keep the handler's MediaItem list in sync so actual playback sees
    // the inserted track.
    final artCache = AlbumArtCache();
    Uri? initialArtUri;
    final cachedPath = artCache.getArtPathSync(song.path);
    if (cachedPath != null) {
      initialArtUri = Uri.file(cachedPath);
    } else if (song.path.startsWith('yt:')) {
      final videoId = song.path.substring(3);
      initialArtUri = Uri.parse(youtubeDatasource.getArtworkUrl(videoId));
    }

    final mediaItem = MediaItem(
      id: song.path,
      album: song.album ?? "Unknown Album",
      title: song.title,
      artist: song.artist,
      duration: song.duration,
      artUri: initialArtUri,
      extras: {'path': song.path, 'hasAlbumArt': song.hasAlbumArt},
    );

    await handler.removeQueueItem(mediaItem);
    final currentIndex = handler.playbackState.value.queueIndex ?? 0;
    await handler.insertQueueItem(currentIndex + 1, mediaItem);
  }

  Future<void> addToQueue(Song song) async {
    if (_audioHandler is! MyAudioHandler) return;
    final handler = _audioHandler;

    q.queueSignal.addToQueue(song);

    Uri? initialArtUri;
    final cachedPath = albumArtCache.getArtPathSync(song.path);
    if (cachedPath != null) {
      initialArtUri = Uri.file(cachedPath);
    } else if (song.path.startsWith('yt:')) {
      final videoId = song.path.substring(3);
      initialArtUri = Uri.parse(youtubeDatasource.getArtworkUrl(videoId));
    }

    final mediaItem = MediaItem(
      id: song.path,
      album: song.album ?? "Unknown Album",
      title: song.title,
      artist: song.artist,
      duration: song.duration,
      artUri: initialArtUri,
      extras: {'path': song.path, 'hasAlbumArt': song.hasAlbumArt},
    );

    await handler.addQueueItem(mediaItem);
  }

  Future<void> removeFromUpNext(int activeIndex) async {
    // activeIndex is a position in the active play sequence (shuffled or
    // unshuffled). Translate it to the underlying playbackOrder index for
    // QueueSignal (which owns the canonical order) and pass the active
    // index to the handler (whose queue is in active order).
    final playbackIdx = q.queueSignal.playbackOrderIndexForActive(activeIndex);
    q.queueSignal.removeAt(playbackIdx);
    if (_audioHandler is MyAudioHandler && activeIndex >= 0) {
      _audioHandler.removeQueueItemAt(activeIndex);
    }
  }

  Future<void> reorderUpNext(int oldActiveIndex, int newActiveIndex) async {
    final oldPlaybackIdx = q.queueSignal.playbackOrderIndexForActive(
      oldActiveIndex,
    );
    final newPlaybackIdx = q.queueSignal.playbackOrderIndexForActive(
      newActiveIndex,
    );
    q.queueSignal.reorderByQueueIndex(oldPlaybackIdx, newPlaybackIdx);
    if (_audioHandler is MyAudioHandler &&
        oldActiveIndex >= 0 &&
        newActiveIndex >= 0) {
      _audioHandler.moveQueueItem(oldActiveIndex, newActiveIndex);
    }
  }

  /// Start radio mode for the given song, fetching a batch of similar songs
  /// from YouTube Music's radio endpoint and seeding the prefetch buffer.
  Future<void> startRadio(Song seedSong) async {
    if (!seedSong.path.startsWith('yt:')) return;
    final videoId = seedSong.path.substring(3);

    isRadioMode.value = true;
    q.queueSignal.updateRadioSeed(videoId);

    // Fetch initial batch from YTM API and seed the prefetch buffer.
    final songs = await youtubeDatasource.getRadioSongs(videoId);
    if (songs.isEmpty) return;

    radioPrefetchBatch.addAll(songs);
    ytRadioSongs.addAll(songs);
    audioCacheService.prefetchRadioSongs(songs, limit: 5);

    // Add the batch to the queue in one operation.
    await _addRadioBatch(songs);
  }

  /// Add a list of songs to the playback queue as a batch.
  Future<void> _addRadioBatch(List<Song> songs) async {
    if (_audioHandler is! MyAudioHandler) return;
    final handler = _audioHandler;

    final items = songs.map((song) {
      Uri? artUri;
      final cachedPath = albumArtCache.getArtPathSync(song.path);
      if (cachedPath != null) {
        artUri = Uri.file(cachedPath);
      } else if (song.path.startsWith('yt:')) {
        artUri = Uri.parse(
          youtubeDatasource.getArtworkUrl(song.path.substring(3)),
        );
      }
      return MediaItem(
        id: song.path,
        album: song.album ?? 'YouTube Music',
        title: song.title,
        artist: song.artist,
        duration: song.duration,
        artUri: artUri,
        extras: {'path': song.path, 'hasAlbumArt': song.hasAlbumArt},
      );
    }).toList();

    await handler.addRadioBatch(items);
  }

  /// Advance the radio seed to a new videoId and prefetch the next batch.
  /// Called when a radio song finishes playing so the continuation chain stays fresh.
  void advanceRadioSeed(String videoId) {
    if (!isRadioMode.value) return;
    q.queueSignal.updateRadioSeed(videoId);
    // Kick off a background prefetch of the next batch from the new seed.
    unawaited(_prefetchRadioBatch(videoId));
  }

  Future<void> _prefetchRadioBatch(String videoId) async {
    final songs = await youtubeDatasource.getRadioSongs(videoId);
    if (songs.isEmpty) return;
    radioPrefetchBatch.addAll(songs);
    ytRadioSongs.addAll(songs);
    audioCacheService.prefetchRadioSongs(songs, limit: 5);
  }

  /// Stop radio mode — no more auto-filling will occur.
  void stopRadio() {
    isRadioMode.value = false;
    q.queueSignal.clearRadioSeed();
  }

  /// Cache songs from radio/fill operations so [resolveSong] can find them for queue display.
  /// Load cached YouTube songs from disk into ytRadioSongs so queue entries
  /// resolve on restart without re-fetching.
  void _loadCachedYtSongs() {
    final cached = q.queueSignal.service.getAllCachedYtSongs();
    for (final json in cached) {
      try {
        final song = _songFromJson(
          null,
          jsonDecode(json) as Map<String, dynamic>,
        );
        if (!ytRadioSongs.value.any((s) => s.path == song.path)) {
          ytRadioSongs.add(song);
        }
      } catch (_) {}
    }
  }

  /// Remove YouTube queue entries that cannot be resolved and are not in any
  /// cached source. This prevents stale YouTube entries from blocking playback.
  void _clearOrphanedYtEntries() {
    bool isResolvable(String path) {
      if (!path.startsWith('yt:')) return true;
      if (songMap.value.containsKey(path)) return true;
      if (ytRadioSongs.value.any((s) => s.path == path)) return true;
      if (searchSignal.youtubeSearchResults.value.any((s) => s.path == path)) {
        return true;
      }
      if (q.queueSignal.service.getYtSongJson(path) != null) return true;
      return false;
    }

    final order = List<String>.from(q.queueSignal.playbackOrder.value);
    final orphans = order
        .where((p) => p.startsWith('yt:') && !isResolvable(p))
        .toList();
    if (orphans.isEmpty) return;

    final cleaned = order.where((p) => !orphans.contains(p)).toList();
    final cleanedHist = q.queueSignal.history.value
        .where((p) => !p.startsWith('yt:') || isResolvable(p))
        .toList();

    // Update signal state directly then persist.
    q.queueSignal.playbackOrder.value = cleaned;
    q.queueSignal.history.value = cleanedHist;
    q.queueSignal.service.replace(
      q.queueSignal.service.model.copyWith(
        playbackOrder: cleaned,
        history: cleanedHist,
      ),
    );
  }

  /// Reconstruct a Song from persisted JSON. [path] may be null if the JSON
  /// already contains a path field.
  Song _songFromJson(String? path, Map<String, dynamic> json) {
    return Song(
      path: path ?? json['path'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown',
      artist: json['artist'] as String? ?? 'Unknown',
      album: json['album'] as String?,
      hasAlbumArt: json['hasAlbumArt'] as bool? ?? true,
      lyrics: null,
      duration: json['durationMs'] != null
          ? Duration(milliseconds: json['durationMs'] as int)
          : null,
      bitrate: json['bitrate'] as int?,
      size: json['size'] as int?,
      modifiedAt: null,
      gainDb: 0.0,
      trackPeak: 1.0,
      albumGainDb: 0.0,
      albumPeak: 1.0,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }

  void cacheRadioSongs(List<Song> songs) {
    for (final song in songs) {
      if (!ytRadioSongs.value.any((s) => s.path == song.path)) {
        ytRadioSongs.add(song);
        // Persist so YouTube queue entries survive restarts.
        q.queueSignal.service.cacheYtSong(
          song.path,
          jsonEncode(_songToJson(song)),
        );
      }
    }
  }

  Map<String, dynamic> _songToJson(Song song) {
    return {
      'path': song.path,
      'title': song.title,
      'artist': song.artist,
      'album': song.album,
      'durationMs': song.duration?.inMilliseconds,
      'thumbnailUrl': song.thumbnailUrl,
      'hasAlbumArt': song.hasAlbumArt,
      'bitrate': song.bitrate,
      'size': song.size,
    };
  }

  Future<void> _updateDynamicTheme(Song song) async {
    if (settingsSignal.themeStyle.value == AppThemeStyle.signature) return;

    if (!song.hasAlbumArt) {
      dynamicThemeSeed.value = null;
      return;
    }

    try {
      final cachedPalette = await PaletteCacheService.getPalette(song.path);
      if (cachedPalette != null) {
        batch(() {
          dominantColor.value = cachedPalette['dominant'];
          mutedColor.value = cachedPalette['muted'];
          dynamicThemeSeed.value = cachedPalette['seed'];
        });
        return;
      }

      ImageProvider? imageProvider;

      if (song.path.startsWith('yt:')) {
        // Use YouTube Music thumbnail for palette generation (square, hi-res)
        final videoId = song.path.substring(3);
        imageProvider = NetworkImage(youtubeDatasource.getArtworkUrl(videoId));
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

      // Optimize: Resize the image to a smaller size for palette generation
      // 250x250 is enough for accurate hue extraction and still fast
      final resizedProvider = ResizeImage(
        imageProvider,
        width: 250,
        height: 250,
        policy: ResizeImagePolicy.fit,
      );

      final palette = await PaletteGeneratorMaster.fromImageProvider(
        resizedProvider,
        maximumColorCount: 16,
      );

      final color = _selectBestSeedColor(palette);

      await PaletteCacheService.savePalette(
        song.path,
        palette.dominantColor?.color,
        palette.mutedColor?.color ?? palette.darkMutedColor?.color,
        color,
      );

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
      currentLyrics.value = lyrics ?? '';
    }
  }

  /// Picks the best accent color from a palette using population-weighted scoring.
  /// Filters out near-white, near-black, and low-saturation hues that are
  /// likely background noise, then scores by: population * saturation * luminance_factor.
  Color? _selectBestSeedColor(PaletteGeneratorMaster palette) {
    Color? bestColor;
    double bestScore = 0;

    for (final paletteColor in palette.paletteColors) {
      final color = paletteColor.color;
      final population = paletteColor.population;

      final hsl = HSLColor.fromColor(color);
      final luminance = hsl.lightness;
      final saturation = hsl.saturation;

      // Reject implausible accents: near-white, near-black, or very desaturated
      if (saturation < 0.08) continue;
      if (luminance < 0.10 || luminance > 0.85) continue;

      // Clamp luminance factor so both very dark and very light colors score lower
      final luminanceFactor = (luminance.clamp(0.15, 0.85) - 0.15) / 0.70;
      final score = population * saturation * luminanceFactor;

      if (score > bestScore) {
        bestScore = score;
        bestColor = color;
      }
    }

    if (bestColor != null) return _boostSaturation(bestColor);

    // Fallback chain: vibrant -> muted -> darkMuted
    final fallback =
        palette.vibrantColor?.color ??
        palette.mutedColor?.color ??
        palette.darkMutedColor?.color;
    if (fallback != null) return _boostSaturation(fallback);

    return null;
  }

  Color _boostSaturation(Color color) {
    final hsl = HSLColor.fromColor(color);
    // If saturation is low but not gray, boost it for a more vibrant theme
    if (hsl.saturation > 0.1 && hsl.saturation < 0.4) {
      return hsl
          .withSaturation((hsl.saturation * 1.5).clamp(0.0, 1.0))
          .toColor();
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
    if (_audioHandler is! MyAudioHandler) return;
    final handler = _audioHandler;

    // Flip the signal state. QueueSignal handles the stable re-shuffle.
    q.queueSignal.toggleShuffle();

    // After the toggle, the handler's queue must reflect the new active
    // order (so the OS lock-screen and notification surfaces show the
    // correct next/previous). Reorder in place so playback is not
    // interrupted — the currently playing song stays playing from its
    // current position.
    final activePaths = <String>[];
    final n = q.queueSignal.activeLength;
    for (int i = 0; i < n; i++) {
      final p = q.queueSignal.pathAtActiveIndex(i);
      if (p != null) activePaths.add(p);
    }
    if (activePaths.isEmpty) return;

    final songs = activePaths.map(resolveSong).toList();
    await handler.reorderQueue(songs);
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

    if (songs.isEmpty || _audioHandler is! MyAudioHandler) return;
    final handler = _audioHandler;

    if (shuffle) {
      await playShuffledFromList(songs);
      return;
    }

    // Sequential play through the playlist.
    final paths = songs.map((s) => s.path).toList();
    q.queueSignal.setPlaylist(paths, playPath: paths.first);
    await handler.setPlaylist(songs);
    await handler.playSong(songs.first);
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
    if (_hasMusicCache.containsKey(dir.path)) {
      return _hasMusicCache[dir.path]!;
    }
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && _isSupportedAudio(entity.path)) {
          _hasMusicCache[dir.path] = true;
          return true;
        }
      }
    } catch (_) {}
    _hasMusicCache[dir.path] = false;
    return false;
  }

  Future<void> addFolderToPlaylist(String playlistId, String folderPath) async {
    final dir = Directory(folderPath);
    _hasMusicCache[dir.path] = true;
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
    _sleepInternalTimer?.cancel();
    _sleepInternalTimer = null;

    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    for (final dispose in _effectDisposals) {
      dispose();
    }
    _effectDisposals.clear();
  }

  Future<void> updateSongMetadata(
    String path, {
    String? title,
    String? artist,
    String? album,
    String? imagePath,
  }) async {
    try {
      final file = File(path);
      if (!await file.exists()) return;

      // 1. Prepare image bytes if needed
      Uint8List? imageBytes;
      String? mimeType;
      if (imagePath != null) {
        final imageFile = File(imagePath);
        if (await imageFile.exists()) {
          imageBytes = await imageFile.readAsBytes();
          mimeType = imagePath.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg';
        }
      }

      // 2. Perform safe read-modify-write via audio_metadata_reader
      updateMetadata(file, (metadata) {
        if (title != null) metadata.setTitle(title);
        if (artist != null) metadata.setArtist(artist);
        if (album != null) metadata.setAlbum(album);

        if (imageBytes != null) {
          final newPic = Picture(imageBytes, mimeType!, PictureType.coverFront);

          if (metadata is Mp3Metadata) {
            final pics = List<Picture>.from(metadata.pictures);
            pics.removeWhere((p) => p.pictureType == PictureType.coverFront);
            pics.insert(0, newPic);
            metadata.pictures = pics;
          } else if (metadata is Mp4Metadata) {
            metadata.picture = newPic;
          } else if (metadata is VorbisMetadata) {
            final pics = List<Picture>.from(metadata.pictures);
            pics.removeWhere((p) => p.pictureType == PictureType.coverFront);
            pics.insert(0, newPic);
            metadata.pictures = pics;
          } else if (metadata is RiffMetadata) {
            final pics = List<Picture>.from(metadata.pictures);
            pics.removeWhere((p) => p.pictureType == PictureType.coverFront);
            pics.insert(0, newPic);
            metadata.pictures = pics;
          } else {
            // Fallback: try common setter extension if available
            try {
              metadata.setPictures([newPic]);
            } catch (_) {}
          }
        }
      });

      // 3. Update cached album art if image changed
      if (imageBytes != null) {
        final artDir = await SongCache.artDir;
        final artFile = File('$artDir/${path.hashCode.abs()}.jpg');
        await artFile.writeAsBytes(imageBytes);
        await evictImageProvider(FileImage(artFile));
      }

      // 4. Update local state
      final index = allSongs.value.indexWhere((s) => s.path == path);
      if (index != -1) {
        final oldSong = allSongs.value[index];
        final updatedSong = oldSong.copyWith(
          title: title ?? oldSong.title,
          artist: artist ?? oldSong.artist,
          album: album ?? oldSong.album,
          hasAlbumArt: imagePath != null ? true : oldSong.hasAlbumArt,
        );

        final newList = List<Song>.from(allSongs.value);
        newList[index] = updatedSong;
        allSongs.value = newList;

        if (currentSong.value?.path == path) {
          currentSong.value = updatedSong;
        }

        await SongCache.saveCache(allSongs.value);
      }
    } catch (e) {
      debugPrint('Error writing metadata: $e');
      rethrow;
    }
  }

  Future<void> evictImageProvider(ImageProvider provider) async {
    try {
      await provider.evict();
    } catch (_) {}
  }
}

class AppAudioMetadata {
  final File file;
  final String? album;
  final String? artist;
  final int? bitrate;
  final Duration? duration;
  final String? title;
  final int? trackNumber;
  final int? trackTotal;
  final DateTime? year;
  final int? discNumber;
  List<Picture> pictures = [];
  double gainDb = 0.0; // ReplayGain track gain
  double trackPeak = 1.0;
  double albumGainDb = 0.0;
  double albumPeak = 1.0;

  AppAudioMetadata({
    required this.file,
    this.album,
    this.artist,
    this.bitrate,
    this.duration,
    this.title,
    this.trackNumber,
    this.trackTotal,
    this.year,
    this.discNumber,
    this.gainDb = 0.0,
    this.trackPeak = 1.0,
    this.albumGainDb = 0.0,
    this.albumPeak = 1.0,
  });
}

double _parseGain(dynamic value) {
  if (value == null) return 0.0;
  String s = value.toString();
  // Remove " dB", "dB", etc.
  s = s.replaceAll(RegExp(r'[a-zA-Z\s]+'), '').trim();
  return double.tryParse(s) ?? 0.0;
}

double _parsePeak(dynamic value) {
  if (value == null) return 1.0;
  String s = value.toString();
  return double.tryParse(s.trim()) ?? 1.0;
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
  final Set<String> excludedPaths = params['excludedPaths'] ?? {};
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
        final path = entity.path;

        // Check exclusions
        bool isExcluded = false;
        for (final excluded in excludedPaths) {
          if (path.startsWith(excluded)) {
            isExcluded = true;
            break;
          }
        }
        if (isExcluded) continue;

        if (entity is File && _isSupportedAudio(path)) {
          if (!cachedPaths.contains(path)) {
            filesToProcess.add(path);
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

        // Use a robust metadata reader that ensures file handles are closed
        AppAudioMetadata? metadata;
        try {
          // Open the file ourselves to ensure we can close it if the parser fails
          final reader = File(path).openSync();
          try {
            // Check if it's ID3 (covers v2.2, v2.3, v2.4)
            if (ID3v2Parser.canUserParser(reader)) {
              // ID3v2Parser.parse will close the reader on success,
              // but we wrap it in a try-finally just in case it throws before/after.
              final mp3Meta = ID3v2Parser(fetchImage: true).parse(reader);
              metadata = AppAudioMetadata(
                file: File(path),
                album: (mp3Meta as dynamic).album,
                artist:
                    (mp3Meta as dynamic).bandOrOrchestra ??
                    (mp3Meta as dynamic).leadPerformer ??
                    (mp3Meta as dynamic).originalArtist,
                bitrate: (mp3Meta as dynamic).bitrate,
                duration: (mp3Meta as dynamic).duration,
                title: (mp3Meta as dynamic).songName,
                trackNumber: (mp3Meta as dynamic).trackNumber,
                trackTotal: (mp3Meta as dynamic).trackTotal,
                year: DateTime(
                  (mp3Meta as dynamic).originalReleaseYear ??
                      (mp3Meta as dynamic).year ??
                      0,
                ),
                discNumber: (mp3Meta as dynamic).discNumber,
              );
              metadata.pictures = List<Picture>.from(
                (mp3Meta as dynamic).pictures,
              );
              // Extract ReplayGain from TXXX frames
              try {
                final customMeta =
                    (mp3Meta as dynamic).customMetadata as Map<String, String>?;
                if (customMeta != null) {
                  metadata.gainDb = _parseGain(
                    customMeta['REPLAYGAIN_TRACK_GAIN'] ??
                        customMeta['replaygain_track_gain'],
                  );
                  metadata.trackPeak = _parsePeak(
                    customMeta['REPLAYGAIN_TRACK_PEAK'] ??
                        customMeta['replaygain_track_peak'],
                  );
                  metadata.albumGainDb = _parseGain(
                    customMeta['REPLAYGAIN_ALBUM_GAIN'] ??
                        customMeta['replaygain_album_gain'],
                  );
                  metadata.albumPeak = _parsePeak(
                    customMeta['REPLAYGAIN_ALBUM_PEAK'] ??
                        customMeta['replaygain_album_peak'],
                  );
                }
              } catch (_) {}

              // Fallback for ID3v2.2 (PIC frame) if no pictures found
              if (metadata.pictures.isEmpty) {
                try {
                  reader.setPositionSync(0);
                  final header = reader.readSync(10);
                  if (header[3] == 2) {
                    // ID3v2.2
                    // Brute force search for PIC frame in the first 128KB
                    final bytes = reader.lengthSync() < 128000
                        ? reader.readSync(reader.lengthSync())
                        : reader.readSync(128000);

                    int picIndex = -1;
                    for (int j = 0; j < bytes.length - 3; j++) {
                      if (bytes[j] == 80 &&
                          bytes[j + 1] == 73 &&
                          bytes[j + 2] == 67) {
                        // "PIC"
                        picIndex = j;
                        break;
                      }
                    }

                    if (picIndex != -1) {
                      // PIC frame header is 6 bytes: ID(3), Size(3)
                      final size =
                          (bytes[picIndex + 3] << 16) |
                          (bytes[picIndex + 4] << 8) |
                          bytes[picIndex + 5];
                      if (size > 0 && picIndex + 6 + size <= bytes.length) {
                        final frameData = bytes.sublist(
                          picIndex + 6,
                          picIndex + 6 + size,
                        );
                        // Skip encoding(1) and fixed format(3) and picture type(1) and description(var)
                        // This is a rough estimation, but usually the image data follows a null terminator or fixed offset
                        int imgOffset = 5; // encoding(1) + format(3) + type(1)
                        if (imgOffset < frameData.length) {
                          metadata.pictures.add(
                            Picture(
                              frameData.sublist(imgOffset),
                              'image/jpeg',
                              PictureType.coverFront,
                            ),
                          );
                        }
                      }
                    }
                  }
                } catch (_) {}
              }
            } else if (FlacParser.canUserParser(reader)) {
              final vorbisMeta = FlacParser(fetchImage: true).parse(reader);
              metadata = AppAudioMetadata(
                file: File(path),
                album: (vorbisMeta as dynamic).album.firstOrNull,
                artist: (vorbisMeta as dynamic).artist.firstOrNull,
                bitrate: (vorbisMeta as dynamic).bitrate,
                duration: (vorbisMeta as dynamic).duration,
                title: (vorbisMeta as dynamic).title.firstOrNull,
                trackNumber: int.tryParse(
                  (vorbisMeta as dynamic).trackNumber.firstOrNull ?? '',
                ),
                trackTotal: int.tryParse(
                  (vorbisMeta as dynamic).trackTotal.firstOrNull ?? '',
                ),
                year: (vorbisMeta as dynamic).date.firstOrNull,
                discNumber: (vorbisMeta as dynamic).discNumber,
              );
              metadata.pictures = List<Picture>.from(
                (vorbisMeta as dynamic).pictures,
              );
              // Extract ReplayGain from Vorbis comments
              try {
                metadata.gainDb = _parseGain(
                  ((vorbisMeta as dynamic).replayGainTrackGain as List?)
                      ?.firstOrNull,
                );
                metadata.trackPeak = _parsePeak(
                  ((vorbisMeta as dynamic).replayGainTrackPeak as List?)
                      ?.firstOrNull,
                );
                metadata.albumGainDb = _parseGain(
                  ((vorbisMeta as dynamic).replayGainAlbumGain as List?)
                      ?.firstOrNull,
                );
                metadata.albumPeak = _parsePeak(
                  ((vorbisMeta as dynamic).replayGainAlbumPeak as List?)
                      ?.firstOrNull,
                );
              } catch (_) {}
            } else if (MP4Parser.canUserParser(reader)) {
              final mp4Meta = MP4Parser(fetchImage: true).parse(reader);
              metadata = AppAudioMetadata(
                file: File(path),
                album: (mp4Meta as dynamic).album,
                artist: (mp4Meta as dynamic).artist,
                bitrate: (mp4Meta as dynamic).bitrate,
                duration: (mp4Meta as dynamic).duration,
                title: (mp4Meta as dynamic).title,
                trackNumber: (mp4Meta as dynamic).trackNumber,
                trackTotal: (mp4Meta as dynamic).totalTracks,
                year: (mp4Meta as dynamic).year,
                discNumber: (mp4Meta as dynamic).discNumber,
              );
              if ((mp4Meta as dynamic).picture != null) {
                metadata.pictures.add((mp4Meta as dynamic).picture!);
              }
            } else if (OGGParser.canUserParser(reader)) {
              final oggMeta = OGGParser(fetchImage: true).parse(reader);
              metadata = AppAudioMetadata(
                file: File(path),
                album: (oggMeta as dynamic).album.firstOrNull,
                artist: (oggMeta as dynamic).artist.firstOrNull,
                bitrate: (oggMeta as dynamic).bitrate,
                duration: (oggMeta as dynamic).duration,
                title: (oggMeta as dynamic).title.firstOrNull,
                trackNumber: int.tryParse(
                  (oggMeta as dynamic).trackNumber.firstOrNull ?? '',
                ),
                trackTotal: int.tryParse(
                  (oggMeta as dynamic).trackTotal.firstOrNull ?? '',
                ),
                year: (oggMeta as dynamic).date.firstOrNull,
                discNumber: (oggMeta as dynamic).discNumber,
              );
              metadata.pictures.addAll((oggMeta as dynamic).pictures);
              // Extract ReplayGain from Vorbis comments (OGG)
              try {
                metadata.gainDb = _parseGain(
                  ((oggMeta as dynamic).replayGainTrackGain as List?)
                      ?.firstOrNull,
                );
                metadata.trackPeak = _parsePeak(
                  ((oggMeta as dynamic).replayGainTrackPeak as List?)
                      ?.firstOrNull,
                );
                metadata.albumGainDb = _parseGain(
                  ((oggMeta as dynamic).replayGainAlbumGain as List?)
                      ?.firstOrNull,
                );
                metadata.albumPeak = _parsePeak(
                  ((oggMeta as dynamic).replayGainAlbumPeak as List?)
                      ?.firstOrNull,
                );
              } catch (_) {}
            } else {
              // Fallback to the package's default readMetadata which might leak on error
              // but at least we tried to be safe for most cases.
              reader.closeSync(); // Close our reader first
              final fallbackMeta = readMetadata(File(path), getImage: true);
              metadata = AppAudioMetadata(
                file: File(path),
                album: fallbackMeta.album,
                artist: fallbackMeta.artist,
                bitrate: fallbackMeta.bitrate,
                duration: fallbackMeta.duration,
                title: fallbackMeta.title,
                trackNumber: fallbackMeta.trackNumber,
                trackTotal: fallbackMeta.trackTotal,
                year: fallbackMeta.year,
                discNumber: fallbackMeta.discNumber,
              );
              metadata.pictures = fallbackMeta.pictures;
            }
          } finally {
            // Ensure reader is closed if it wasn't already by the parser
            try {
              reader.closeSync();
            } catch (_) {
              // Already closed on success, that's fine
            }
          }
        } catch (e) {
          // If our manual parsing fails, try the standard way as a last resort
          try {
            final fallbackMeta = readMetadata(File(path), getImage: true);
            metadata = AppAudioMetadata(
              file: File(path),
              album: fallbackMeta.album,
              artist: fallbackMeta.artist,
              bitrate: fallbackMeta.bitrate,
              duration: fallbackMeta.duration,
              title: fallbackMeta.title,
              trackNumber: fallbackMeta.trackNumber,
              trackTotal: fallbackMeta.trackTotal,
              year: fallbackMeta.year,
              discNumber: fallbackMeta.discNumber,
            );
            metadata.pictures = fallbackMeta.pictures;
          } catch (_) {
            metadata = null;
          }
        }

        if (metadata == null) {
          sendPort.send(Song.fromPath(path));
          continue;
        }

        bool hasArt = false;
        if (metadata.pictures.isNotEmpty) {
          try {
            final artPath = '$artDir/${path.hashCode.abs()}.jpg';
            final artFile = File(artPath);
            if (!await artFile.exists()) {
              Picture selectedPic;
              try {
                selectedPic = metadata.pictures.firstWhere(
                  (p) => p.pictureType == PictureType.coverFront,
                );
              } catch (_) {
                selectedPic = metadata.pictures.first;
              }

              // Robust check: find the real start of image data (Magic Bytes)
              // The library often skips too many or too few bytes for the description offset.
              Uint8List bytes = selectedPic.bytes;
              int imageStart = -1;
              for (int j = 0; j < bytes.length - 8; j++) {
                // JPEG: FF D8 FF
                if (bytes[j] == 0xFF &&
                    bytes[j + 1] == 0xD8 &&
                    bytes[j + 2] == 0xFF) {
                  imageStart = j;
                  break;
                }
                // PNG: 89 50 4E 47
                if (bytes[j] == 0x89 &&
                    bytes[j + 1] == 0x50 &&
                    bytes[j + 2] == 0x4E &&
                    bytes[j + 3] == 0x47) {
                  imageStart = j;
                  break;
                }
              }

              if (imageStart != -1 && imageStart > 0) {
                bytes = bytes.sublist(imageStart);
              }

              await artFile.writeAsBytes(bytes);
              hasArt = true;
            } else {
              hasArt = true;
            }
          } catch (e) {
            // Silently fail artwork, but song is still indexed
          }
        }

        // Fallback to sidecar art if still no art
        if (!hasArt) {
          final sidecar = _findSidecarArt(path);
          if (sidecar != null) {
            try {
              final artPath = '$artDir/${path.hashCode.abs()}.jpg';
              await sidecar.copy(artPath);
              hasArt = true;
            } catch (_) {}
          }
        }

        final file = File(path);
        final fileSizeBytes = await file.length();
        final modifiedAt = file.lastModifiedSync();

        // Use bitrate from metadata if available, otherwise calculate from file size
        int? bitrate = metadata.bitrate != null
            ? (metadata.bitrate! / 1000).round()
            : null;
        if (bitrate == null &&
            metadata.duration != null &&
            metadata.duration!.inSeconds > 0) {
          final durationSeconds = metadata.duration!.inSeconds;
          bitrate = ((fileSizeBytes * 8) / durationSeconds / 1000).round();
        }

        final parsed = MetadataService().parseFromFilename(path);
        final hasTitle =
            metadata.title != null && metadata.title!.trim().isNotEmpty;
        final hasArtist =
            metadata.artist != null && metadata.artist != 'Unknown Artist';

        final song = Song(
          path: path,
          title: hasTitle ? metadata.title! : parsed['title']!,
          artist: hasArtist ? metadata.artist! : parsed['artist']!,
          album: metadata.album,
          hasAlbumArt: hasArt,
          duration: metadata.duration,
          bitrate: bitrate,
          size: fileSizeBytes,
          modifiedAt: modifiedAt,
          gainDb: metadata.gainDb,
          trackPeak: metadata.trackPeak,
          albumGainDb: metadata.albumGainDb,
          albumPeak: metadata.albumPeak,
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
    final metadata = readMetadata(File(path), getImage: true);

    if (metadata.pictures.isNotEmpty && artDir != null) {
      try {
        final artPath = '$artDir/${path.hashCode.abs()}.jpg';
        final artFile = File(artPath);
        if (!await artFile.exists()) {
          Picture selectedPic;
          try {
            selectedPic = metadata.pictures.firstWhere(
              (p) => p.pictureType == PictureType.coverFront,
            );
          } catch (_) {
            selectedPic = metadata.pictures.first;
          }
          await artFile.writeAsBytes(selectedPic.bytes);
        }
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

File? _findSidecarArt(String audioPath) {
  try {
    final file = File(audioPath);
    final directory = file.parent;
    if (!directory.existsSync()) return null;

    final sidecarNames = [
      'cover.jpg',
      'cover.png',
      'cover.jpeg',
      'folder.jpg',
      'folder.png',
      'folder.jpeg',
      'album.jpg',
      'album.png',
      '.folder.jpg',
      '.folder.png',
    ];

    for (final name in sidecarNames) {
      final sidecar = File('${directory.path}/$name');
      if (sidecar.existsSync()) return sidecar;
    }

    // Try case-insensitive matching if not found
    final list = directory.listSync();
    for (final entity in list) {
      if (entity is File) {
        final name = entity.path.split('/').last.toLowerCase();
        if (name == 'cover.jpg' ||
            name == 'cover.png' ||
            name == 'folder.jpg' ||
            name == 'folder.png' ||
            name == 'album.jpg' ||
            name == 'album.png') {
          return entity;
        }
      }
    }
  } catch (_) {}
  return null;
}
