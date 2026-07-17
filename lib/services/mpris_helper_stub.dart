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

/// Stub used on non-Linux platforms (Android, iOS, web). The conditional
/// import in `mpris_helper.dart` selects this file unless `dart:io` is
/// available, in which case `mpris_helper_linux.dart` is loaded instead.
///
/// Public so the conditional import in `mpris_helper.dart` can resolve it.
void registerMprisPlatformImpl() {
  // No-op: the platform's native media-control surface is handled by
  // audio_service's built-in plugin platform.
}
