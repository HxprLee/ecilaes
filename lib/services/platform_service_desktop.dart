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

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dart_discord_presence/dart_discord_presence.dart';
import 'platform_service.dart';
import 'platform_service_desktop_impl.dart' deferred as impl;

PlatformService getPlatformService() => PlatformServiceProxy();

class PlatformServiceProxy implements PlatformService {
  PlatformService? _delegate;

  @override
  Future<void> init() async {
    if (kIsWeb) return;
    // Only load implementation if we are on a desktop platform
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      await impl.loadLibrary();
      _delegate = impl.PlatformServiceDesktopImpl();
      await _delegate!.init();
    }
  }

  @override
  Future<void> updatePresence(
    dynamic song, {
    String? artworkUrl,
    bool isPlaying = true,
    int? startTimeStamp,
    int? endTimeStamp,
    List<DiscordButton>? buttons,
  }) async {
    if (_delegate != null) {
      await _delegate!.updatePresence(
        song,
        artworkUrl: artworkUrl,
        isPlaying: isPlaying,
        startTimeStamp: startTimeStamp,
        endTimeStamp: endTimeStamp,
        buttons: buttons,
      );
    }
  }

  @override
  Future<void> clearPresence() async {
    if (_delegate != null) {
      await _delegate!.clearPresence();
    }
  }

  @override
  Future<void> dispose() async {
    if (_delegate != null) {
      await _delegate!.dispose();
    }
  }
}
