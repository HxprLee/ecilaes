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

import 'package:dart_discord_presence/dart_discord_presence.dart';
import 'platform_service.dart';

PlatformService getPlatformService() => PlatformServiceStub();

class PlatformServiceStub implements PlatformService {
  @override
  Future<void> init() async {
    // No-op on mobile/web
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
    // No-op on mobile/web
  }

  @override
  Future<void> clearPresence() async {
    // No-op on mobile/web
  }

  @override
  Future<void> dispose() async {
    // No-op on mobile/web
  }
}
