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
import '../library_screen.dart';
import '../albums_screen.dart';
import '../album_detail_screen.dart';
import '../artists_screen.dart';
import '../artist_detail_screen.dart';
import '../playlists_screen.dart';
import '../playlist_screen.dart';
import '../file_explorer_screen.dart';
import '../recently_played_screen.dart';
import '../recently_added_screen.dart';
import '../most_played_screen.dart';
import '../../widgets/songs_list_content.dart';
import '../../signals/audio_signal.dart';

List<GoRoute> get libraryRoutes => [
  GoRoute(
    path: AppRoutes.songs,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const SongsListContent()),
  ),
  GoRoute(
    path: AppRoutes.library,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const LibraryScreen()),
  ),
  GoRoute(
    path: AppRoutes.recentlyPlayed,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const RecentlyPlayedScreen()),
  ),
  GoRoute(
    path: AppRoutes.mostPlayed,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const MostPlayedScreen()),
  ),
  GoRoute(
    path: AppRoutes.recentlyAdded,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const RecentlyAddedScreen()),
  ),
  GoRoute(
    path: AppRoutes.explorer,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const FileExplorerScreen()),
  ),
  GoRoute(
    path: '${AppRoutes.explorer}/:path',
    pageBuilder: (context, state) {
      final path = state.pathParameters['path'] ?? '';
      return buildPageWithTransition(
        state,
        FileExplorerScreen(initialPath: path),
      );
    },
  ),
  GoRoute(
    path: AppRoutes.playlists,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const PlaylistsScreen()),
  ),
  GoRoute(
    path: '/playlist/:id',
    redirect: (context, state) {
      final playlistId = state.pathParameters['id'];
      if (playlistId == null) return AppRoutes.library;
      final playlists = audioSignal.playlists.value;
      final index = playlists.indexWhere((p) => p.id == playlistId);
      if (index == -1) return AppRoutes.library;
      return null;
    },
    pageBuilder: (context, state) {
      final playlistId = state.pathParameters['id']!;
      final playlists = audioSignal.playlists.value;
      final index = playlists.indexWhere((p) => p.id == playlistId);
      return buildPageWithTransition(
        state,
        PlaylistScreen(playlist: playlists[index]),
      );
    },
  ),
  GoRoute(
    path: AppRoutes.artists,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const ArtistsScreen()),
  ),
  GoRoute(
    path: '${AppRoutes.artists}/:name',
    pageBuilder: (context, state) {
      final name = state.pathParameters['name'] ?? '';
      return buildPageWithTransition(
        state,
        ArtistDetailScreen(artistName: name),
      );
    },
  ),
  GoRoute(
    path: AppRoutes.albums,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const AlbumsScreen()),
  ),
  GoRoute(
    path: '${AppRoutes.albums}/:artist/:name',
    pageBuilder: (context, state) {
      final artist = state.pathParameters['artist'] ?? '';
      final name = state.pathParameters['name'] ?? '';
      return buildPageWithTransition(
        state,
        AlbumDetailScreen(artistName: artist, albumName: name),
      );
    },
  ),
];
