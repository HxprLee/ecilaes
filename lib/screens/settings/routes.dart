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

import 'package:go_router/go_router.dart';
import '../../router/routes.dart';
import '../../router/transitions.dart';
import '../settings_screen.dart';
import 'customization_screen.dart';
import 'playback_section.dart';
import 'library_section.dart';
import 'about_section.dart';
import 'actions_layout_section.dart';
import 'player_bar_layout_section.dart';
import 'lyrics_appearance_section.dart';
import 'sidebar_layout_section.dart';
import 'discord_presence_section.dart';
import 'cache_management_screen.dart';
import 'yt_login_webview_screen.dart';
import 'integrations_section.dart';

List<GoRoute> get settingsRoutes => [
  GoRoute(
    path: AppRoutes.settings,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const SettingsScreen()),
  ),
  GoRoute(
    path: AppRoutes.settingsCustomization,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const CustomizationScreen()),
  ),
  GoRoute(
    path: AppRoutes.settingsCustomizationActionsLayout,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const ActionsLayoutSection()),
  ),
  GoRoute(
    path: AppRoutes.settingsCustomizationPlayerLayout,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const PlayerBarLayoutSection()),
  ),
  GoRoute(
    path: AppRoutes.settingsCustomizationLyricsLayout,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const LyricsAppearanceSection()),
  ),
  GoRoute(
    path: AppRoutes.settingsCustomizationSidebarLayout,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const SidebarLayoutSection()),
  ),
  GoRoute(
    path: AppRoutes.settingsPlayback,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const PlaybackSection()),
  ),
  GoRoute(
    path: AppRoutes.settingsLibrary,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const LibrarySection()),
  ),
  GoRoute(
    path: AppRoutes.settingsLibraryManageCache,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const CacheManagementScreen()),
  ),
  GoRoute(
    path: AppRoutes.settingsIntegrations,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const IntegrationsSection()),
  ),
  GoRoute(
    path: AppRoutes.settingsIntegrationsDiscordPresence,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const DiscordPresenceSection()),
  ),
  GoRoute(
    path: AppRoutes.settingsIntegrationsYoutubeLogin,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const YtLoginWebViewScreen()),
  ),
  GoRoute(
    path: AppRoutes.settingsAbout,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const AboutSection()),
  ),
];
