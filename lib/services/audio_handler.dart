import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:home_widget/home_widget.dart';
import '../models/song.dart';
import '../signals/audio_signal.dart';
import '../signals/settings_signal.dart';
import 'album_art_cache.dart';
import 'playback_history_service.dart';
import 'youtube_service.dart';
import 'YoutubeDatasource.dart';

class MyAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();
  int _currentIndex = 0;
  List<int> _shuffledIndices = [];
  final _shuffleIndicesController = StreamController<List<int>>.broadcast();
  Stream<List<int>> get shuffleIndicesStream => _shuffleIndicesController.stream;
  AudioServiceShuffleMode _shuffleMode = AudioServiceShuffleMode.none;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;

  // Loading lock to prevent concurrent _playCurrent calls
  Completer<void>? _loadingCompleter;
  bool _isDisposed = false;

  // Subscriptions for proper cleanup
  final List<StreamSubscription> _subscriptions = [];

  // Album art cache
  final AlbumArtCache _artCache = AlbumArtCache();

  // History tracking
  Timer? _historyTimer;
  bool _hasRecordedCurrent = false;
  String? _lastTrackId;

  // Gapless playback — instant switch mode (no ConcatenatingAudioSource)
  bool _gaplessMode = false;

  // Audio normalization
  bool _normalizationEnabled = false;
  double _normalizationTargetLufs = -14.0;
  final Map<String, double> _gainMap = {}; // path -> gainDb

  MyAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    // Load settings
    _gaplessMode = settingsSignal.gaplessPlayback.value;
    _normalizationEnabled = settingsSignal.audioNormalization.value;
    _normalizationTargetLufs = settingsSignal.normalizationTargetLufs.value;

    // Broadcast playback state changes
    _subscriptions.add(
      _player.playerStateStream.listen((state) {
        if (_isDisposed) return;

        final playing = state.playing;
        final processingState = state.processingState;

        playbackState.add(
          playbackState.value.copyWith(
            controls: [
              MediaControl.skipToPrevious,
              if (playing) MediaControl.pause else MediaControl.play,
              MediaControl.stop,
              MediaControl.skipToNext,
            ],
            systemActions: const {
              MediaAction.seek,
              MediaAction.seekForward,
              MediaAction.seekBackward,
            },
            androidCompactActionIndices: const [0, 1, 3],
            processingState: const {
              ProcessingState.idle: AudioProcessingState.idle,
              ProcessingState.loading: AudioProcessingState.loading,
              ProcessingState.buffering: AudioProcessingState.buffering,
              ProcessingState.ready: AudioProcessingState.ready,
              ProcessingState.completed: AudioProcessingState.completed,
            }[processingState]!,
            playing: playing,
            updatePosition: _player.position,
            bufferedPosition: _player.bufferedPosition,
            speed: _player.speed,
            queueIndex: _currentIndex,
            shuffleMode: _shuffleMode,
            repeatMode: _repeatMode,
          ),
        );
        _updateWidget();
        _handleHistoryTracking(playing);
      }),
    );

    // Handle auto-advance on track completion
    _subscriptions.add(
      _player.processingStateStream.listen((state) {
        if (_isDisposed) return;
        if (state == ProcessingState.completed) {
          if (_repeatMode == AudioServiceRepeatMode.one) {
            // Repeat one: just restart current track
            _player.seek(Duration.zero);
            _player.play();
          } else if (_repeatMode == AudioServiceRepeatMode.none && _isAtEnd) {
            stop();
          } else {
            // Auto-advance to next track (gapless or normal)
            skipToNext();
          }
        }
      }),
    );

    // Sync duration
    _subscriptions.add(
      _player.durationStream.listen((duration) {
        if (_isDisposed) return;
        if (duration != null) {
          final index = _currentIndex;
          if (index >= 0 && index < queue.value.length) {
            final item = queue.value[index];
            if (item.duration != duration) {
              final newItem = item.copyWith(duration: duration);
              queue.value[index] = newItem;
              if (mediaItem.value?.id == item.id) {
                mediaItem.add(newItem);
              }
            }
          }
        }
      }),
    );

    // Listen for mediaItem changes to update widget
    _subscriptions.add(
      mediaItem.listen((item) {
        if (item != null) {
          _updateWidget();
        }
      }),
    );
  }

  /// Apply per-track volume normalization
  void _applyNormalization(String trackId) {
    if (_normalizationEnabled) {
      final gainDb = _gainMap[trackId] ?? 0.0;
      // Volume multiplier: 10^(gainDb / 20)
      // targetLufs adjusts relative to reference (-14 LUFS is standard)
      final adjustedGain = gainDb + (_normalizationTargetLufs + 14.0);
      final volume = pow(10.0, adjustedGain / 20.0).clamp(0.1, 2.0).toDouble();
      _player.setVolume(volume);
    } else {
      _player.setVolume(1.0);
    }
  }

  /// Update normalization setting at runtime
  void setNormalizationEnabled(bool enabled) {
    _normalizationEnabled = enabled;
    if (mediaItem.value != null) {
      _applyNormalization(mediaItem.value!.id);
    }
  }

  /// Update normalization target LUFS at runtime
  void setNormalizationTargetLufs(double lufs) {
    _normalizationTargetLufs = lufs;
    if (_normalizationEnabled && mediaItem.value != null) {
      _applyNormalization(mediaItem.value!.id);
    }
  }

  /// Store gain values for normalization lookup
  void setGainMap(Map<String, double> gainMap) {
    _gainMap.clear();
    _gainMap.addAll(gainMap);
  }

  /// Update a single gain entry (e.g. after metadata edit)
  void updateGain(String path, double gainDb) {
    _gainMap[path] = gainDb;
  }

  /// Update gapless mode setting (no source rebuild needed — just a flag)
  Future<void> setGaplessMode(bool enabled) async {
    _gaplessMode = enabled;
  }

  Future<void> _updateWidget() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final item = mediaItem.value;
    final isPlaying = playbackState.value.playing;

    if (item == null ||
        playbackState.value.processingState == AudioProcessingState.idle) {
      await HomeWidget.saveWidgetData<String>('title', 'Not Playing');
      await HomeWidget.saveWidgetData<String>('artist', '-');
      await HomeWidget.saveWidgetData<bool>('isPlaying', false);
      await HomeWidget.saveWidgetData<String?>('artPath', null);
    } else {
      await HomeWidget.saveWidgetData<String>('title', item.title);
      await HomeWidget.saveWidgetData<String>('artist', item.artist ?? "-");
      await HomeWidget.saveWidgetData<bool>('isPlaying', isPlaying);

      String? artPath;
      if (item.artUri != null && item.artUri!.isScheme('file')) {
        artPath = item.artUri!.toFilePath();
      }
      await HomeWidget.saveWidgetData<String?>('artPath', artPath);
    }

    await HomeWidget.updateWidget(
      name: 'MusicWidgetProvider',
      androidName: 'MusicWidgetProvider',
    );
  }

  Future<void> setPlaylist(List<Song> songs) async {
    print('Setting playlist with ${songs.length} songs');

    // Initialize album art cache
    await _artCache.init();

    // Store gain values for normalization
    _gainMap.clear();
    for (final song in songs) {
      if (song.gainDb != 0.0) {
        _gainMap[song.path] = song.gainDb;
      }
    }

    // Convert songs to MediaItems (without art URIs for local files - loaded lazily when played)
    final mediaItems = songs.map((song) {
      Uri? initialArtUri;
      final cachedPath = _artCache.getArtPathSync(song.path);
      if (cachedPath != null) {
        initialArtUri = Uri.file(cachedPath);
      } else if (song.path.startsWith('yt:')) {
        final videoId = song.path.substring(3);
        initialArtUri = Uri.parse(youtubeDatasource.getArtworkUrl(videoId));
      }

      return MediaItem(
        id: song.path,
        album: song.album ?? "Unknown Album",
        title: song.title,
        artist: song.artist,
        artUri: initialArtUri,
        extras: {'path': song.path, 'hasAlbumArt': song.hasAlbumArt},
      );
    }).toList();

    // Update the queue
    queue.add(mediaItems);
    _currentIndex = 0;
    _shuffledIndices = [];

    // Refresh gapless setting
    _gaplessMode = settingsSignal.gaplessPlayback.value;

    if (_shuffleMode == AudioServiceShuffleMode.all) {
      _generateShuffledIndices();
    } else {
      _shuffleIndicesController.add([]);
    }

    // Don't auto-play, just be ready
    if (mediaItems.isNotEmpty) {
      mediaItem.add(mediaItems[0]);
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
    _updateWidget();
  }

  @override
  Future<void> play() async {
    if (_player.processingState == ProcessingState.idle) {
      await _playCurrent();
    } else {
      await _player.play();
    }
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _shuffleMode = shuffleMode;
    if (shuffleMode == AudioServiceShuffleMode.all) {
      _generateShuffledIndices();
    } else {
      _shuffledIndices = [];
      _shuffleIndicesController.add([]);
    }
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final currentQueue = queue.value;
    final newQueue = [...currentQueue, mediaItem];

    if (_shuffleMode == AudioServiceShuffleMode.all) {
      final newIndex = newQueue.length - 1;
      _shuffledIndices.add(newIndex);
      _shuffleIndicesController.add(List<int>.from(_shuffledIndices));
    }

    queue.add(newQueue);
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    final id = mediaItem.id;
    final currentQueue = List<MediaItem>.from(queue.value);
    
    final indicesToRemove = <int>[];
    for (int i = 0; i < currentQueue.length; i++) {
      if (currentQueue[i].id == id) {
        indicesToRemove.add(i);
      }
    }

    if (indicesToRemove.isEmpty) return;

    for (final index in indicesToRemove.reversed) {
      currentQueue.removeAt(index);

      if (_shuffledIndices.isNotEmpty) {
        _shuffledIndices.remove(index);
        for (int i = 0; i < _shuffledIndices.length; i++) {
          if (_shuffledIndices[i] > index) {
            _shuffledIndices[i]--;
          }
        }
      }

      if (index < _currentIndex) {
        _currentIndex--;
      } else if (index == _currentIndex) {
        if (_currentIndex >= currentQueue.length) {
          _currentIndex = currentQueue.isNotEmpty ? currentQueue.length - 1 : 0;
        }
      }
    }

    if (_shuffledIndices.isNotEmpty) {
      _shuffleIndicesController.add(List<int>.from(_shuffledIndices));
    }

    queue.add(currentQueue);
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    final currentQueue = List<MediaItem>.from(queue.value);
    if (index < 0) index = 0;
    if (index > currentQueue.length) index = currentQueue.length;

    currentQueue.insert(index, mediaItem);

    if (_shuffledIndices.isNotEmpty) {
      for (int i = 0; i < _shuffledIndices.length; i++) {
        if (_shuffledIndices[i] >= index) {
          _shuffledIndices[i]++;
        }
      }

      final currentShuffledPos = _shuffledIndices.indexOf(_currentIndex);
      if (currentShuffledPos != -1) {
        _shuffledIndices.insert(currentShuffledPos + 1, index);
      } else {
        _shuffledIndices.add(index);
      }
      _shuffleIndicesController.add(List<int>.from(_shuffledIndices));
    }

    if (index <= _currentIndex) {
      _currentIndex++;
    }

    queue.add(currentQueue);
  }

  void _generateShuffledIndices() {
    final count = queue.value.length;
    _shuffledIndices = List.generate(count, (i) => i);
    _shuffledIndices.shuffle();

    if (count > 0) {
      _shuffledIndices.remove(_currentIndex);
      _shuffledIndices.insert(0, _currentIndex);
    }
    _shuffleIndicesController.add(List<int>.from(_shuffledIndices));
  }

  int _getNextIndex() {
    final count = queue.value.length;
    if (count == 0) return 0;

    if (_repeatMode == AudioServiceRepeatMode.one) {
      return _currentIndex;
    }

    if (_shuffleMode == AudioServiceShuffleMode.none ||
        _shuffledIndices.isEmpty) {
      final nextIndex = _currentIndex + 1;
      if (nextIndex < count) {
        return nextIndex;
      } else {
        return _repeatMode == AudioServiceRepeatMode.all ? 0 : _currentIndex;
      }
    }

    final currentShuffledPos = _shuffledIndices.indexOf(_currentIndex);
    if (currentShuffledPos != -1 &&
        currentShuffledPos < _shuffledIndices.length - 1) {
      return _shuffledIndices[currentShuffledPos + 1];
    }

    return _repeatMode == AudioServiceRepeatMode.all
        ? _shuffledIndices[0]
        : _currentIndex;
  }

  int _getPreviousIndex() {
    if (_shuffleMode == AudioServiceShuffleMode.none ||
        _shuffledIndices.isEmpty) {
      return (_currentIndex - 1 + queue.value.length) % queue.value.length;
    }
    final currentShuffledPos = _shuffledIndices.indexOf(_currentIndex);
    if (currentShuffledPos != -1 && currentShuffledPos > 0) {
      return _shuffledIndices[currentShuffledPos - 1];
    }
    return _shuffledIndices.last;
  }

  bool get _isAtEnd {
    final count = queue.value.length;
    if (count == 0) return true;
    if (_shuffleMode == AudioServiceShuffleMode.all && _shuffledIndices.isNotEmpty) {
      return _shuffledIndices.last == _currentIndex;
    }
    return _currentIndex == count - 1;
  }

  @override
  Future<void> skipToNext() async {
    if (queue.value.isEmpty) return;

    if (_repeatMode == AudioServiceRepeatMode.none && _isAtEnd) {
      _currentIndex = _shuffleMode == AudioServiceShuffleMode.all && _shuffledIndices.isNotEmpty
          ? _shuffledIndices[0]
          : 0;
    } else {
      _currentIndex = _getNextIndex();
    }
    await _playCurrent();
  }

  @override
  Future<void> skipToPrevious() async {
    if (queue.value.isEmpty) return;
    _currentIndex = _getPreviousIndex();
    await _playCurrent();
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    final index = queue.value.indexWhere((item) => item.id == mediaItem.id);
    if (index != -1) {
      _currentIndex = index;
      await _playCurrent();
    }
  }

  // Custom method to play a specific song from the provider
  Future<void> playSong(Song song) async {
    final index = queue.value.indexWhere((item) => item.id == song.path);
    if (index != -1) {
      _currentIndex = index;
      await _playCurrent();
    }
  }

  Future<void> _playCurrent() async {
    if (_isDisposed || queue.value.isEmpty) return;

    // Cancel any ongoing load operation
    if (_loadingCompleter != null && !_loadingCompleter!.isCompleted) {
      _loadingCompleter!.complete();
    }

    final thisLoad = Completer<void>();
    _loadingCompleter = thisLoad;

    var item = queue.value[_currentIndex];

    // Lazily load art URI for MPRIS
    if (!item.id.startsWith('yt:') && item.artUri == null && item.extras?['hasAlbumArt'] == true) {
      final artUri = await _artCache.getArtUri(item.id);
      if (artUri != null) {
        item = item.copyWith(artUri: artUri);
        final updatedQueue = List<MediaItem>.from(queue.value);
        updatedQueue[_currentIndex] = item;
        queue.add(updatedQueue);
        if (mediaItem.value?.id == item.id) {
          mediaItem.add(item);
        }
      }
    } else if (item.id.startsWith('yt:')) {
      final videoId = item.id.substring(3);
      final thumbUri = Uri.parse(youtubeDatasource.getArtworkUrl(videoId));
      item = item.copyWith(artUri: thumbUri);
      
      // Cache artwork locally for OS controls/widgets
      _artCache.getArt(item.id).then((file) {
        if (file != null && file.existsSync()) {
          final artUri = Uri.file(file.path);
          final updatedItem = item.copyWith(artUri: artUri);
          
          // Update queue so subsequent updates (like duration) use the local URI
          final currentQueue = queue.value;
          if (_currentIndex < currentQueue.length && currentQueue[_currentIndex].id == item.id) {
            final updatedQueue = List<MediaItem>.from(currentQueue);
            updatedQueue[_currentIndex] = updatedItem;
            queue.add(updatedQueue);
          }

          if (mediaItem.value?.id == item.id) {
            mediaItem.add(updatedItem);
          }
        }
      });
    }

    mediaItem.add(item);

    // Apply normalization for the new track
    _applyNormalization(item.id);

    try {
      if (thisLoad.isCompleted || _isDisposed) return;

      if (item.id.startsWith('yt:')) {
        final videoId = item.id.substring(3);
        final url = await youtubeService.getAudioStreamUrl(videoId);
        if (url != null) {
          await _player.setAudioSource(
            AudioSource.uri(
              Uri.parse(url),
              tag: item,
              headers: const {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              },
            ),
          );
        } else {
          throw Exception('Could not resolve YouTube stream');
        }
      } else {
        await _player.setAudioSource(
          AudioSource.uri(Uri.file(item.id), tag: item),
        );
      }

      if (thisLoad.isCompleted || _isDisposed) return;

      await _player.play();
    } on PlayerInterruptedException catch (_) {
      print("Audio loading interrupted (switching tracks)");
    } catch (e) {
      if (e.toString().contains('Loading interrupted')) {
        print("Audio loading interrupted (switching tracks)");
      } else {
        print("Error playing audio: $e");
      }
    } finally {
      if (_loadingCompleter == thisLoad && !thisLoad.isCompleted) {
        thisLoad.complete();
      }
    }
  }

  void _handleHistoryTracking(bool isPlaying) {
    final currentId = mediaItem.value?.id;

    if (currentId != _lastTrackId) {
      _historyTimer?.cancel();
      _historyTimer = null;
      _hasRecordedCurrent = false;
      _lastTrackId = currentId;
    }

    if (isPlaying && !_hasRecordedCurrent && currentId != null && !currentId.startsWith('yt:')) {
      _historyTimer ??= Timer(const Duration(seconds: 40), () async {
        if (mediaItem.value?.id == currentId && !_hasRecordedCurrent) {
          _hasRecordedCurrent = true;
          await PlaybackHistoryService.recordPlay(currentId);
          await audioSignal.refreshHistory();
          print('HISTORY_DEBUG: Recorded play for $currentId');
        }
      });
    } else if (!isPlaying) {
      if (!_hasRecordedCurrent && _historyTimer != null) {
        _historyTimer?.cancel();
        _historyTimer = null;
      }
    }
  }

  // Expose player for direct access if needed
  AudioPlayer get player => _player;

  /// Dispose of resources
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    if (_loadingCompleter != null && !_loadingCompleter!.isCompleted) {
      _loadingCompleter!.complete();
    }

    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    _historyTimer?.cancel();
    _historyTimer = null;

    await _shuffleIndicesController.close();

    await _player.dispose();
  }
}
