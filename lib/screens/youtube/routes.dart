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
import '../youtube_music_screen.dart';
import '../yt_album_screen.dart';
import '../yt_artist_screen.dart';
import '../yt_playlist_screen.dart';
import '../search/yt_library_screen.dart';

List<GoRoute> get youtubeRoutes => [
  GoRoute(
    path: AppRoutes.youtube,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const YoutubeMusicScreen()),
  ),
  GoRoute(
    path: '${AppRoutes.youtube}/album/:id',
    pageBuilder: (context, state) {
      final id = Uri.decodeComponent(state.pathParameters['id'] ?? '');
      final extra = state.extra as Map<String, dynamic>? ?? {};
      return buildPageWithTransition(state, YtAlbumScreen(
        browseId: id,
        title: extra['title'] ?? '',
        thumbnailUrl: extra['thumbnailUrl'] ?? '',
      ));
    },
  ),
  GoRoute(
    path: '${AppRoutes.youtube}/artist/:id',
    pageBuilder: (context, state) {
      final id = Uri.decodeComponent(state.pathParameters['id'] ?? '');
      final extra = state.extra as Map<String, dynamic>? ?? {};
      return buildPageWithTransition(state, YtArtistScreen(
        channelId: id,
        name: extra['name'] ?? '',
        thumbnailUrl: extra['thumbnailUrl'] ?? '',
      ));
    },
  ),
  GoRoute(
    path: '${AppRoutes.youtube}/playlist/:id',
    pageBuilder: (context, state) {
      final id = Uri.decodeComponent(state.pathParameters['id'] ?? '');
      final extra = state.extra as Map<String, dynamic>? ?? {};
      return buildPageWithTransition(state, YtPlaylistScreen(
        playlistId: id,
        title: extra['title'] ?? '',
        thumbnailUrl: extra['thumbnailUrl'] ?? '',
      ));
    },
  ),
  GoRoute(
    path: AppRoutes.ytLibraryPlaylists,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const YtLibraryScreen(type: YTLibraryType.playlists)),
  ),
  GoRoute(
    path: AppRoutes.ytLibraryAlbums,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const YtLibraryScreen(type: YTLibraryType.albums)),
  ),
  GoRoute(
    path: AppRoutes.ytLibraryArtists,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const YtLibraryScreen(type: YTLibraryType.artists)),
  ),
];
