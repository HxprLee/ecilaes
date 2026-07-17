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

import 'dart:math';
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
///
/// ## Shuffle
/// When [isShuffleEnabled] is true, [shuffleOrder] is a permutation of
/// indices into [playbackOrder] and the active play sequence is
/// `playbackOrder[shuffleOrder[i]]`. [currentIndex] indexes into the
/// shuffle order, not the underlying [playbackOrder]. When shuffle is
/// off, the active play sequence is the literal [playbackOrder].
class QueueSignal {
  static final QueueSignal _instance = QueueSignal._internal();
  factory QueueSignal() => _instance;
  QueueSignal._internal();

  final QueueService _service = QueueService();

  /// Direct access to the underlying service. Use with care — prefer signal
  /// methods when available.
  QueueService get service => _service;

  /// Full ordered playback list. The canonical, unshuffled queue.
  final playbackOrder = listSignal<String>([]);

  /// Index of the currently playing song.
  ///
  /// When [isShuffleEnabled] is true, this indexes into [shuffleOrder].
  /// When false, it indexes into [playbackOrder]. -1 when the queue is
  /// empty.
  final currentIndex = signal<int>(-1);

  /// Played songs, newest first. Capped on insert to [historyLimit].
  final history = listSignal<String>([]);

  /// Whether shuffle is currently enabled. When true, [shuffleOrder] is
  /// the active play sequence.
  final isShuffleEnabled = signal<bool>(false);

  /// Permutation of indices into [playbackOrder]. Empty when shuffle is
  /// off or the queue is empty.
  final shuffleOrder = listSignal<int>([]);

  /// Maximum number of history entries to retain. Oldest entries are dropped
  /// when the list grows past this threshold.
  static const int historyLimit = 500;

  final Random _rng = Random();

  Future<void> init() async {
    await _service.load();
    _syncFromModel(_service.model);

    _service.stream.listen((model) {
      _syncFromModel(model);
    });
  }

  void _syncFromModel(QueueModel model) {
    playbackOrder.value = List<String>.from(model.playbackOrder);
    currentIndex.value = model.currentIndex;
    history.value = List<String>.from(model.history);
    isShuffleEnabled.value = model.isShuffleEnabled;
    shuffleOrder.value = List<int>.from(model.shuffleOrder);
  }

  void _commit({
    List<String>? order,
    int? index,
    List<String>? hist,
    String? radioSeed,
    List<String>? recentRadioSeeds,
    bool? isShuffleEnabled,
    List<int>? shuffleOrder,
  }) {
    final model = _service.model.copyWith(
      playbackOrder: order,
      currentIndex: index,
      history: hist,
      radioSeed: radioSeed,
      recentRadioSeeds: recentRadioSeeds,
      isShuffleEnabled: isShuffleEnabled,
      shuffleOrder: shuffleOrder,
    );
    // Update signals synchronously so callers (e.g. AudioSignal.toggleShuffle)
    // see the new state immediately. The broadcast stream still fires for
    // any other subscribers and for persistence.
    _syncFromModel(model);
    _service.replace(model);
  }

  int get upNextCount {
    final i = currentIndex.value;
    final n = activeLength;
    if (i < 0 || i >= n - 1) return 0;
    return n - i - 1;
  }

  int get historyCount => history.value.length;
  bool get isEmpty => playbackOrder.value.isEmpty;
  String? get currentPath {
    final i = currentIndex.value;
    if (i < 0) return null;
    if (isShuffleEnabled.value) {
      final order = shuffleOrder.value;
      if (i >= order.length) return null;
      final idx = order[i];
      final play = playbackOrder.value;
      if (idx < 0 || idx >= play.length) return null;
      return play[idx];
    }
    final play = playbackOrder.value;
    if (i >= play.length) return null;
    return play[i];
  }

  /// Length of the active play sequence (shuffled or sequential).
  int get activeLength =>
      isShuffleEnabled.value ? shuffleOrder.value.length : playbackOrder.value.length;

  /// The list of paths that will play after the current one, in active
  /// play order.
  List<String> get upNextPaths {
    final i = currentIndex.value;
    final n = activeLength;
    if (i < 0 || i >= n - 1) return const [];
    final play = playbackOrder.value;
    if (isShuffleEnabled.value) {
      final order = shuffleOrder.value;
      return [for (int k = i + 1; k < order.length; k++) play[order[k]]];
    }
    return play.sublist(i + 1);
  }

