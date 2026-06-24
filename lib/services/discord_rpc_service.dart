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
import 'package:flutter/foundation.dart';
import 'package:dart_discord_presence/dart_discord_presence.dart';
import '../models/song.dart';
import '../signals/settings_signal.dart';

class DiscordRpcService {
  static final DiscordRpcService _instance = DiscordRpcService._internal();
  factory DiscordRpcService() => _instance;
  DiscordRpcService._internal();

  DiscordRPC? _rpc;
  bool _isConnected = false;
  Completer<void>? _initCompleter;

  static const String _applicationId = '1453422309057757307';

  String _truncate(String? text, int maxLength) {
    if (text == null || text.isEmpty) return '';
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  String _sanitize(String? text) {
    if (text == null) return '';
    return text
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('…', '...')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '') // Remove control characters
        .trim();
  }

  Future<void> init() async {
    if (_isConnected && _rpc != null && _rpc!.isInitialized) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();

    try {
      // debugPrint('DiscordRpcService: Initializing with ID $_applicationId');
      _rpc = DiscordRPC();
      await _rpc!.initialize(_applicationId);
      _isConnected = true;
      debugPrint('DiscordRpcService: Connected.');
    } catch (e) {
      if (e.toString().contains('Discord is not running')) {
        // Silently fail if Discord is just not open
        _isConnected = false;
      } else {
        debugPrint('DiscordRpcService: Init error: $e');
        _isConnected = false;
      }
    } finally {
      if (!(_initCompleter?.isCompleted ?? true)) {
        _initCompleter?.complete();
      }
      _initCompleter = null;
    }
  }

  Future<void> updatePresence(
    Song song, {
    String? artworkUrl,
    bool isPlaying = true,
    int? startTimeStamp,
    int? endTimeStamp,
    List<DiscordButton>? buttons,
  }) async {
    try {
      if (!_isConnected || _rpc == null) {
        await init();
      }

      if (!_isConnected || _rpc == null) return;

      print(
        'DiscordRpcService: updatePresence called for "${song.title}" (playing: $isPlaying)',
      );

      final presence = DiscordPresence(
        type: DiscordActivityType.listening,
        details: _truncate(_sanitize(song.title), 128),
        state: _truncate(_sanitize(song.artist), 128),
        timestamps: startTimeStamp != null
            ? DiscordTimestamps(
                start: startTimeStamp ~/ 1000,
                end: endTimeStamp != null ? endTimeStamp ~/ 1000 : null,
              )
            : (isPlaying ? DiscordTimestamps.started(DateTime.now()) : null),
        largeAsset: artworkUrl != null && artworkUrl.startsWith('http')
            ? DiscordAsset.fromUrl(
                artworkUrl,
                text: isPlaying ? '' : '⏸︎ Paused',
              )
            : DiscordAsset(
                key: artworkUrl ?? 'app_icon',
                text: isPlaying ? '▸ Playing' : '⏸︎ Paused',
              ),
        buttons: _buildButtons(song, buttons),
      );

      await _rpc!.setPresence(presence);
      print('DiscordRpcService: updatePresence sent successfully.');
    } catch (e, stack) {
      print('DiscordRpcService: updatePresence error: $e');
      print('Stack trace: $stack');
      _isConnected = false;
    }
  }

  List<DiscordButton>? _buildButtons(Song song, List<DiscordButton>? defaultButtons) {
    final enabledButtons = <DiscordButton>[];

    final listenEnabled = settingsSignal.enableDiscordListenButton.value;
    final projectEnabled = settingsSignal.enableDiscordProjectLink.value;

    if (listenEnabled) {
      final url = song.path.startsWith('yt:')
          ? 'https://www.youtube.com/watch?v=${song.path.substring(3)}'
          : null;
      if (url != null) {
        enabledButtons.add(DiscordButton(label: 'Listen on YouTube', url: url));
      }
    }

    if (projectEnabled) {
      enabledButtons.add(DiscordButton(
        label: 'Open Project',
        url: 'https://github.com/HxprLee/ecilaes',
      ));
    }

    return enabledButtons.isEmpty ? null : enabledButtons;
  }

  Future<void> clearPresence() async {
    if (!_isConnected || _rpc == null) return;

    try {
      print('DiscordRpcService: Clearing presence...');
      await _rpc!.clearPresence();
    } catch (e) {
      print('DiscordRpcService: clearPresence error: $e');
      _isConnected = false;
    }
  }

  Future<void> dispose() async {
    print('DiscordRpcService: Disposing and disconnecting...');
    try {
      await _rpc!.shutdown();
    } catch (e) {
      // Ignore errors during disconnect
    }
    _rpc = null;
    _isConnected = false;
  }
}
