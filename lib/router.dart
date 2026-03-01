import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_shell.dart';
import 'screens/file_explorer_screen.dart';
import 'screens/playlist_screen.dart';
import 'screens/playlists_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/search_screen.dart';
import 'screens/library_screen.dart';
import 'screens/home_screen.dart';
import 'screens/recently_played_screen.dart';
import 'screens/recently_added_screen.dart';
import 'widgets/songs_list_content.dart';
import 'signals/audio_signal.dart';
import 'signals/navigation_signal.dart';
import 'screens/settings/appearance_section.dart';
import 'screens/settings/playback_section.dart';
import 'screens/settings/library_section.dart';
import 'screens/settings/about_section.dart';

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
                final path = Uri.decodeComponent(
                  state.pathParameters['path'] ?? '',
                );
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
              path: 'appearance',
              pageBuilder: (context, state) =>
                  _buildPageWithTransition(state, const AppearanceSection()),
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

  router.routerDelegate.addListener(() {
    final location = router.routerDelegate.currentConfiguration.uri.toString();
    navigationSignal.onRouteChanged(location);
  });
}