  /// The path at a given active sequence index. Returns null if out of
  /// range.
  String? pathAtActiveIndex(int index) {
    if (index < 0 || index >= activeLength) return null;
    final play = playbackOrder.value;
    if (isShuffleEnabled.value) {
      final idx = shuffleOrder.value[index];
      if (idx < 0 || idx >= play.length) return null;
      return play[idx];
    }
    if (index >= play.length) return null;
    return play[index];
  }

  /// Replace the entire queue. If [playPath] is non-null, playback jumps
  /// to that song; otherwise it starts at index 0.
  ///
  /// Resets shuffle order when not in shuffle mode. When shuffle is
  /// enabled, the order is freshly shuffled (a new permutation is built).
  ///
  /// History is preserved — the canonical played-history list is updated
  /// only when the handler actually changes the playing song
  /// (see [MyAudioHandler._recordHistory]). Mutators on the queue itself
  /// must not touch history; doing so overwrites the user's previous
  /// session every time the queue is replaced.
  void setPlaylist(List<String> paths, {String? playPath}) {
    final order = List<String>.from(paths);
    int index = -1;
    if (playPath != null) {
      index = order.indexOf(playPath);
    }
    if (index < 0 && order.isNotEmpty) index = 0;

    // Preserve any existing radio songs (paths not in the new list) already in
    // the canonical queue — radio fills add them to the handler queue, and
    // setPlaylist is called next by playSong/handler.setPlaylist which would
    // otherwise wipe them. Radio songs are appended to the end so they play
    // after the user's selected content.
    final existingOrder = playbackOrder.value;
    final pathSet = paths.toSet();
    final radioSongs = existingOrder.where((p) => !pathSet.contains(p)).toList();
    final newOrder = [...order, ...radioSongs];
    final newIndex = index < 0 ? -1 : index;

    if (isShuffleEnabled.value && newOrder.isNotEmpty) {
      final perm = _buildFreshPermutation(newOrder.length, preserve: newIndex + 1);
      final newShuffleOrder = [for (int p = 0; p < perm.length; p++) perm[p]];
      _commit(
        order: newOrder,
        index: newIndex,
        shuffleOrder: newShuffleOrder,
      );
    } else {
      _commit(order: newOrder, index: newIndex, shuffleOrder: const []);
    }
  }

  /// Replace the queue with a freshly shuffled copy of [paths]. If
  /// [playPath] is provided, the play sequence starts with that song
  /// (it is placed at shuffle-position 0); otherwise a random song
  /// starts.
  ///
  /// Implicitly enables shuffle so the new permutation is honored on
  /// subsequent skips.
  ///
  /// History is preserved — see [setPlaylist] for the rationale.
  void shuffleFrom(List<String> paths, {String? playPath}) {
    final order = List<String>.from(paths);
    if (order.isEmpty) {
      _commit(
        order: const [],
        index: -1,
        isShuffleEnabled: true,
        shuffleOrder: const [],
      );
      return;
    }
    int startIndex = 0;
    if (playPath != null) {
      final found = order.indexOf(playPath);
      if (found >= 0) startIndex = found;
    }

    // Preserve any existing radio songs (paths not in the new list) already in
    // the canonical queue — they should play AFTER the user's selected
    // content, so append to the end.
    final existingOrder = playbackOrder.value;
    final pathSet = paths.toSet();
    final radioSongs = existingOrder.where((p) => !pathSet.contains(p)).toList();
    final newOrder = [...order, ...radioSongs];

    final perm = _buildFreshPermutation(newOrder.length, preserve: startIndex + 1);
    _commit(
      order: newOrder,
      index: 0,
      isShuffleEnabled: true,
      shuffleOrder: perm,
    );
  }

