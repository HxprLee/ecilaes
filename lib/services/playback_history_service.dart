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

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/history_entry.dart';

class PlaybackHistoryService {
  static const String _fileName = 'playback_history.json';

  static Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/ecilaes_cache';
    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('$path/$_fileName');
  }

  static Future<List<HistoryEntry>> loadHistory() async {
    try {
      final file = await _file;
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((j) => HistoryEntry.fromJson(j)).toList();
    } catch (e) {
      print('Error loading playback history: $e');
      return [];
    }
  }

  static Future<void> saveHistory(List<HistoryEntry> history) async {
    try {
      final file = await _file;
      final jsonList = history.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print('Error saving playback history: $e');
    }
  }

  static Future<void> recordPlay(String songPath) async {
    final history = await loadHistory();
    final index = history.indexWhere((e) => e.songPath == songPath);

    if (index != -1) {
      final entry = history[index];
      history[index] = entry.copyWith(
        playCount: entry.playCount + 1,
        lastPlayed: DateTime.now(),
      );
    } else {
      history.add(
        HistoryEntry(
          songPath: songPath,
          playCount: 1,
          lastPlayed: DateTime.now(),
        ),
      );
    }

    // Keep only the last 100 entries for performance
    history.sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));
    if (history.length > 100) {
      history.removeRange(100, history.length);
    }

    await saveHistory(history);
  }
}
