import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import '../models/queue_model.dart';

class QueueService {
  static const String _fileName = 'queue.json';

  static final QueueService _instance = QueueService._internal();
  factory QueueService() => _instance;
  QueueService._internal();

  QueueModel _model = const QueueModel();
  QueueModel get model => _model;

  final _controller = StreamController<QueueModel>.broadcast();
  Stream<QueueModel> get stream => _controller.stream;

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/ecilaes_cache';
    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('$path/$_fileName');
  }

  Future<void> load() async {
    try {
      final f = await _file;
      if (await f.exists()) {
        final content = await f.readAsString();
        _model = QueueModel.decode(content);
        _controller.add(_model);
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final f = await _file;
      await f.writeAsString(QueueModel.encode(_model));
    } catch (_) {}
  }

  void _emit() {
    _controller.add(_model);
  }

  void updateFromPlayback({
    required List<MediaItem> playbackQueue,
    required int currentIndex,
  }) {
    if (playbackQueue.isEmpty) {
      _model = const QueueModel();
      _emit();
      unawaited(_save());
      return;
    }

    final allPaths = playbackQueue.map((i) => i.id).toList();
    final playedPaths = allPaths.sublist(
      0,
      currentIndex.clamp(0, allPaths.length),
    );
    final upNextPaths = currentIndex < allPaths.length - 1
        ? allPaths.sublist(currentIndex + 1)
        : <String>[];

    _model = QueueModel(
      upNext: upNextPaths,
      history: playedPaths.reversed.toList(),
    );
    _emit();
    unawaited(_save());
  }

  void updateFromQueueAndHistory({
    required List<String> upNext,
    required List<String> history,
  }) {
    _model = QueueModel(
      upNext: upNext,
      history: history,
    );
    _emit();
  }

  Future<void> setQueue({
    required List<String> songPaths,
    required int currentIndex,
  }) async {
    if (currentIndex < 0 || currentIndex >= songPaths.length) return;

    _model = QueueModel(
      upNext: songPaths.sublist((currentIndex + 1).clamp(0, songPaths.length)),
      history: songPaths.sublist(0, currentIndex).reversed.toList(),
    );
    _emit();
    await _save();
  }

  Future<void> playNext(String songPath) async {
    final upNext = List<String>.from(_model.upNext);
    upNext.insert(0, songPath);
    _model = _model.copyWith(upNext: upNext);
    _emit();
    await _save();
  }

  Future<void> addToQueue(String songPath) async {
    final upNext = List<String>.from(_model.upNext)..add(songPath);
    _model = _model.copyWith(upNext: upNext);
    _emit();
    await _save();
  }

  Future<void> reorderUpNext(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final upNext = List<String>.from(_model.upNext);
    if (oldIndex < 0 || oldIndex >= upNext.length) return;
    if (newIndex < 0 || newIndex > upNext.length) return;

    final item = upNext.removeAt(oldIndex);
    final adjustedNew = newIndex > oldIndex ? newIndex - 1 : newIndex;
    upNext.insert(adjustedNew, item);
    _model = _model.copyWith(upNext: upNext);
    _emit();
    await _save();
  }

  Future<void> moveToTop(String songPath) async {
    final upNext = List<String>.from(_model.upNext);
    upNext.remove(songPath);
    upNext.insert(0, songPath);
    _model = _model.copyWith(upNext: upNext);
    _emit();
    await _save();
  }

  Future<void> removeFromUpNext(String songPath) async {
    final upNext = _model.upNext.where((p) => p != songPath).toList();
    _model = _model.copyWith(upNext: upNext);
    _emit();
    await _save();
  }

  Future<void> clearUpNext() async {
    _model = _model.copyWith(upNext: []);
    _emit();
    await _save();
  }

  Future<void> clearHistory() async {
    _model = _model.copyWith(history: []);
    _emit();
    await _save();
  }

  Future<void> clearAll() async {
    _model = _model.copyWith(upNext: [], history: []);
    _emit();
    await _save();
  }

  Future<void> requeueFromHistory(String songPath) async {
    final history = List<String>.from(_model.history);
    final idx = history.indexWhere((p) => p == songPath);
    if (idx == -1) return;

    history.removeAt(idx);
    final upNext = List<String>.from(_model.upNext)..insert(0, songPath);
    _model = _model.copyWith(upNext: upNext, history: history);
    _emit();
    await _save();
  }

  Future<void> playHistoryItem(String songPath) async {
    await requeueFromHistory(songPath);
  }

  List<String> get upNextPaths => _model.upNext;
  List<String> get historyPaths => _model.history;

  void dispose() {
    _controller.close();
  }
}
