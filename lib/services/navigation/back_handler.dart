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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../signals/audio_signal.dart';
import '../../signals/navigation_signal.dart';
import '../../signals/overlay_signal.dart';

/// Result of a back-press attempt.
///
/// - [handled] is `true` if the back action was consumed in-app (player
///   minimized, overlay closed, route popped, etc.). The caller should not
///   propagate to the OS.
/// - [handled] is `false` if no in-app action was possible. The caller
///   should let the OS handle the back press (typically closing the app on
///   mobile).
class BackResult {
  final bool handled;
  const BackResult(this.handled);
}

/// Central back-action handler. Used by:
///
/// - `PopScope` on `HomeShellMobile` and `HomeShellDesktop`.
/// - The visible back arrow on the mobile header.
/// - The back/forward buttons on the desktop header.
/// - The Escape-key handler on the search-results screen.
///
/// The priority order is:
///
/// 1. Morphing player is expanded -> minimize the player.
/// 2. An open overlay (drawer, modal sheet, dialog) -> close the topmost one.
/// 3. The Navigator can pop a pushed route -> pop it.
/// 4. NavigationSignal has prior history -> pop that history.
/// 5. Otherwise -> allow the OS to close the app.
class AppBackHandler {
  /// Run the back action. Returns whether the action was handled in-app.
  ///
  /// [closeOverlays] is called when overlays should be closed. When `null`
  /// the handler will attempt to close the topmost overlay via
  /// [Navigator.maybePop] (which works for `showDialog` / `showModalBottomSheet`
  /// routes as well as `showMenu` overlays attached via [OverlayState]).
  BackResult invoke(
    BuildContext context, {
    Future<bool> Function()? closeOverlays,
  }) {
    // 1. Expanded morphing player.
    if (audioSignal.playerExpansion.value > 0.001) {
      audioSignal.minimizePlayerTrigger.value++;
      return const BackResult(true);
    }

    // 2. Open overlay (drawer, modal sheet, dialog).
    if (overlaySignal.isDrawerOpen.value ||
        overlaySignal.activeModalSheet.value != ActiveOverlay.none) {
      if (overlaySignal.isDrawerOpen.value) {
        final scaffold = Scaffold.maybeOf(context);
        if (scaffold != null && scaffold.isDrawerOpen) {
          scaffold.closeDrawer();
          overlaySignal.isDrawerOpen.value = false;
          return const BackResult(true);
        }
      }
      // Close the topmost overlay/dialog/sheet if possible.
      if (closeOverlays != null) {
        // Caller-provided closer; we trust its return value.
        // We don't await: the user wants an immediate response.
        // ignore: discarded_futures
        closeOverlays();
      } else {
        // Default: ask the root Navigator to pop whatever is on top. Works
        // for showDialog/showModalBottomSheet as long as they used
        // useRootNavigator: true (or are attached to the root overlay).
        final nav = Navigator.of(context, rootNavigator: true);
        // ignore: discarded_futures
        nav.maybePop();
      }
      overlaySignal.reset();
      return const BackResult(true);
    }

    // 3. Pushed route on the active Navigator.
    final router = GoRouter.of(context);
    if (router.canPop()) {
      // Capture the URL being popped so the navigation history can move
      // it onto the forward-stack. ImperativeRouteMatch (a push) carries
      // the full matched URI on its `matches.uri`; a plain RouteMatch
      // only exposes `matchedLocation`. Prefer the URI so a forward-nav
      // lands the user on the same URL they were on, including any
      // query string.
      final poppingMatch = router.routerDelegate.currentConfiguration.lastOrNull;
      String? poppingLoc;
      if (poppingMatch is ImperativeRouteMatch) {
        poppingLoc = poppingMatch.matches.uri.toString();
      } else if (poppingMatch != null) {
        poppingLoc = poppingMatch.matchedLocation;
      }
      // Record pop BEFORE router.pop() — notifyListeners fires synchronously
      // during the pop and triggers the route listener (recordVisit).
      // Without this ordering, recordVisit adds the target location before
      // the old entry is removed, breaking the dedup guard.
      if (poppingLoc != null) {
        navigationSignal.recordPop(poppingLoc);
      }
      router.pop();
      return const BackResult(true);
    }

    // 4. Custom NavigationSignal history.
    if (navigationSignal.canGoBack) {
      navigationSignal.stepBack(context);
      return const BackResult(true);
    }

    // 5. Nothing left - let the OS handle the back press.
    return const BackResult(false);
  }
}

/// Convenience singleton matching the pattern of other top-level services.
final AppBackHandler appBackHandler = AppBackHandler();