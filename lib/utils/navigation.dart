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

/// Replacement-style navigation. Skips when the target equals the
/// current location so the router stack and NavigationSignal back-history
/// do not grow with redundant entries.
void navigateGo(BuildContext context, String location, {Object? extra}) {
  final current = GoRouterState.of(context).uri.toString();
  if (current == location) return;
  if (extra != null) {
    context.go(location, extra: extra);
  } else {
    context.go(location);
  }
}

/// Push-style navigation. Skips when the target is already the top of
/// the stack to avoid duplicate pages.
void navigatePush(BuildContext context, String location, {Object? extra}) {
  final router = GoRouter.of(context);
  final lastSegment = router.routerDelegate.currentConfiguration.uri.toString();
  if (lastSegment == location) return;
  if (extra != null) {
    context.push(location, extra: extra);
  } else {
    context.push(location);
  }
}
