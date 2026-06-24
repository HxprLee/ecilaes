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

import 'dart:async';
import 'package:signals/signals_flutter.dart';
import '../models/queue_model.dart';
import '../models/song.dart';
import '../services/queue_service.dart';
import 'audio_signal.dart';

/// Single source of truth for the playback queue.
///
/// Owns the path-based queue (local + YouTube mixed), the current song
/// index, the shuffle order, and the history. Persists to disk via
/// [QueueService]. [MyAudioHandler] remains the only place that knows
/// about `MediaItem`s — this signal speaks paths.
class QueueSignal {
  static final QueueSignal _instance = QueueSignal._internal();
  factory QueueSignal() => _instance;
  QueueSignal._internal();

  final QueueService _service = QueueService();

  /// Full ordered playback list, current song at [currentIndex].
  final playbackOrder = listSignal<String>([]);

  /// Index of the currently playing song within [playbackOrder]. -1 when
  /// the queue is empty.
  final currentIndex = signal<int>(-1);

  /// Played songs, newest first. Capped on insert.
  final history = listSignal<String>([]);

  StreamSubscription? _subscription;

  Future<void> init() async {
    await _service.load();
    _syncFromModel(_service.model);

    _subscription = _service.stream.listen((model) {
      _syncFromModel(model);
    });
  }

  void _syncFromModel(QueueModel model) {
    playbackOrder.value = List<String>.from(model.playbackOrder);
    currentIndex.value = model.currentIndex;
    history.value = List<String>.from(model.history);
  }

  void _commit({List<String>? order, int? index, List<String>? hist}) {
    final model = _service.model.copyWith(
      playbackOrder: order,
      currentIndex: index,
      history: hist,
    );
    _service.replace(model);
  }

  int get upNextCount {
    final i = currentIndex.value;
    final n = playbackOrder.value.length;
    if (i < 0 || i >= n - 1) return 0;
    return n - i - 1;
  }

  int get historyCount => history.value.length;
  bool get isEmpty => playbackOrder.value.isEmpty;
  String? get currentPath {
    final i = currentIndex.value;
    if (i < 0 || i >= playbackOrder.value.length) return null;
    return playbackOrder.value[i];
  }

  /// The list of songs that will play after the current one.
  List<String> get upNextPaths {
    final i = currentIndex.value;
    final order = playbackOrder.value;
    if (i < 0 || i >= order.length - 1) return const [];
    return order.sublist(i + 1);
  }

  /// Replace the entire queue. If [playPath] is non-null, playback jumps
  /// to that song; otherwise it starts at index 0.
  ///
  /// Resets shuffle order when not in shuffle mode.
  void setPlaylist(List<String> paths, {String? playPath}) {
    final order = List<String>.from(paths);
    int index = -1;
    if (playPath != null) {
      index = order.indexOf(playPath);
    }
    if (index < 0 && order.isNotEmpty) index = 0;
    final newHistory = <String>[];
    if (index >= 0 && index < order.length) {
      newHistory.add(order[index]);
    }
    _commit(order: order, index: index, hist: newHistory);
  }

  /// Play a single song. Replaces the queue with [fromList] (or just the
  /// song if no list is provided) and jumps to [song.path].
  void playNow(Song song, {List<Song>? fromList}) {
    final paths = (fromList ?? [song]).map((s) => s.path).toList();
    setPlaylist(paths, playPath: song.path);
  }

  /// Insert [song] right after the current song (or at the top if the
  /// queue is empty).
  void playNext(Song song) {
    final path = song.path;
    final order = List<String>.from(playbackOrder.value);
    order.remove(path);
    final i = currentIndex.value;
    if (i < 0) {
      order.add(path);
      _commit(order: order, index: 0, hist: [path]);
    } else {
      order.insert(i + 1, path);
      _commit(order: order);
    }
  }

  /// Append [song] to the end of the queue.
  void addToQueue(Song song) {
    final path = song.path;
    final order = List<String>.from(playbackOrder.value);
    if (!order.contains(path)) {
      order.add(path);
      _commit(order: order);
    }
  }

  /// Remove the song at [index] in [playbackOrder]. Adjusts [currentIndex]
  /// so it still points to the same song (or to the previous one when the
  /// current song itself was removed).
  void removeAt(int index) {
    if (index < 0 || index >= playbackOrder.value.length) return;
    final order = List<String>.from(playbackOrder.value);
    order.removeAt(index);
    int newCurrent = currentIndex.value;
    if (index < newCurrent) {
      newCurrent--;
    } else if (index == newCurrent) {
      newCurrent = order.isEmpty ? -1 : (newCurrent >= order.length ? order.length - 1 : newCurrent);
    }
    _commit(order: order, index: newCurrent);
  }