  /// Insert [song] right after the current song (or at the top if the
  /// queue is empty).
  ///
  /// History is preserved — see [setPlaylist] for the rationale.
  void playNext(Song song) {
    final path = song.path;
    final order = List<String>.from(playbackOrder.value);
    order.remove(path);
    final i = currentIndex.value;
    int newIndex;
    List<int>? newShuffle;
    if (i < 0) {
      order.add(path);
      newIndex = 0;
      // Recompute shuffle with the new song as part of the to-play tail.
      if (isShuffleEnabled.value) {
        newShuffle = _buildFreshPermutation(order.length, preserve: 1);
      }
    } else {
      order.insert(i + 1, path);
      newIndex = i;
      if (isShuffleEnabled.value) {
        // The newly inserted path is at order[i + 1]; existing shuffleOrder
        // entries > i still reference valid indices (insertion shifts the
        // unplayed tail but our shuffleOrder only stores indices, so we
        // need to bump indices >= i+1).
        final perm = List<int>.from(shuffleOrder.value);
        for (int k = 0; k < perm.length; k++) {
          if (perm[k] >= i + 1) perm[k] = perm[k] + 1;
        }
        // The new song isn't in the active sequence yet; for the user it
        // should appear as "next" — append at the end of the unplayed
        // tail. Insert just after current position.
        final currentShufflePos = currentIndex.value;
        perm.insert(currentShufflePos + 1, i + 1);
        newShuffle = perm;
      }
    }
    _commit(
      order: order,
      index: newIndex,
      shuffleOrder: newShuffle,
    );
  }

  /// Append [song] to the end of the queue.
  void addToQueue(Song song) {
    final path = song.path;
    final order = List<String>.from(playbackOrder.value);
    if (order.contains(path)) return;
    order.add(path);
    List<int>? newShuffle;
    if (isShuffleEnabled.value) {
      final perm = List<int>.from(shuffleOrder.value);
      // Append the new index at the end of the unplayed tail so it
      // becomes "last in the shuffled sequence".
      perm.add(order.length - 1);
      newShuffle = perm;
    }
    _commit(order: order, shuffleOrder: newShuffle);
  }

  /// Remove the song at [index] in [playbackOrder]. Adjusts [currentIndex]
  /// so it still points to the same song (or to the previous one when the
  /// current song itself was removed).
  void removeAt(int index) {
    if (index < 0 || index >= playbackOrder.value.length) return;
    final order = List<String>.from(playbackOrder.value);
    order.removeAt(index);
    int newCurrent = currentIndex.value;
    List<int>? newShuffle;
    if (isShuffleEnabled.value) {
      final perm = List<int>.from(shuffleOrder.value);
      // Remove every entry in the permutation that referenced [index],
      // and decrement entries that referenced indices > index.
      perm.removeWhere((i) => i == index);
      for (int k = 0; k < perm.length; k++) {
        if (perm[k] > index) perm[k] = perm[k] - 1;
      }
      // If we removed the currently playing playbackOrder entry, also
      // remove its shuffle position so currentIndex keeps pointing at the
      // next thing to play (or moves back if nothing was after it).
      if (index == newCurrent) {
        // currentIndex points to the position in shuffleOrder. The song
        // we removed was at that position. Drop the entry.
        if (currentIndex.value >= 0 && currentIndex.value < perm.length) {
          perm.removeAt(currentIndex.value);
        } else if (perm.isNotEmpty) {
          newCurrent = perm.length - 1;
        } else {
          newCurrent = -1;
        }
      } else if (index < newCurrent) {
        newCurrent = newCurrent - 1;
      }
      newShuffle = perm;
    } else {
      if (index < newCurrent) {
        newCurrent--;
      } else if (index == newCurrent) {
        newCurrent =
            order.isEmpty ? -1 : (newCurrent >= order.length ? order.length - 1 : newCurrent);
      }
    }
    _commit(order: order, index: newCurrent, shuffleOrder: newShuffle);
  }

