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

/// Tags the open-modal-overlay state of the app. Consumed by the central
/// back-handler so the system back button closes the topmost overlay instead
/// of popping the route or backgrounding the app.
enum ActiveOverlay {
  none,

  // Drawer (mobile shell only).
  drawer,

  // Bottom sheets.
  songActions,
  queue,
  lyrics,

  // Modal dialogs.
  sleepTimer,
  playbackSpeed,
  playlistPicker,
  songInfo,
  editMetadata,
  createPlaylist,
  managePlaylists,
  cacheConfirm,
  clearHistoryConfirm,
  resetDirectoryConfirm,
  clearMissingConfirm,
  forceScanConfirm,
  ytLoginInstructions,
  integrationsConnect,

  // File explorer.
  folderMenu,

  // Generic fallback for callers that don't tag explicitly.
  unknown,
}

/// Lightweight registry of currently-open modal overlays.
///
/// The signals are mutable from anywhere; modal openers call [push] when
/// they show and the dismissing widget calls [pop] when it closes. The
/// central back-handler ([AppBackHandler]) consults [activeModalSheet] and
/// [isDrawerOpen] to decide whether to consume the back press itself.
class OverlaySignal {
  /// True when the Scaffold's drawer is open. Driven by the mobile shell.
  final Signal<bool> isDrawerOpen = signal(false);

  /// Topmost active overlay. `none` means nothing modal is open.
  final Signal<ActiveOverlay> activeModalSheet =
      signal(ActiveOverlay.none);

  void pushDrawer() {
    isDrawerOpen.value = true;
  }

  void popDrawer() {
    isDrawerOpen.value = false;
  }

  void push(ActiveOverlay overlay) {
    activeModalSheet.value = overlay;
  }

  void pop(ActiveOverlay overlay) {
    if (activeModalSheet.value == overlay) {
      activeModalSheet.value = ActiveOverlay.none;
    }
  }

  /// Reset to the closed state. Used by the back-handler after it dismisses
  /// a top-level overlay so stale tags don't leak across sessions.
  void reset() {
    isDrawerOpen.value = false;
    activeModalSheet.value = ActiveOverlay.none;
  }
}

final OverlaySignal overlaySignal = OverlaySignal();