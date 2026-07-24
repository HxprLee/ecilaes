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

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../router/routes.dart';
import '../signals/audio_signal.dart';

/// Replacement-style navigation for **tab-level** destinations only — the
/// sidebar/mobile-nav targets (Home, Library, YouTube, Settings root, etc.).
/// Uses [GoRouter.go], which keeps the underlying Navigator stack one entry
/// deep. Detail/drill-down navigation should use [navigatePush] so the back
/// button has something to pop.
void navigateTab(BuildContext context, String location, {Object? extra}) {
  final current = GoRouterState.of(context).uri.toString();
  if (current == location) return;
  if (extra != null) {
    context.go(location, extra: extra);
  } else {
    context.go(location);
  }
}

/// Push-style navigation for **detail** screens (album detail, settings
/// sub-pages, file-explorer subfolders, etc.). Pushes onto the Navigator
/// stack so the system back button pops back to the parent.
void navigatePush(BuildContext context, String location, {Object? extra}) {
  final current = GoRouterState.of(context).uri.toString();
  if (current == location) return;
  if (extra != null) {
    context.push(location, extra: extra);
  } else {
    context.push(location);
  }
}

/// Backwards-compatible alias for [navigateTab]. New code should call
/// [navigateTab] directly so the caller's intent (tab-level vs detail) is
/// obvious from the symbol name.
void navigateGo(BuildContext context, String location, {Object? extra}) =>
    navigateTab(context, location, extra: extra);

/// Derive a display title from the current route. Used by both the desktop
/// and mobile header bars so they stay in sync. Returns an empty string when
/// no specific title is known — the caller can fall back to a generic label.
String pageTitleFor(String route) {
  if (route == AppRoutes.home) return 'Home';
  if (route == AppRoutes.songs) return 'Songs';
  if (route == AppRoutes.search) return 'Search';
  if (route == AppRoutes.library) return 'Library';
  if (route == AppRoutes.explorer) return 'Folders';
  if (route == AppRoutes.recentlyPlayed) return 'Recently Played';
  if (route == AppRoutes.recentlyAdded) return 'Recently Added';
  if (route == AppRoutes.playlists) return 'Playlists';
  if (route == AppRoutes.albums) return 'Albums';
  if (route == AppRoutes.artists) return 'Artists';
  if (route == AppRoutes.youtube) return 'YouTube Music';
  if (route.startsWith('/youtube/album')) return 'Album';
  if (route.startsWith('/youtube/artist')) return 'Artist';
  if (route.startsWith('/youtube/playlist')) return 'Playlist';
  if (route.startsWith('/albums/')) {
    final parts = route.split('/');
    if (parts.length >= 4) return Uri.decodeComponent(parts.last);
  }
  if (route.startsWith('/artists/')) {
    final parts = route.split('/');
    if (parts.length >= 3) return Uri.decodeComponent(parts.last);
  }
  if (route == AppRoutes.settings) return 'Settings';
  if (route == AppRoutes.settingsCustomization) return 'Customization';
  if (route == AppRoutes.settingsPlayback) return 'Playback';
  if (route == AppRoutes.settingsLibrary) return 'Library';
  if (route == AppRoutes.settingsAbout) return 'About';
  if (route == AppRoutes.settingsCustomizationPlayerLayout)
    return 'Player Bar Layout';
  if (route == AppRoutes.settingsCustomizationLyricsLayout)
    return 'Lyrics Layout';
  if (route == AppRoutes.settingsCustomizationActionsLayout)
    return 'Actions Sheet Layout';
  if (route == AppRoutes.settingsCustomizationSidebarLayout)
    return 'Sidebar Items';
  if (route == AppRoutes.settingsIntegrationsDiscordPresence)
    return 'Discord Rich Presence';
  if (route == AppRoutes.settingsLibraryManageCache) return 'Cache Management';
  if (route == AppRoutes.settingsIntegrationsYoutubeLogin)
    return 'YouTube Music Login';
  if (route.startsWith('/explorer/')) return 'Folders';
  if (route.startsWith('/playlist/')) {
    final id = route.split('/').last;
    try {
      final playlist = audioSignal.playlists.value.firstWhere(
        (p) => p.id == id,
      );
      return playlist.name;
    } catch (_) {
      return 'Playlist';
    }
  }
  return '';
}