  /// Reorder by full [playbackOrder] indices. [oldQueueIndex] and
  /// [newQueueIndex] are positions in [playbackOrder], not display offsets.
  void reorderByQueueIndex(int oldQueueIndex, int newQueueIndex) {
    if (oldQueueIndex == newQueueIndex) return;
    final order = List<String>.from(playbackOrder.value);
    if (oldQueueIndex < 0 || oldQueueIndex >= order.length) return;
    if (newQueueIndex < 0 || newQueueIndex > order.length) return;

    final item = order.removeAt(oldQueueIndex);
    final adjusted = newQueueIndex > oldQueueIndex ? newQueueIndex - 1 : newQueueIndex;
    order.insert(adjusted, item);

    int newCurrent = currentIndex.value;
    if (oldQueueIndex < newCurrent && adjusted >= newCurrent) {
      newCurrent--;
    } else if (oldQueueIndex > newCurrent && adjusted <= newCurrent) {
      newCurrent++;
    }
    _commit(order: order, index: newCurrent);
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

  void clearUpNext() {
    final i = currentIndex.value;
    final order = playbackOrder.value;
    final prefix = i >= 0 && i < order.length ? order.sublist(0, i + 1) : <String>[];
    List<int>? newShuffle;
    if (isShuffleEnabled.value) {
      // Truncate the shuffle permutation to the played prefix.
      if (i < 0) {
        newShuffle = const [];
      } else {
        newShuffle = List<int>.from(shuffleOrder.value.take(i + 1));
      }
    }
    _commit(order: prefix, shuffleOrder: newShuffle);
  }

  void clearHistory() {
    _commit(hist: const []);
  }

  void clearAll() {
    _commit(
      order: const [],
      index: -1,
      hist: const [],
      isShuffleEnabled: false,
      shuffleOrder: const [],
    );
  }

  /// Toggle shuffle on/off. When enabling with a non-empty queue,
  /// performs a stable re-shuffle: the currently playing song stays at
  /// shuffle-position 0 so playback continues uninterrupted, and the
  /// unplayed tail is freshly permuted after it. Songs already played
  /// are dropped from the permutation (they remain in [playbackOrder]
  /// for history purposes).
  ///
  /// When disabling, [shuffleOrder] is cleared and [currentIndex] is
  /// mapped back to the corresponding index in [playbackOrder] so the
  /// current song is preserved.
  void toggleShuffle() {
    final wasOn = isShuffleEnabled.value;
    if (wasOn) {
      // Turn shuffle off — map currentIndex back into playbackOrder space.
      final order = playbackOrder.value;
      final perm = shuffleOrder.value;
      int newIndex = currentIndex.value;
      if (perm.isNotEmpty &&
          currentIndex.value >= 0 &&
          currentIndex.value < perm.length) {
        newIndex = perm[currentIndex.value];
      } else if (currentIndex.value < 0) {
        newIndex = -1;
      }
      // Clamp to a valid playbackOrder index.
      if (newIndex >= order.length) newIndex = order.isEmpty ? -1 : order.length - 1;
      _commit(
        isShuffleEnabled: false,
        shuffleOrder: const [],
        index: newIndex,
      );
    } else {
      // Turn shuffle on — build a stable permutation.
      final order = playbackOrder.value;
      final n = order.length;
      if (n == 0) {
        _commit(isShuffleEnabled: true, shuffleOrder: const [], index: -1);
        return;
      }
      final cur = currentIndex.value;
      final currentPlaybackIdx = (cur >= 0 && cur < n) ? cur : 0;

      // The permutation is the current song followed by a Fisher–Yates
      // shuffle of the unplayed tail (everything after the current
      // position in [playbackOrder]). Already-played songs (those
      // before the current one) are not included — they remain in
      // [playbackOrder] for history but are no longer in the play
      // sequence.
      final remaining = <int>[
        for (int k = currentPlaybackIdx + 1; k < n; k++) k,
      ];
      remaining.shuffle(_rng);
      final newPerm = <int>[currentPlaybackIdx, ...remaining];

      _commit(
        isShuffleEnabled: true,
        shuffleOrder: newPerm,
        index: 0,
      );
    }
  }

  /// Update the radio seed. Called when radio mode starts so it survives restarts.
  void updateRadioSeed(String videoId) {
    final recent = List<String>.from(_service.getRecentRadioSeeds());
    recent.remove(videoId);
    recent.insert(0, videoId);
    // Keep only the 5 most recent seeds.
    if (recent.length > 5) recent.removeLast();
    _commit(radioSeed: videoId, recentRadioSeeds: recent);
  }

  /// Clear the radio seed. Called when radio mode stops.
  void clearRadioSeed() {
    _commit(radioSeed: null);
  }

  /// Mirror the handler's canonical state into the signal. The handler
  /// provides paths in the order it actually plays them (so this is the
  /// active sequence — shuffled when shuffle is on, sequential
  /// otherwise) plus the index of the currently playing song within
  /// that sequence.
  ///
  /// History is **not** mutated here — it's updated only when the
  /// current song actually changes (see [_playCurrent] in
  /// [MyAudioHandler]).
  ///
  /// Importantly, [playbackOrder] (the canonical unshuffled queue) is
  /// **not** overwritten. If shuffle is enabled, the handler emits a
  /// shuffled order, but the canonical order remains the one the user
  /// originally loaded. [shuffleOrder] is rebuilt so it stays consistent
  /// with the handler's emitted order.
  void syncFromHandler({
    required List<String> playbackOrder,
    required int currentIndex,
  }) {
    final play = playbackOrder;
    final canonical = this.playbackOrder.value;
    final sameAsCanonical =
        canonical.length == play.length &&
            List.generate(canonical.length, (i) => canonical[i] == play[i])
                .every((b) => b);

    if (isShuffleEnabled.value && play.isNotEmpty) {
      if (!sameAsCanonical && canonical.isNotEmpty) {
        // Handler's emitted order differs from the canonical (shuffle
        // is on and the queue was just shuffled). Rebuild the
        // permutation by mapping each emitted path back to its index in
        // the canonical order.
        final canonicalSet = canonical.toSet();
        final newPaths = [for (final p in play) if (!canonicalSet.contains(p)) p];
        final byPath = <String, int>{
          for (int k = 0; k < canonical.length; k++) canonical[k]: k,
        };
        if (newPaths.isEmpty) {
          // Every emitted path is already in canonical — the only
          // change is order, so the existing byPath maps them all.
          shuffleOrder.value = [for (final p in play) byPath[p] ?? 0];
        } else {
          // Append the new (radio-fill) paths to canonical in their
          // emitted order, then map each emitted path through the
          // expanded byPath so the permutation resolves each index to
          // a distinct canonical entry. Without this, unmapped paths
          // collapsed to 0 and every up-next tile rendered the same
          // song via pathAtActiveIndex.
          final newCanonical = <String>[...canonical, ...newPaths];
          for (int k = canonical.length; k < newCanonical.length; k++) {
            byPath[newCanonical[k]] = k;
          }
          this.playbackOrder.value = newCanonical;
          shuffleOrder.value = [for (final p in play) byPath[p] ?? 0];
        }
      } else if (sameAsCanonical) {
        // Handler reported the unshuffled order; shuffleOrder should be
        // the trivial identity permutation.
        shuffleOrder.value = List<int>.generate(play.length, (i) => i);
      } else {
        // Canonical is empty (first sync, before any mutator set it).
        // Promote the handler's order to canonical and use trivial
        // shuffleOrder.
        this.playbackOrder.value = List<String>.from(play);
        shuffleOrder.value = List<int>.generate(play.length, (i) => i);
      }
    } else {
      // Shuffle off — ensure playbackOrder matches the handler's order
      // (or stays empty if the queue is empty). The handler's order is
      // the canonical order in this case.
      if (!sameAsCanonical) {
        this.playbackOrder.value = List<String>.from(play);
      }
      shuffleOrder.value = const [];
    }

    this.currentIndex.value = currentIndex;
  }

  /// Resolve a path to a [Song] using the in-memory caches owned by
  /// [AudioSignal]. This is a thin convenience wrapper so the queue UI
  /// does not have to import [AudioSignal] directly.
  Song resolveSong(String path) => audioSignal.resolveSong(path);

  /// Given an index in the active play sequence, return the corresponding
  /// index in [playbackOrder]. Returns -1 if out of range.
  int playbackOrderIndexForActive(int activeIndex) {
    if (activeIndex < 0) return -1;
    if (isShuffleEnabled.value) {
      final perm = shuffleOrder.value;
      if (activeIndex >= perm.length) return -1;
      return perm[activeIndex];
    }
    final play = playbackOrder.value;
    if (activeIndex >= play.length) return -1;
    return activeIndex;
  }

  /// Build a fresh shuffle permutation of size [total]. The first
  /// [preserve] positions contain indices `[0, preserve)` so that
  /// previously-played songs keep their order. The remaining
  /// positions are Fisher–Yates shuffled.
  List<int> _buildFreshPermutation(int total, {required int preserve}) {
    final perm = List<int>.generate(total, (i) => i);
    if (preserve > total) preserve = total;
    if (preserve < 0) preserve = 0;
    // Fisher–Yates on the tail.
    for (int i = total - 1; i > preserve; i--) {
      final j = preserve + _rng.nextInt(i - preserve + 1);
      final tmp = perm[i];
      perm[i] = perm[j];
      perm[j] = tmp;
    }
    return perm;
  }

}

final queueSignal = QueueSignal();