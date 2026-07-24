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

import 'package:signals/signals_flutter.dart';

/// Layout-level runtime measurements shared between the shell and any
/// overlay mounted above it (toasts, OSDs, global popups).
///
/// Lives here, not in [SettingsSignal], because the values are derived
/// from the currently-running shell's layout — they are not user
/// preferences and aren't persisted across launches.
class ShellLayoutSignal {
  /// Effective horizontal width occupied by the persistent sidebar on
  /// desktop shells. `0` on mobile shells or when the sidebar is hidden.
  ///
  /// Written by [HomeShellDesktop] whenever its sidebar's expanded width
  /// changes (toggle, drag-to-resize, screen-size breakpoints). Read by
  /// anything that needs to dodge the sidebar — currently the global toast
  /// host, which anchors toasts to the bottom of the *content* area, not
  /// the full screen.
  final Signal<double> sidebarWidth = signal<double>(0);

  void setSidebarWidth(double width) {
    sidebarWidth.value = width;
  }
}

final ShellLayoutSignal shellLayoutSignal = ShellLayoutSignal();
