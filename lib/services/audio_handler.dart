// Ecilaes - Cross-platform music player
// Copyright (C) 2024  Anton Borri
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

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:home_widget/home_widget.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import '../signals/audio_signal.dart';
import '../signals/settings_signal.dart';
import '../signals/queue_signal.dart';
import 'YoutubeDatasource.dart';
import 'album_art_cache.dart';
import 'audio_cache_service.dart';
import 'playback_history_service.dart';
import 'youtube_service.dart';

/// A monotonically increasing token used to cancel in-flight load operations
/// when a newer selection supersedes them. Each call to [MyAudioHandler.playSong]
/// bumps the generation; any awaiting code compares its captured generation
/// against the latest one to decide whether to abort.
class _LoadToken {
  _LoadToken._(this.generation);
  factory _LoadToken(int generation) => _LoadToken._(generation);

  final int generation;
}

/// Exception thrown when an in-flight load operation is cancelled by a newer
/// selection or by [MyAudioHandler.dispose]. It is intentionally not logged —
/// cancellation is a normal control-flow event, not an error.
class _LoadCancelled implements Exception {
  const _LoadCancelled();
}

class MyAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();

  int _currentIndex = 0;
  AudioServiceShuffleMode _shuffleMode = AudioServiceShuffleMode.none;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;

  // Shuffle state. _shuffledIndices maps a "shuffle position" to a queue
  // index; the current song is always at shuffle-position 0.
  List<int> _shuffledIndices = [];
  final StreamController<List<int>> _shuffleIndicesController =
      StreamController<List<int>>.broadcast();
  Stream<List<int>> get shuffleIndicesStream => _shuffleIndicesController.stream;

  // Load generation — bumped on every new playSong/skipToNext. In-flight
  // loads capture this value and bail out if it changes before they finish.
  int _loadGeneration = 0;
  _LoadToken? _activeToken;

  bool _isDisposed = false;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  final AlbumArtCache _artCache = AlbumArtCache();

  // History tracking
  Timer? _historyTimer;
  bool _hasRecordedCurrent = false;
  String? _lastTrackId;
  final List<String> _sessionPlayedOrder = [];

  // Radio queue auto-fill guard
  bool _isFillingRadio = false;
  Timer? _radioFillDebounce;

  // Audio normalization
  bool _normalizationEnabled = false;
  double _normalizationTargetLufs = -14.0;
  final Map<String, double> _gainMap = {};

  MyAudioHandler() {
    _init();
  }

  // ---------------------------------------------------------------------------
  // Public surface
  // ---------------------------------------------------------------------------

  AudioPlayer get player => _player;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> _init() async {
    _normalizationEnabled = settingsSignal.audioNormalization.value;
    _normalizationTargetLufs = settingsSignal.normalizationTargetLufs.value;

    _subscriptions.add(_player.playerStateStream.listen(_onPlayerStateChanged));
    _subscriptions
        .add(_player.processingStateStream.listen(_onProcessingStateChanged));
    _subscriptions.add(_player.durationStream.listen(_onDurationChanged));
    _subscriptions.add(mediaItem.listen((item) {
      if (!_isDisposed && item != null) _updateWidget();
    }));
  }

  void _onPlayerStateChanged(PlayerState state) {
    if (_isDisposed) return;
    final playing = state.playing;

    playbackState.add(playbackState.value.copyWith(
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
      processingState: _mapProcessingState(state.processingState),
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _currentIndex,
      shuffleMode: _shuffleMode,
      repeatMode: _repeatMode,
    ));
    _updateWidget();
    _handleHistoryTracking(playing);
  }

  void _onProcessingStateChanged(ProcessingState state) {
    if (_isDisposed) return;
    if (state != ProcessingState.completed) return;

    if (_repeatMode == AudioServiceRepeatMode.one) {
      _player.seek(Duration.zero);
      _player.play();
    } else if (_repeatMode == AudioServiceRepeatMode.none && _isAtEnd) {
      stop();
    } else {
      skipToNext();
    }
  }

  void _onDurationChanged(Duration? duration) {
    if (_isDisposed || duration == null) return;
    final index = _currentIndex;
    if (index < 0 || index >= queue.value.length) return;

    final item = queue.value[index];
    if (item.duration == duration) return;

    final newItem = item.copyWith(duration: duration);
    final newQueue = List<MediaItem>.from(queue.value)..[index] = newItem;
    queue.add(newQueue);

    if (mediaItem.value?.id == item.id) {
      mediaItem.add(newItem);
    }
  }

  static AudioProcessingState _mapProcessingState(ProcessingState state) =>
      switch (state) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      };

  // ---------------------------------------------------------------------------
  // Queue management
  // ---------------------------------------------------------------------------

  Future<void> setPlaylist(List<Song> songs) async {
    await _artCache.init();

    _sessionPlayedOrder.clear();

    _gainMap
      ..clear()
      ..addEntries(songs
          .where((s) => s.gainDb != 0.0)
          .map((s) => MapEntry(s.path, s.gainDb)));

    final mediaItems = songs.map(_toMediaItem).toList(growable: false);

    queue.add(mediaItems);
    _currentIndex = 0;
    _shuffledIndices = const [];
    _syncQueueSignal();

    if (_shuffleMode == AudioServiceShuffleMode.all) {
      _generateShuffledIndices();
    } else {
      _shuffleIndicesController.add(const []);
    }
  }

  MediaItem _toMediaItem(Song song) {
    Uri? artUri;
    final cached = _artCache.getArtPathSync(song.path);
    if (cached != null) {
      artUri = Uri.file(cached);
    } else if (song.path.startsWith('yt:')) {
      artUri = Uri.parse(youtubeDatasource.getArtworkUrl(song.path.substring(3)));
    }

    return MediaItem(
      id: song.path,
      album: song.album ?? 'Unknown Album',
      title: song.title,
      artist: song.artist,
      duration: song.duration,
      artUri: artUri,
      extras: {'path': song.path, 'hasAlbumArt': song.hasAlbumArt},
    );
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final newQueue = [...queue.value, mediaItem];
    if (_shuffleMode == AudioServiceShuffleMode.all) {
      _shuffledIndices.add(newQueue.length - 1);
      _shuffleIndicesController.add(List<int>.from(_shuffledIndices));
    }
    queue.add(newQueue);
    _syncQueueSignal();
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    final id = mediaItem.id;
    final current = List<MediaItem>.from(queue.value);

    final indices =
        [for (var i = 0; i < current.length; i++) if (current[i].id == id) i];
    if (indices.isEmpty) return;

    for (final index in indices.reversed) {
      current.removeAt(index);

      if (_shuffledIndices.isNotEmpty) {
        _shuffledIndices.remove(index);
        for (var i = 0; i < _shuffledIndices.length; i++) {
          if (_shuffledIndices[i] > index) _shuffledIndices[i]--;
        }
      }

      if (index < _currentIndex) {
        _currentIndex--;
      } else if (index == _currentIndex && _currentIndex >= current.length) {
        _currentIndex = current.isEmpty ? 0 : current.length - 1;
      }
    }

    if (_shuffledIndices.isNotEmpty) {
      _shuffleIndicesController.add(List<int>.from(_shuffledIndices));
    }
    queue.add(current);
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    final current = List<MediaItem>.from(queue.value);
    final clamped = index.clamp(0, current.length);
    current.insert(clamped, mediaItem);

    if (_shuffledIndices.isNotEmpty) {
      for (var i = 0; i < _shuffledIndices.length; i++) {
        if (_shuffledIndices[i] >= clamped) _shuffledIndices[i]++;
      }
      final currentShuffledPos = _shuffledIndices.indexOf(_currentIndex);
      if (currentShuffledPos != -1) {
        _shuffledIndices.insert(currentShuffledPos + 1, clamped);
      } else {
        _shuffledIndices.add(clamped);
      }
      _shuffleIndicesController.add(List<int>.from(_shuffledIndices));
    }

    if (clamped <= _currentIndex) _currentIndex++;
    queue.add(current);
    _syncQueueSignal();
  }

  // ---------------------------------------------------------------------------
  // Shuffle / repeat
  // ---------------------------------------------------------------------------

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _shuffleMode = shuffleMode;
    if (shuffleMode == AudioServiceShuffleMode.all) {
      if (_shuffledIndices.isEmpty) {
        _generateShuffledIndices();
      }
    } else {
      if (_shuffledIndices.isNotEmpty) {
        _currentIndex = _shuffledIndices[_currentIndex];
      }
      _shuffledIndices = const [];
      _shuffleIndicesController.add(const []);
    }
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
    _syncQueueSignal();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  void _generateShuffledIndices() {
    final count = queue.value.length;
    if (count == 0) return;
    _shuffledIndices = List<int>.generate(count, (i) => i)..shuffle();
    _shuffledIndices.remove(_currentIndex);
    _shuffledIndices.insert(0, _currentIndex);
    _shuffleIndicesController.add(List<int>.from(_shuffledIndices));
  }

  int _getNextIndex() {
    final count = queue.value.length;
    if (count == 0) return 0;
    if (_repeatMode == AudioServiceRepeatMode.one) return _currentIndex;

    if (_shuffleMode == AudioServiceShuffleMode.none || _shuffledIndices.isEmpty) {
      final next = _currentIndex + 1;
      if (next < count) return next;
      return _repeatMode == AudioServiceRepeatMode.all ? 0 : _currentIndex;
    }

    final pos = _shuffledIndices.indexOf(_currentIndex);
    if (pos != -1 && pos < _shuffledIndices.length - 1) {
      return _shuffledIndices[pos + 1];
    }
    return _repeatMode == AudioServiceRepeatMode.all
        ? _shuffledIndices[0]
        : _currentIndex;
  }

  int _getPreviousIndex() {
    if (_shuffleMode == AudioServiceShuffleMode.none || _shuffledIndices.isEmpty) {
      final len = queue.value.length;
      return len == 0 ? 0 : (_currentIndex - 1 + len) % len;
    }
    final pos = _shuffledIndices.indexOf(_currentIndex);
    if (pos > 0) return _shuffledIndices[pos - 1];
    return _shuffledIndices.last;
  }

  bool get _isAtEnd {
    final count = queue.value.length;
    if (count == 0) return true;
    if (_shuffledIndices.isNotEmpty) {
      return _currentIndex == _shuffledIndices.length - 1;
    }
    return _currentIndex == count - 1;
  }

  // ---------------------------------------------------------------------------
  // Transport controls
  // ---------------------------------------------------------------------------

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
  Future<void> skipToNext() async {
    if (queue.value.isEmpty) return;
    if (_repeatMode == AudioServiceRepeatMode.none && _isAtEnd) {
      _currentIndex = _shuffleMode == AudioServiceShuffleMode.all &&
              _shuffledIndices.isNotEmpty
          ? _shuffledIndices[0]
          : 0;
    } else {
      _currentIndex = _getNextIndex();
    }
    await _playCurrent();
    _syncQueueSignal();
  }

  @override
  Future<void> skipToPrevious() async {
    if (queue.value.isEmpty) return;
    _currentIndex = _getPreviousIndex();
    await _playCurrent();
    _syncQueueSignal();
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    final index = queue.value.indexWhere((item) => item.id == mediaItem.id);
    if (index == -1) return;
    _currentIndex = index;
    await _playCurrent();
    _syncQueueSignal();
  }

  /// Play a specific song. If [song.path] is already in the queue, jumps to
  /// that position; otherwise no-op (the caller is expected to call
  /// [setPlaylist] first to establish the queue context).
  Future<void> playSong(Song song) async {
    final index = queue.value.indexWhere((item) => item.id == song.path);
    if (index == -1) return;
    _currentIndex = index;
    await _playCurrent();
    _syncQueueSignal();
  }

  /// Update the tracked queue index without triggering playback.
  /// Used after a queue reorder to keep the now-playing song at the right
  /// index. Does NOT call `_syncQueueSignal` — the UI signal was already
  /// updated by the reorder.
  void updateQueueIndex(int newIndex) {
    _currentIndex = newIndex;
    _updateWidget();
  }

  // ---------------------------------------------------------------------------
  // Normalization
  // ---------------------------------------------------------------------------

  void setNormalizationEnabled(bool enabled) {
    _normalizationEnabled = enabled;
    final current = mediaItem.value;
    if (current != null) _applyNormalization(current.id);
  }

  void setNormalizationTargetLufs(double lufs) {
    _normalizationTargetLufs = lufs;
    if (_normalizationEnabled) {
      final current = mediaItem.value;
      if (current != null) _applyNormalization(current.id);
    }
  }

  void setGainMap(Map<String, double> gainMap) {
    _gainMap
      ..clear()
      ..addAll(gainMap);
  }

  void updateGain(String path, double gainDb) {
    _gainMap[path] = gainDb;
  }

  void _applyNormalization(String trackId) {
    if (!_normalizationEnabled) {
      _player.setVolume(1.0);
      return;
    }
    final gainDb = _gainMap[trackId] ?? 0.0;
    final adjusted = gainDb + (_normalizationTargetLufs + 14.0);
    final volume = pow(10.0, adjusted / 20.0).clamp(0.1, 2.0).toDouble();
    _player.setVolume(volume);
  }

  // ---------------------------------------------------------------------------
  // Queue signal bridge
  // ---------------------------------------------------------------------------

  void _syncQueueSignal() {
    if (_currentIndex < 0 || queue.value.isEmpty) {
      queueSignal.updateFromQueueAndHistory(
        upNext: const [],
        history: _sessionPlayedOrder.toList(growable: false),
      );
      return;
    }

    final List<String> upNextPaths;
    if (_shuffledIndices.isNotEmpty) {
      if (_currentIndex < _shuffledIndices.length - 1) {
        upNextPaths = _shuffledIndices
            .sublist(_currentIndex + 1)
            .map((idx) => queue.value[idx].id)
            .toList();
      } else {
        upNextPaths = const [];
      }
    } else {
      upNextPaths = _currentIndex < queue.value.length - 1
          ? queue.value
              .sublist(_currentIndex + 1)
              .map((i) => i.id)
              .toList()
          : const [];
    }

    queueSignal.updateFromQueueAndHistory(
      upNext: upNextPaths,
      history: _sessionPlayedOrder.toList(growable: false),
    );

    _scheduleRadioFill();
  }

  void _scheduleRadioFill() {
    if (!audioSignal.isRadioMode.value) return;
    if (mediaItem.value == null) return;
    final remaining = queue.value.length - _currentIndex - 1;
    if (remaining > 3) return;
    // Debounce so a burst of queue updates doesn't trigger multiple fills.
    _radioFillDebounce?.cancel();
    _radioFillDebounce = Timer(const Duration(milliseconds: 250), _fillRadioQueue);
  }

  Future<void> _fillRadioQueue() async {
    if (_isFillingRadio || _isDisposed) return;
    final current = mediaItem.value;
    if (current == null || !current.id.startsWith('yt:')) return;

    _isFillingRadio = true;
    try {
      final videoId = current.id.substring(3);
      final songs = await youtubeDatasource.getRadioSongs(videoId);
      if (_isDisposed) return;
      audioSignal.cacheRadioSongs(songs);
      for (final song in songs) {
        if (_isDisposed) return;
        final songVideoId =
            song.path.startsWith('yt:') ? song.path.substring(3) : '';
        final artUri =
            Uri.parse(youtubeDatasource.getArtworkUrl(songVideoId));
        await addQueueItem(MediaItem(
          id: song.path,
          album: song.album ?? 'YouTube Music',
          title: song.title,
          artist: song.artist,
          duration: song.duration,
          artUri: artUri,
          extras: {'path': song.path, 'hasAlbumArt': song.hasAlbumArt},
        ));
      }
    } finally {
      _isFillingRadio = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Playback orchestration
  // ---------------------------------------------------------------------------

  /// Orchestrates a single "play the current item" cycle. Safe to call
  /// concurrently — each call is serialized via [_activeToken] and any
  /// superseded call bails out at the next await boundary.
  Future<void> _playCurrent() async {
    if (_isDisposed || queue.value.isEmpty) return;

    // Pause the underlying player immediately so the previous track doesn't
    // keep playing while we resolve a new source.
    if (_player.playing) await _player.pause();

    final token = _LoadToken(++_loadGeneration);
    _activeToken = token;

    var item = queue.value[_currentIndex];

    // History bookkeeping for the new track.
    _sessionPlayedOrder
      ..remove(item.id)
      ..insert(0, item.id);

    try {
      item = await _resolveArt(item, token);
      _throwIfCancelled(token);

      // Publish metadata early so the UI updates with the new selection.
      // Cancellation past this point is fine: a newer load will overwrite
      // mediaItem with its own item.
      mediaItem.add(item);
      _applyNormalization(item.id);

      final source = await _resolveSource(item, token);
      _throwIfCancelled(token);

      await _player.setAudioSource(source);
      _throwIfCancelled(token);

      await _player.play();
    } on _LoadCancelled {
      // Normal control flow; no logging.
    } on PlayerInterruptedException {
      // Already handled by the player; no-op.
    } catch (e) {
      if (e.toString().contains('Loading interrupted')) return;
      // Only surface errors for the still-active load.
      if (_activeToken == token) {
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
        ));
      }
    } finally {
      // Pre-cache the next track only if this load is still the active one.
      if (_activeToken == token &&
          !_isDisposed &&
          settingsSignal.enablePreCaching.value) {
        _preCacheNext();
      }
    }
  }

  /// Throws [_LoadCancelled] if [token] has been superseded by a newer load
  /// or the handler has been disposed.
  void _throwIfCancelled(_LoadToken token) {
    if (_isDisposed || token != _activeToken) throw const _LoadCancelled();
  }

  /// Resolves the art URI for [item], mutating and returning a copy with the
  /// art URI set. Yields (does not cancel) if [token] becomes stale — the
  /// next code path will throw.
  Future<MediaItem> _resolveArt(MediaItem item, _LoadToken token) async {
    if (!item.id.startsWith('yt:') &&
        item.artUri == null &&
        item.extras?['hasAlbumArt'] == true) {
      final uri = await _artCache.getArtUri(item.id);
      if (token != _activeToken || _isDisposed) return item;
      if (uri == null) return item;
      final updated = item.copyWith(artUri: uri);
      final newQueue = List<MediaItem>.from(queue.value)
        ..[_currentIndex] = updated;
      queue.add(newQueue);
      return updated;
    }

    if (item.id.startsWith('yt:')) {
      final videoId = item.id.substring(3);
      final cached = _artCache.getArtPathSync(item.id);
      if (cached != null) return item.copyWith(artUri: Uri.file(cached));

      final thumb = Uri.parse(youtubeDatasource.getArtworkUrl(videoId));
      _artCache.getArt(item.id); // background download
      return item.copyWith(artUri: thumb);
    }

    return item;
  }

  /// Resolves the audio source for [item] (file, cache, or network stream).
  /// Throws [_LoadCancelled] on supersession.
  Future<AudioSource> _resolveSource(MediaItem item, _LoadToken token) async {
    if (item.id.startsWith('yt:')) {
      final videoId = item.id.substring(3);
      final cached = audioCacheService.getCachedPath(videoId);
      if (cached != null) {
        _throwIfCancelled(token);
        return AudioSource.file(cached, tag: item);
      }
      final url = await youtubeService.getAudioStreamUrl(videoId);
      _throwIfCancelled(token);
      if (url == null) throw Exception('Could not resolve YouTube stream');

      if (settingsSignal.enableStreamCaching.value) {
        unawaited(audioCacheService.cacheStream(videoId, streamUrl: url));
      }
      return AudioSource.uri(
        Uri.parse(url),
        tag: item,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      );
    }
    return AudioSource.uri(Uri.file(item.id), tag: item);
  }

  void _preCacheNext() {
    if (_isDisposed || queue.value.isEmpty) return;

    final nextIndex = _getNextIndex();
    if (nextIndex == _currentIndex) return;

    final next = queue.value[nextIndex];
    if (!next.id.startsWith('yt:')) return;

    final videoId = next.id.substring(3);
    if (audioCacheService.getCachedPath(videoId) != null) return;
    if (audioCacheService.isCaching(videoId)) return;
    audioCacheService.cacheStream(videoId);
  }

  // ---------------------------------------------------------------------------
  // History tracking
  // ---------------------------------------------------------------------------

  void _handleHistoryTracking(bool isPlaying) {
    final currentId = mediaItem.value?.id;

    if (currentId != _lastTrackId) {
      _historyTimer?.cancel();
      _historyTimer = null;
      _hasRecordedCurrent = false;
      _lastTrackId = currentId;
    }

    if (isPlaying &&
        !_hasRecordedCurrent &&
        currentId != null &&
        !currentId.startsWith('yt:')) {
      _historyTimer ??= Timer(const Duration(seconds: 40), () async {
        if (mediaItem.value?.id == currentId && !_hasRecordedCurrent) {
          _hasRecordedCurrent = true;
          await PlaybackHistoryService.recordPlay(currentId);
          if (!_isDisposed) await audioSignal.refreshHistory();
        }
      });
    } else if (!isPlaying) {
      if (!_hasRecordedCurrent && _historyTimer != null) {
        _historyTimer?.cancel();
        _historyTimer = null;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Android home-screen widget
  // ---------------------------------------------------------------------------

  Future<void> _updateWidget() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final item = mediaItem.value;
    final isPlaying = playbackState.value.playing;
    final isIdle =
        playbackState.value.processingState == AudioProcessingState.idle;

    if (item == null || isIdle) {
      await HomeWidget.saveWidgetData<String>('title', 'Not Playing');
      await HomeWidget.saveWidgetData<String>('artist', '-');
      await HomeWidget.saveWidgetData<bool>('isPlaying', false);
      await HomeWidget.saveWidgetData<String?>('artPath', null);
    } else {
      await HomeWidget.saveWidgetData<String>('title', item.title);
      await HomeWidget.saveWidgetData<String>('artist', item.artist ?? '-');
      await HomeWidget.saveWidgetData<bool>('isPlaying', isPlaying);

      String? artPath;
      final artUri = item.artUri;
      if (artUri != null && artUri.isScheme('file')) {
        artPath = artUri.toFilePath();
      }
      await HomeWidget.saveWidgetData<String?>('artPath', artPath);
    }

    await HomeWidget.updateWidget(
      name: 'MusicWidgetProvider',
      androidName: 'MusicWidgetProvider',
    );
  }

  // ---------------------------------------------------------------------------
  // Disposal
  // ---------------------------------------------------------------------------

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    // Bump generation so any in-flight load throws _LoadCancelled on its
    // next check.
    _loadGeneration++;
    _activeToken = null;

    _radioFillDebounce?.cancel();
    _historyTimer?.cancel();

    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    await _shuffleIndicesController.close();
    await _player.dispose();
  }
}
