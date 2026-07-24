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
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_shell.dart';
import 'signals/audio_signal.dart';
import 'signals/navigation_signal.dart';
import 'router/routes.dart';
import 'screens/home/routes.dart' as home_routes;
import 'screens/library/routes.dart' as library_routes;
import 'screens/search/routes.dart' as search_routes;
import 'screens/youtube/routes.dart' as youtube_routes;
import 'screens/settings/routes.dart' as settings_routes;

/// The root navigator key. Held on the [GoRouter] so widgets mounted above
/// the Navigator (e.g. [MaterialApp.builder]) can still reach the root
/// [OverlayState] — required by the global toast host, which lives above
/// the Navigator and needs to install [OverlayEntry]s into the root overlay.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'rootNavigator');

/// Creates the GoRouter configuration.
final GoRouter router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.home,
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return HomeShell(child: child);
      },
      routes: [
        ...home_routes.homeRoutes,
        ...library_routes.libraryRoutes,
        ...search_routes.searchRoutes,
        ...youtube_routes.youtubeRoutes,
        ...settings_routes.settingsRoutes,
      ],
    ),
  ],
  errorBuilder: (context, state) =>
      Scaffold(body: Center(child: Text('Error: ${state.error}'))),
);

bool _navigationListenerInitialized = false;

/// Resets header state when a new route is first entered and records the
/// visit in [NavigationSignal] for the desktop back/forward buttons. Called
/// once at startup from main.dart — calling it more than once would
/// double-record every navigation (the underlying listener is not removed
/// to keep this cheap on hot restart).
void initNavigationListener() {
  if (_navigationListenerInitialized) return;
  _navigationListenerInitialized = true;

  navigationSignal.clear();
  // Seed the back-stack with the absolute root so the canonical "/" route
  // is always present in history — even if the router's initial event fires
  // before the listener is wired up (which happens during cold start).
  navigationSignal.recordVisit(AppRoutes.home);

  router.routerDelegate.addListener(_handleRouteChange);
  // Reset once at startup so the first build sees a clean header state.
  _resetHeaderState();
}

void _handleRouteChange() {
  // Defer the read until go_router's delegate has finished its current
  // notification — the synchronous `addListener` callback fires before the
  // delegate has fully updated `currentConfiguration` for the new location.
  SchedulerBinding.instance.addPostFrameCallback((_) {
    final config = router.routerDelegate.currentConfiguration;
    // ImperativeRouteMatch (a push) carries the full matched URI on its
    // `matches.uri`; a plain RouteMatch only exposes `matchedLocation`.
    // Prefer the URI so the recorded history includes any query string.
    final lastMatch = config.lastOrNull;
    String loc;
    if (lastMatch is ImperativeRouteMatch) {
      loc = lastMatch.matches.uri.toString();
    } else {
      loc = lastMatch?.matchedLocation ?? config.uri.toString();
    }
    if (loc.isEmpty) return;

    navigationSignal.recordVisit(loc);
    _resetHeaderState();
  });
}

void _resetHeaderState() {
  audioSignal.headerShowBlur.value = false;
  audioSignal.headerTitleProgress.value = 0.0;
  audioSignal.headerArtCover.value = null;
}
