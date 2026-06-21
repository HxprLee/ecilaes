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
import 'package:audio_service/audio_service.dart';
import 'package:signals/signals.dart';
import '../models/queue_model.dart';
import '../models/song.dart';
import '../services/queue_service.dart';
import 'audio_signal.dart';

class QueueSignal {
  static final QueueSignal _instance = QueueSignal._internal();
  factory QueueSignal() => _instance;
  QueueSignal._internal();

  final QueueService _service = QueueService();

  final upNext = listSignal<String>([]);
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
    upNext.value = model.upNext;
    history.value = model.history;
  }

  int get upNextCount => upNext.value.length;
  int get historyCount => history.value.length;
  bool get isEmpty => upNext.value.isEmpty;

  Future<void> playNext(Song song) async {
    await _service.playNext(song.path);
    upNext.value = [song.path, ...upNext.value];
  }

  Future<void> addToQueue(Song song) async {
    await _service.addToQueue(song.path);
    upNext.value = [...upNext.value, song.path];
  }

  Future<void> reorderUpNext(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final paths = List<String>.from(upNext.value);
    if (oldIndex < 0 || oldIndex >= paths.length) return;
    if (newIndex < 0 || newIndex > paths.length) return;

    final item = paths.removeAt(oldIndex);
    final adjustedNew = newIndex > oldIndex ? newIndex - 1 : newIndex;
    paths.insert(adjustedNew, item);

    // Build the full queue path list: items before current song + current song + reordered upNext
    final currentPath = audioSignal.currentSong.value?.path;
    final handlerQueue = audioSignal.queue.value;
    final currentQueueIndex = currentPath != null
        ? handlerQueue.indexWhere((item) => item.id == currentPath)
        : -1;

    List<String> fullOrderedPaths;
    if (currentQueueIndex >= 0) {
      fullOrderedPaths = [
        ...handlerQueue.sublist(0, currentQueueIndex).map((i) => i.id),
        currentPath!,
        ...paths,
      ];
    } else {
      fullOrderedPaths = [...paths];
    }

    await _service.reorderUpNext(oldIndex, newIndex);
    upNext.value = paths;
    audioSignal.reorderQueueFromPaths(
      fullOrderedPaths,
      currentQueueIndex >= 0 ? currentQueueIndex : 0,
    );
  }

  Future<void> moveToTop(String songPath) async {
    await _service.moveToTop(songPath);
    final paths = List<String>.from(upNext.value);
    paths.remove(songPath);
    paths.insert(0, songPath);
    upNext.value = paths;
  }

  Future<void> removeFromUpNext(String songPath) async {
    await _service.removeFromUpNext(songPath);
    upNext.value = upNext.value.where((p) => p != songPath).toList();
  }

  Future<void> clearUpNext() async {
    await _service.clearUpNext();
    upNext.value = [];
  }

  Future<void> clearHistory() async {
    await _service.clearHistory();
    history.value = [];
  }

  Future<void> clearAll() async {
    await _service.clearAll();
    upNext.value = [];
    history.value = [];
  }

  Future<void> requeueFromHistory(String songPath) async {
    await _service.requeueFromHistory(songPath);
    history.value = history.value.where((p) => p != songPath).toList();
    upNext.value = [songPath, ...upNext.value];
  }

  Future<void> playHistoryItem(String songPath) async {
    await _service.playHistoryItem(songPath);
    history.value = history.value.where((p) => p != songPath).toList();
    upNext.value = [songPath, ...upNext.value];
  }

  void updateFromPlayback({
    required List<MediaItem> playbackQueue,
    required int currentIndex,
  }) {
    _service.updateFromPlayback(
      playbackQueue: playbackQueue,
      currentIndex: currentIndex,
    );
  }

  void updateFromQueueAndHistory({
    required List<String> upNext,
    required List<String> history,
  }) {
    _service.updateFromQueueAndHistory(upNext: upNext, history: history);
  }

  void dispose() {
    _subscription?.cancel();
    _service.dispose();
  }
}

final queueSignal = QueueSignal();
