import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:home_widget/home_widget.dart';
import '../models/song.dart';
import '../signals/audio_signal.dart';
import 'album_art_cache.dart';
import 'playback_history_service.dart';

class MyAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();
  // We'll use the 'queue' behavior subject from BaseAudioHandler to store the playlist
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

  MyAudioHandler() {
    _init();
  }

  // Throttle for playback event updates

  Future<void> _init() async {
    // Broadcast playback state changes (throttled to reduce CPU for position updates, but immediate for play/pause)
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

    // Propagate processing state to playback state and handle auto-advance
    _subscriptions.add(
      _player.processingStateStream.listen((state) {
        if (_isDisposed) return;
        if (state == ProcessingState.completed) {
          if (_repeatMode == AudioServiceRepeatMode.none && _isAtEnd) {
            stop();
          } else {
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
              // Update the item in the queue
              final newItem = item.copyWith(duration: duration);
              queue.value[index] = newItem;
              // Also update current mediaItem if it matches
              if (mediaItem.value?.id == item.id) {
                mediaItem.add(newItem);
              }
            }
          }
        }
      }),
    );

    // Listen for mediaItem changes to update widget
    mediaItem.listen((item) {
      if (item != null) {
        _updateWidget();
      }
    });
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

      // Get art path if available
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

    // Convert songs to MediaItems (without art URIs - loaded lazily when played)
    final mediaItems = songs.map((song) {
      return MediaItem(
        id: song.path,
        album: song.album ?? "Unknown Album",
        title: song.title,
        artist: song.artist,
        artUri: null, // Art URI loaded lazily when song plays
        extras: {'path': song.path, 'hasAlbumArt': song.hasAlbumArt},
      );
    }).toList();

    // Update the queue
    queue.add(mediaItems);
    _currentIndex = 0;
    _shuffledIndices = [];
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
    // Update playback state to reflect shuffle mode change
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
    // Update playback state to reflect repeat mode change
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
    
    // Find all occurrences
    final indicesToRemove = <int>[];
    for (int i = 0; i < currentQueue.length; i++) {
      if (currentQueue[i].id == id) {
        indicesToRemove.add(i);
      }
    }

    if (indicesToRemove.isEmpty) return;

    // Process removals from back to front to keep indices valid
    for (final index in indicesToRemove.reversed) {
      currentQueue.removeAt(index);

      // Update shuffled indices if they exist
      if (_shuffledIndices.isNotEmpty) {
        _shuffledIndices.remove(index);
        for (int i = 0; i < _shuffledIndices.length; i++) {
          if (_shuffledIndices[i] > index) {
            _shuffledIndices[i]--;
          }
        }
      }

      // Adjust _currentIndex if we removed something before or at it
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

  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    final currentQueue = List<MediaItem>.from(queue.value);
    if (index < 0) index = 0;
    if (index > currentQueue.length) index = currentQueue.length;

    currentQueue.insert(index, mediaItem);

    // Update shuffled indices if they exist
    if (_shuffledIndices.isNotEmpty) {
      // Increment all indices >= the insertion index
      for (int i = 0; i < _shuffledIndices.length; i++) {
        if (_shuffledIndices[i] >= index) {
          _shuffledIndices[i]++;
        }
      }

      // If it's a "Play Next" (implicitly determined by caller but we can handle it here)
      // Usually, the caller wants it to be the next song in the current sequence.
      // If shuffle is on, we find current index in shuffled list and insert there.
      final currentShuffledPos = _shuffledIndices.indexOf(_currentIndex);
      if (currentShuffledPos != -1) {
        _shuffledIndices.insert(currentShuffledPos + 1, index);
      } else {
        _shuffledIndices.add(index);
      }
      _shuffleIndicesController.add(List<int>.from(_shuffledIndices));
    }

    // Adjust _currentIndex if we inserted before the current position
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
    return _shuffledIndices.last; // Loop back
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
      // If repeat is off and we're at the end, maybe stop or loop back to first but don't play?
      // Standard behavior: clicking next at end usually loops back or stays at last.
      // Let's loop back but keep it playing if it was playing, or just move index.
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
    // Find index in queue
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
      // Signal that we're interrupting
      _loadingCompleter!.complete();
    }

    // Create a new completer for this load operation
    final thisLoad = Completer<void>();
    _loadingCompleter = thisLoad;

    var item = queue.value[_currentIndex];

    // Lazily load art URI for MPRIS if this song has album art
    if (item.artUri == null && item.extras?['hasAlbumArt'] == true) {
      final artUri = await _artCache.getArtUri(item.id);
      if (artUri != null) {
        // Create updated item with art URI
        item = item.copyWith(artUri: artUri);
        // Update queue with the updated item
        final updatedQueue = List<MediaItem>.from(queue.value);
        updatedQueue[_currentIndex] = item;
        queue.add(updatedQueue);
        // Explicitly update MediaItem to trigger listeners
        if (mediaItem.value?.id == item.id) {
          mediaItem.add(item);
        }
      }
    }

    mediaItem.add(item);

    try {
      // Stop current playback first to prevent overlap
      // await _player.stop(); // Removed to prevent notification flickering

      // Check if we were cancelled before loading
      if (thisLoad.isCompleted || _isDisposed) return;

      await _player.setAudioSource(
        AudioSource.uri(Uri.file(item.id), tag: item),
      );

      // Check if we were cancelled after loading
      if (thisLoad.isCompleted || _isDisposed) return;

      await _player.play();
    } on PlayerInterruptedException catch (_) {
      // Loading was interrupted by a new load request - this is expected
      print("Audio loading interrupted (switching tracks)");
    } catch (e) {
      // Handle "Loading interrupted" from just_audio
      if (e.toString().contains('Loading interrupted')) {
        print("Audio loading interrupted (switching tracks)");
      } else {
        print("Error playing audio: $e");
      }
    } finally {
      // Only complete if this is still the active load
      if (_loadingCompleter == thisLoad && !thisLoad.isCompleted) {
        thisLoad.complete();
      }
    }
  }

  void _handleHistoryTracking(bool isPlaying) {
    final currentId = mediaItem.value?.id;

    // Reset if track changed
    if (currentId != _lastTrackId) {
      _historyTimer?.cancel();
      _historyTimer = null;
      _hasRecordedCurrent = false;
      _lastTrackId = currentId;
    }

    if (isPlaying && !_hasRecordedCurrent && currentId != null) {
      // Start or resume timer
      _historyTimer ??= Timer(const Duration(seconds: 40), () async {
        if (mediaItem.value?.id == currentId && !_hasRecordedCurrent) {
          _hasRecordedCurrent = true;
          await PlaybackHistoryService.recordPlay(currentId);
          await audioSignal.refreshHistory();
          print('HISTORY_DEBUG: Recorded play for $currentId');
        }
      });
    } else if (!isPlaying) {
      // Pause timer - for simplicity, we'll just cancel and restart if they haven't hit 40s yet.
      // If we want "cumulative" 40s across pauses, we'd need a Stopwatch.
      if (!_hasRecordedCurrent && _historyTimer != null) {
        _historyTimer?.cancel();
        _historyTimer = null;
      }
    }
  }

  // Expose player for direct access if needed (though discouraged)
  AudioPlayer get player => _player;

  /// Dispose of resources to prevent native callback crashes
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    // Cancel any ongoing load
    if (_loadingCompleter != null && !_loadingCompleter!.isCompleted) {
      _loadingCompleter!.complete();
    }

    // Cancel all subscriptions
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _shuffleIndicesController.close();

    // Dispose the player
    await _player.dispose();
  }
}
