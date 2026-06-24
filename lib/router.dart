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
import 'screens/home_shell.dart';
import 'screens/file_explorer_screen.dart';
import 'screens/playlist_screen.dart';
import 'screens/playlists_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/search/search_result_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/search/mood_screen.dart';
import 'screens/search/yt_library_screen.dart';
import 'screens/library_screen.dart';
import 'screens/home_screen.dart';
import 'screens/recently_played_screen.dart';
import 'screens/most_played_screen.dart';
import 'screens/recently_added_screen.dart';
import 'screens/artists_screen.dart';
import 'screens/artist_detail_screen.dart';
import 'screens/albums_screen.dart';
import 'screens/album_detail_screen.dart';
import 'screens/youtube_music_screen.dart';
import 'screens/yt_album_screen.dart';
import 'screens/yt_artist_screen.dart';
import 'screens/yt_playlist_screen.dart';
import 'widgets/songs_list_content.dart';
import 'signals/audio_signal.dart';
import 'signals/navigation_signal.dart';
import 'screens/settings/customization_screen.dart';
import 'screens/settings/playback_section.dart';
import 'screens/settings/library_section.dart';
import 'screens/settings/about_section.dart';
import 'screens/settings/actions_layout_section.dart';
import 'screens/settings/player_bar_layout_section.dart';
import 'screens/settings/lyrics_appearance_section.dart';
import 'screens/settings/sidebar_layout_section.dart';
import 'screens/settings/discord_presence_section.dart';
import 'screens/settings/cache_management_screen.dart';
import 'screens/settings/yt_login_webview_screen.dart';

