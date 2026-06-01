import 'dart:convert';

/// Represents the two-section model for the playback queue.
///
/// - **Up Next** is the ordered list of track paths that will play after the current one.
/// - **History** is the list of track paths that have already been played, newest first.
class QueueModel {
  final List<String> upNext;
  final List<String> history;
  final String? sourceId;
  final bool sourceIsPlaylist;

  const QueueModel({
    this.upNext = const [],
    this.history = const [],
    this.sourceId,
    this.sourceIsPlaylist = false,
  });

  bool get isEmpty => upNext.isEmpty;
  bool get isNotEmpty => upNext.isNotEmpty;
  int get upNextCount => upNext.length;
  int get historyCount => history.length;

  QueueModel copyWith({
    List<String>? upNext,
    List<String>? history,
    String? sourceId,
    bool? sourceIsPlaylist,
  }) {
    return QueueModel(
      upNext: upNext ?? this.upNext,
      history: history ?? this.history,
      sourceId: sourceId ?? this.sourceId,
      sourceIsPlaylist: sourceIsPlaylist ?? this.sourceIsPlaylist,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'upNext': upNext,
      'history': history,
      'sourceId': sourceId,
      'sourceIsPlaylist': sourceIsPlaylist,
    };
  }

  factory QueueModel.fromJson(Map<String, dynamic> json) {
    return QueueModel(
      upNext: (json['upNext'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      history: (json['history'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      sourceId: json['sourceId'] as String?,
      sourceIsPlaylist: json['sourceIsPlaylist'] as bool? ?? false,
    );
  }

  static String encode(QueueModel model) => jsonEncode(model.toJson());
  static QueueModel decode(String data) =>
      QueueModel.fromJson(jsonDecode(data) as Map<String, dynamic>);
}
