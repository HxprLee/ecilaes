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

/// Represents the playback queue as a single ordered list of song paths,
/// along with the index of the currently playing song and a separate
/// history list for played songs (newest first).
///
/// This is the single source of truth for queue state. Local files and
/// YouTube-sourced songs (using the `yt:<videoId>` path convention) coexist
/// in the same list.
class QueueModel {
  /// Ordered list of every song in the playback queue, current song at
  /// [currentIndex]. Local file paths and `yt:<videoId>` paths mix freely.
  final List<String> playbackOrder;

  /// The index of the currently playing song within [playbackOrder].
  /// -1 means the queue is empty / nothing is playing.
  final int currentIndex;

  /// Songs that have been played, newest first. Capped on insert to keep
  /// the file small.
  final List<String> history;

  /// Radio seed videoId (without the `yt:` prefix). Persisted so the app can
  /// offer to continue radio on restart.
  final String? radioSeed;

  /// Recent radio seed videoIds. Used for "radio from recent" without re-fetching.
  final List<String> recentRadioSeeds;

  /// Whether shuffle mode is currently enabled. Drives whether [shuffleOrder]
  /// or [playbackOrder] is the active play sequence.
  final bool isShuffleEnabled;

  /// Permutation of indices into [playbackOrder] that defines the shuffled
  /// play order. `playbackOrder[shuffleOrder[i]]` is the i-th song played
  /// while shuffle is enabled. Empty when shuffle is off or the queue is
  /// empty.
  final List<int> shuffleOrder;

  const QueueModel({
    this.playbackOrder = const [],
    this.currentIndex = -1,
    this.history = const [],
    this.radioSeed,
    this.recentRadioSeeds = const [],
    this.isShuffleEnabled = false,
    this.shuffleOrder = const [],
  });

  bool get isEmpty => playbackOrder.isEmpty;
  bool get isNotEmpty => playbackOrder.isNotEmpty;
  int get length => playbackOrder.length;

  /// Songs that will play after the current one, in play order.
  List<String> get upNextPaths {
    if (currentIndex < 0 || currentIndex >= playbackOrder.length - 1) {
      return const [];
    }
    return playbackOrder.sublist(currentIndex + 1);
  }

  /// The song that is currently playing, or null when the queue is empty.
  String? get currentPath {
    if (currentIndex < 0 || currentIndex >= playbackOrder.length) return null;
    return playbackOrder[currentIndex];
  }

  QueueModel copyWith({
    List<String>? playbackOrder,
    int? currentIndex,
    List<String>? history,
    String? radioSeed,
    List<String>? recentRadioSeeds,
    bool? isShuffleEnabled,
    List<int>? shuffleOrder,
  }) {
    return QueueModel(
      playbackOrder: playbackOrder ?? this.playbackOrder,
      currentIndex: currentIndex ?? this.currentIndex,
      history: history ?? this.history,
      radioSeed: radioSeed ?? this.radioSeed,
      recentRadioSeeds: recentRadioSeeds ?? this.recentRadioSeeds,
      isShuffleEnabled: isShuffleEnabled ?? this.isShuffleEnabled,
      shuffleOrder: shuffleOrder ?? this.shuffleOrder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'playbackOrder': playbackOrder,
      'currentIndex': currentIndex,
      'history': history,
      'radioSeed': radioSeed,
      'recentRadioSeeds': recentRadioSeeds,
      'isShuffleEnabled': isShuffleEnabled,
      'shuffleOrder': shuffleOrder,
    };
  }

  factory QueueModel.fromJson(Map<String, dynamic> json) {
    return QueueModel(
      playbackOrder: (json['playbackOrder'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      currentIndex: json['currentIndex'] as int? ?? -1,
      history: (json['history'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      radioSeed: json['radioSeed'] as String?,
      recentRadioSeeds: (json['recentRadioSeeds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isShuffleEnabled: json['isShuffleEnabled'] as bool? ?? false,
      shuffleOrder: (json['shuffleOrder'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
    );
  }

  static String encode(QueueModel model) => jsonEncode(model.toJson());
  static QueueModel decode(String data) =>
      QueueModel.fromJson(jsonDecode(data) as Map<String, dynamic>);
}