/// Creates the GoRouter configuration.
final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return HomeShell(child: child);
      },
      routes: [
        // Home
        GoRoute(
          path: '/',
          pageBuilder: (context, state) =>
              _buildPageWithTransition(state, const HomeScreen()),
        ),
        // Songs list
        GoRoute(
          path: '/songs',
          pageBuilder: (context, state) =>
              _buildPageWithTransition(state, const SongsListContent()),
        ),
        // Search
        GoRoute(
          path: '/search',
          pageBuilder: (context, state) =>
              _buildPageWithTransition(state, const SearchScreen()),
        ),
        // Search Results
        GoRoute(
          path: '/search-result',
          pageBuilder: (context, state) =>
              _buildPageWithTransition(state, const SearchResultScreen()),
        ),
        // Mood
        GoRoute(
          path: '/mood/:params',
          pageBuilder: (context, state) {
            final params = Uri.decodeComponent(state.pathParameters['params'] ?? '');
            final title = state.extra as String? ?? 'Mood';
            return _buildPageWithTransition(
              state,
              MoodScreen(title: title, params: params),
            );
          },
        ),
        // YouTube Music
        GoRoute(
          path: '/youtube',
          pageBuilder: (context, state) =>
              _buildPageWithTransition(state, const YoutubeMusicScreen()),
          routes: [
            GoRoute(
              path: 'album/:id',
              pageBuilder: (context, state) {
                final id = Uri.decodeComponent(state.pathParameters['id'] ?? '');
                final extra = state.extra as Map<String, dynamic>? ?? {};
                return _buildPageWithTransition(state, YtAlbumScreen(
                  browseId: id,
                  title: extra['title'] ?? '',
                  thumbnailUrl: extra['thumbnailUrl'] ?? '',
                ));
              },
            ),
            GoRoute(
              path: 'artist/:id',
              pageBuilder: (context, state) {
                final id = Uri.decodeComponent(state.pathParameters['id'] ?? '');
                final extra = state.extra as Map<String, dynamic>? ?? {};
                return _buildPageWithTransition(state, YtArtistScreen(
                  channelId: id,
                  name: extra['name'] ?? '',
                  thumbnailUrl: extra['thumbnailUrl'] ?? '',
                ));
              },
            ),
            GoRoute(
              path: 'playlist/:id',
              pageBuilder: (context, state) {
                final id = Uri.decodeComponent(state.pathParameters['id'] ?? '');
                final extra = state.extra as Map<String, dynamic>? ?? {};
                return _buildPageWithTransition(state, YtPlaylistScreen(
                  playlistId: id,
                  title: extra['title'] ?? '',
                  thumbnailUrl: extra['thumbnailUrl'] ?? '',
                ));
              },
            ),
          ],
        ),
        // YouTube Music Library
        GoRoute(
          path: '/yt-library/playlists',
          pageBuilder: (context, state) =>
              _buildPageWithTransition(state, const YtLibraryScreen(type: YTLibraryType.playlists)),
        ),
        GoRoute(
          path: '/yt-library/albums',
          pageBuilder: (context, state) =>
              _buildPageWithTransition(state, const YtLibraryScreen(type: YTLibraryType.albums)),
        ),
        GoRoute(
          path: '/yt-library/artists',
          pageBuilder: (context, state) =>
              _buildPageWithTransition(state, const YtLibraryScreen(type: YTLibraryType.artists)),
        ),
        // Library
        GoRoute(
          path: '/library',
          pageBuilder: (context, state) =>
              _buildPageWithTransition(state, const LibraryScreen()),
        ),
        // Recently Played
        GoRoute(
          path: '/recently-played',
          pageBuilder: (context, state) =>
              _buildPageWithTransition(state, const RecentlyPlayedScreen()),
        ),
        // Most Played
        GoRoute(
          path: '/most-played',
          pageBuilder: (context, state) =>
              _buildPageWithTransition(state, const MostPlayedScreen()),
        ),
        // Recently Added
        GoRoute(
          path: '/recently-added',
          pageBuilder: (context, state) =>
              _buildPageWithTransition(state, const RecentlyAddedScreen()),
        ),
        // File Explorer
        GoRoute(
          path: '/explorer',
          pageBuilder: (context, state) =>
              _buildPageWithTransition(state, const FileExplorerScreen()),
          routes: [
            // Nested route for directory paths
            GoRoute(
              path: ':path',
              pageBuilder: (context, state) {
                final path = state.pathParameters['path'] ?? '';
                return _buildPageWithTransition(
                  state,
                  FileExplorerScreen(initialPath: path),
                );
              },
            ),
          ],
        ),
        // Playlists
        GoRoute(
          path: '/playlists',
          pageBuilder: (context, state) =>
              _buildPageWithTransition(state, const PlaylistsScreen()),
        ),
        // Artists
        GoRoute(
          path: '/artists',
          pageBuilder: (context, state) =>
              _buildPageWithTransition(state, const ArtistsScreen()),
          routes: [
            GoRoute(
              path: ':name',
              pageBuilder: (context, state) {
                final name = state.pathParameters['name'] ?? '';
                return _buildPageWithTransition(
                  state,
                  ArtistDetailScreen(artistName: name),
                );
              },
            ),
          ],
        ),
        // Albums
        GoRoute(
          path: '/albums',
          pageBuilder: (context, state) =>
              _buildPageWithTransition(state, const AlbumsScreen()),
          routes: [
            GoRoute(
              path: ':artist/:name',
              pageBuilder: (context, state) {
                final artist = state.pathParameters['artist'] ?? '';
                final name = state.pathParameters['name'] ?? '';
                return _buildPageWithTransition(
                  state,
                  AlbumDetailScreen(artistName: artist, albumName: name),
                );
              },
            ),
          ],
        ),
        // Playlist
        GoRoute(
          path: '/playlist/:id',
          pageBuilder: (context, state) {
            final playlistId = state.pathParameters['id'];
            final playlists = audioSignal.playlists.value;
            final index = playlists.indexWhere((p) => p.id == playlistId);
            if (index == -1) {
              // Playlist was deleted or ID is invalid — redirect to library
              return _buildPageWithTransition(state, const LibraryScreen());
            }
            return _buildPageWithTransition(
              state,
              PlaylistScreen(playlist: playlists[index]),
            );
          },
        ),
        // Settings
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              _buildPageWithTransition(state, const SettingsScreen()),
          routes: [
            GoRoute(
              path: 'customization',
              pageBuilder: (context, state) =>
                  _buildPageWithTransition(state, const CustomizationScreen()),
              routes: [
                GoRoute(
                  path: 'actions-layout',
                  pageBuilder: (context, state) => _buildPageWithTransition(
                    state,
                    const ActionsLayoutSection(),
                  ),
                ),
                GoRoute(
                  path: 'player-layout',
                  pageBuilder: (context, state) => _buildPageWithTransition(
                    state,
                    const PlayerBarLayoutSection(),
                  ),
                ),
                GoRoute(
                  path: 'lyrics-layout',
                  pageBuilder: (context, state) => _buildPageWithTransition(
                    state,
                    const LyricsAppearanceSection(),
                  ),
                ),
                GoRoute(
                  path: 'sidebar-layout',
                  pageBuilder: (context, state) => _buildPageWithTransition(
                    state,
                    const SidebarLayoutSection(),
                  ),
                ),
                GoRoute(
                  path: 'discord-presence',
                  pageBuilder: (context, state) => _buildPageWithTransition(
                    state,
                    const DiscordPresenceSection(),
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'playback',
              pageBuilder: (context, state) =>
                  _buildPageWithTransition(state, const PlaybackSection()),
            ),
            GoRoute(
              path: 'library',
              pageBuilder: (context, state) =>
                  _buildPageWithTransition(state, const LibrarySection()),
              routes: [
                GoRoute(
                  path: 'manage_cache',
                  pageBuilder: (context, state) =>
                      _buildPageWithTransition(state, const CacheManagementScreen()),
                ),
                GoRoute(
                  path: 'youtube-login',
                  pageBuilder: (context, state) =>
                      _buildPageWithTransition(state, const YtLoginWebViewScreen()),
                ),
              ],
            ),
            GoRoute(
              path: 'about',
              pageBuilder: (context, state) =>
                  _buildPageWithTransition(state, const AboutSection()),
            ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) =>
      Scaffold(body: Center(child: Text('Error: ${state.error}'))),
);

CustomTransitionPage _buildPageWithTransition(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: Curves.easeOutCubic,
          ),
        ),
        child: FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 400),
  );
}

void initNavigationListener() {
  // Seed initial location
  final initialLocation = router.routerDelegate.currentConfiguration.uri
      .toString();
  if (initialLocation.isNotEmpty) {
    navigationSignal.onRouteChanged(initialLocation);
  }

  // Use routeInformationProvider for the most up-to-date URI, since
  // currentConfiguration.uri can incorrectly report the parent shell
  // route for nested pages.
  router.routerDelegate.addListener(() {
    String location;
    try {
      location = router.routeInformationProvider.value.uri.toString();
    } catch (_) {
      location = router.routerDelegate.currentConfiguration.uri.toString();
    }
    navigationSignal.onRouteChanged(location);
  });
}
