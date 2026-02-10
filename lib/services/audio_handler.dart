import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import 'album_art_cache.dart';

class MyAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();
  // We'll use the 'queue' behavior subject from BaseAudioHandler to store the playlist
  int _currentIndex = 0;
  List<int> _shuffledIndices = [];
  AudioServiceShuffleMode _shuffleMode = AudioServiceShuffleMode.none;

  // Loading lock to prevent concurrent _playCurrent calls
  Completer<void>? _loadingCompleter;
  bool _isDisposed = false;

  // Subscriptions for proper cleanup
  final List<StreamSubscription> _subscriptions = [];

  // Album art cache
  final AlbumArtCache _artCache = AlbumArtCache();

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
          ),
        );
      }),
    );

    // Propagate processing state to playback state and handle auto-advance
    _subscriptions.add(
      _player.processingStateStream.listen((state) {
        if (_isDisposed) return;
        if (state == ProcessingState.completed) {
          skipToNext();
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
    }
    // Update playback state to reflect shuffle mode change
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  void _generateShuffledIndices() {
    final count = queue.value.length;
    _shuffledIndices = List.generate(count, (i) => i);
    _shuffledIndices.shuffle();

    // Ensure current song is at the current position in shuffled list if possible
    // or just let it be random. Usually, if you toggle shuffle while playing,
    // you want the current song to stay, and the NEXT songs to be random.
    if (count > 0) {
      _shuffledIndices.remove(_currentIndex);
      _shuffledIndices.insert(0, _currentIndex);
    }
  }

  int _getNextIndex() {
    if (_shuffleMode == AudioServiceShuffleMode.none ||
        _shuffledIndices.isEmpty) {
      return (_currentIndex + 1) % queue.value.length;
    }
    final currentShuffledPos = _shuffledIndices.indexOf(_currentIndex);
    if (currentShuffledPos != -1 &&
        currentShuffledPos < _shuffledIndices.length - 1) {
      return _shuffledIndices[currentShuffledPos + 1];
    }
    return _shuffledIndices[0]; // Loop back
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

  @override
  Future<void> skipToNext() async {
    if (queue.value.isEmpty) return;
    _currentIndex = _getNextIndex();
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

    // Dispose the player
    await _player.dispose();
  }
}