  /// Reorder a song within the upNext section. [oldIndex] and [newIndex]
  /// are positions in [upNextPaths], not in [playbackOrder].
  void reorderUpNext(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final upNext = List<String>.from(upNextPaths);
    if (oldIndex < 0 || oldIndex >= upNext.length) return;
    if (newIndex < 0 || newIndex > upNext.length) return;

    final item = upNext.removeAt(oldIndex);
    final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
    upNext.insert(adjusted, item);

    final i = currentIndex.value;
    final prefix = i >= 0 && i < playbackOrder.value.length
        ? playbackOrder.value.sublist(0, i + 1)
        : <String>[];
    _commit(order: [...prefix, ...upNext]);
  }

  /// Move [songPath] to the very top of upNext. No-op if it's not in
  /// upNext already.
  void moveToTop(String songPath) {
    final upNext = List<String>.from(upNextPaths);
    if (!upNext.remove(songPath)) return;
    upNext.insert(0, songPath);

    final i = currentIndex.value;
    final prefix = i >= 0 && i < playbackOrder.value.length
        ? playbackOrder.value.sublist(0, i + 1)
        : <String>[];
    _commit(order: [...prefix, ...upNext]);
  }

  /// Remove a song from upNext by path.
  void removeFromUpNext(String songPath) {
    final upNext = upNextPaths.where((p) => p != songPath).toList();
    final i = currentIndex.value;
    final prefix = i >= 0 && i < playbackOrder.value.length
        ? playbackOrder.value.sublist(0, i + 1)
        : <String>[];
    _commit(order: [...prefix, ...upNext]);
  }

  /// Remove a song from history by path.
  void removeFromHistory(String songPath) {
    final hist = history.value.where((p) => p != songPath).toList();
    _commit(hist: hist);
  }

  /// Move [songPath] from history back into upNext. Returns the song so
  /// the caller can start playback.
  Song? playFromHistory(String songPath) {
    final song = resolveSong(songPath);
    playNext(song);
    removeFromHistory(songPath);
    return song;
  }

  /// Skip the player to [index] in [playbackOrder]. Updates the current
  /// index and prepends the song to history.
  void skipTo(int index) {
    final order = playbackOrder.value;
    if (index < 0 || index >= order.length) return;
    final newHist = <String>[order[index]];
    _commit(index: index, hist: newHist);
  }

  /// Skip forward by one (wraps via repeat mode in the handler). No-op
  /// at the end of the queue unless repeat-all is set.
  void skipNext() {
    final order = playbackOrder.value;
    final i = currentIndex.value;
    if (i < 0 || order.isEmpty) return;
    if (i >= order.length - 1) return;
    skipTo(i + 1);
  }

  /// Skip backward by one. No-op at the start of the queue.
  void skipPrevious() {
    final i = currentIndex.value;
    if (i <= 0) return;
    skipTo(i - 1);
  }

  void clearUpNext() {
    final i = currentIndex.value;
    final order = playbackOrder.value;
    final prefix = i >= 0 && i < order.length ? order.sublist(0, i + 1) : <String>[];
    _commit(order: prefix);
  }

  void clearHistory() {
    _commit(hist: const []);
  }

  void clearAll() {
    _commit(order: const [], index: -1, hist: const []);
  }

  /// Mirror the handler's canonical state (full ordered path list + the
  /// index of the currently playing song) into the signal. History is
  /// updated to contain exactly the current song.
  ///
  /// This is called by [MyAudioHandler] after every queue mutation so
  /// that the signal stays a faithful projection of the handler's state
  /// without the signal having to know about `MediaItem`s.
  void syncFromHandler({
    required List<String> playbackOrder,
    required int currentIndex,
  }) {
    this.playbackOrder.value = List<String>.from(playbackOrder);
    this.currentIndex.value = currentIndex;
    if (currentIndex >= 0 && currentIndex < playbackOrder.length) {
      final currentPath = playbackOrder[currentIndex];
      final newHist = <String>[currentPath];
      // Preserve any history entries that come before this song in the
      // handler's view (i.e. songs already played in this session).
      final existing = history.value;
      newHist.addAll(existing.where((p) => p != currentPath));
      history.value = newHist;
    } else {
      history.value = <String>[];
    }
  }

  /// Resolve a path to a [Song] using the in-memory caches owned by
  /// [AudioSignal]. This is a thin convenience wrapper so the queue UI
  /// does not have to import [AudioSignal] directly.
  Song resolveSong(String path) => audioSignal.resolveSong(path);

  void dispose() {
    _subscription?.cancel();
    _service.dispose();
  }
}

final queueSignal = QueueSignal();
