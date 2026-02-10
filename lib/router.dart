import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_shell.dart';
import 'screens/file_explorer_screen.dart';
import 'screens/playlist_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/search_screen.dart';
import 'screens/library_screen.dart';
import 'screens/home_screen.dart';
import 'widgets/songs_list_content.dart';
import 'signals/audio_signal.dart';
import 'signals/navigation_signal.dart';

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
              const NoTransitionPage(child: HomeScreen()),
        ),
        // Songs list
        GoRoute(
          path: '/songs',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SongsListContent()),
        ),
        // Search
        GoRoute(
          path: '/search',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SearchScreen()),
        ),
        // Library
        GoRoute(
          path: '/library',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: LibraryScreen()),
        ),
        // File Explorer
        GoRoute(
          path: '/explorer',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: FileExplorerScreen()),
          routes: [
            // Nested route for directory paths
            GoRoute(
              path: ':path',
              pageBuilder: (context, state) {
                final path = Uri.decodeComponent(
                  state.pathParameters['path'] ?? '',
                );
                return NoTransitionPage(
                  child: FileExplorerScreen(initialPath: path),
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
            final playlist = audioSignal.playlists.value.firstWhere(
              (p) => p.id == playlistId,
              orElse: () => throw Exception('Playlist not found'),
            );
            return NoTransitionPage(child: PlaylistScreen(playlist: playlist));
          },
        ),
        // Settings
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SettingsScreen()),
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) =>
      Scaffold(body: Center(child: Text('Error: ${state.error}'))),
);

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
