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
import 'search_screen.dart';
import 'search_result_screen.dart';
import 'see_more_screen.dart';
import 'mood_screen.dart';

List<GoRoute> get searchRoutes => [
  GoRoute(
    path: AppRoutes.search,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const SearchScreen()),
  ),
  GoRoute(
    path: AppRoutes.searchResult,
    pageBuilder: (context, state) =>
        buildPageWithTransition(state, const SearchResultScreen()),
  ),
  GoRoute(
    path: AppRoutes.seeMore,
    redirect: (context, state) {
      // The see-more screen requires a sectionKey in `extra` to render.
      // Without it, fall back to the search screen rather than crashing.
      final extra = state.extra;
      if (extra is! Map<String, dynamic>) return AppRoutes.search;
      final key = extra['sectionKey'];
      if (key is! String || key.isEmpty) return AppRoutes.search;
      return null;
    },
    pageBuilder: (context, state) {
      final extra = state.extra as Map<String, dynamic>;
      return buildPageWithTransition(
        state,
        SeeMoreScreen(
          sectionKey: extra['sectionKey'] as String,
          title: extra['title'] as String? ?? 'More',
        ),
      );
    },
  ),
  GoRoute(
    path: '${AppRoutes.mood}/:params',
    pageBuilder: (context, state) {
      final params = Uri.decodeComponent(state.pathParameters['params'] ?? '');
      final title = state.extra as String? ?? 'Mood';
      return buildPageWithTransition(
        state,
        MoodScreen(title: title, params: params),
      );
    },
  ),
];
