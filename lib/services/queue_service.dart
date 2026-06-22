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
import 'package:path_provider/path_provider.dart';
import '../models/queue_model.dart';

/// File-backed persistence for [QueueModel]. Writes to a single
/// `queue.json` file in the app documents directory. Emits the new model
/// on its broadcast stream after every mutation so subscribers can mirror
/// the canonical state into their own signals.
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

  /// Replace the entire model. Used by [QueueSignal] after a single
  /// authoritative update so that persistence and the broadcast stream
  /// stay aligned with the signal layer.
  void replace(QueueModel model) {
    _model = model;
    _emit();
    unawaited(_save());
  }

  void dispose() {
    _controller.close();
  }
}
