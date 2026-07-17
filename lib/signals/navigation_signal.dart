// Ecilaes - Cross-platform music player
// Copyright (C) 2024  hxprlee
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';

/// In-memory back/forward history used by the desktop header's nav buttons.
///
/// `go_router` resets its stack on every `context.go(...)`, so we keep our
/// own lists of past and future URIs and reactively expose `canGoBack` /
/// `canGoForward` for the UI.
class NavigationSignal {
  final List<String> _backStack = [];
  final List<String> _forwardStack = [];

  final Signal<int> _backCount = signal(0);
  final Signal<int> _forwardCount = signal(0);

  bool get canGoBack => _backCount.value > 0;
  bool get canGoForward => _forwardCount.value > 0;

  /// Records a navigation event. Call from a listener on
  /// `GoRouter.routerDelegate` so the stack follows the live URL.
  ///
  /// Equal/consecutive visits and `go`-style replacement of the current
  /// location are flattened so the stacks stay useful. A revisited location
  /// already present anywhere in the back-stack is collapsed to a single
  /// entry, preventing cycles such as A,B,A from accumulating.
  void recordVisit(String location) {
    if (location.isEmpty) return;

    if (_backStack.isNotEmpty && _backStack.last == location) {
      // Same location re-emitted by the delegate listener — ignore.
      return;
    }

    // A new visit invalidates any forward history.
    if (_forwardStack.isNotEmpty) {
      _forwardStack.clear();
      _forwardCount.value = 0;
    }

    // Drop any earlier occurrence of this location so the back-stack
    // never contains a cycle (e.g. A,B,A collapses to B,A).
    final existing = _backStack.indexOf(location);
    if (existing != -1) {
      _backStack.removeAt(existing);
    }

    _backStack.add(location);
    _backCount.value = _backStack.length;
  }

  /// Step back. Returns `true` if a navigation actually happened.
  bool goBack(BuildContext context) {
    if (_backStack.length <= 1) return false;
    final router = GoRouter.of(context);
    final current = _backStack.removeLast();
    _backCount.value = _backStack.length;
    final target = _backStack.last;
    _forwardStack.add(current);
    _forwardCount.value = _forwardStack.length;
    router.go(target);
    return true;
  }

  /// Step forward. Returns `true` if a navigation actually happened.
  bool goForward(BuildContext context) {
    if (_forwardStack.isEmpty) return false;
    final router = GoRouter.of(context);
    final target = _forwardStack.removeLast();
    _forwardCount.value = _forwardStack.length;
    _backStack.add(target);
    _backCount.value = _backStack.length;
    router.go(target);
    return true;
  }

  /// Reset stacks. Called once at startup from `initNavigationListener`.
  void clear() {
    _backStack.clear();
    _forwardStack.clear();
    _backCount.value = 0;
    _forwardCount.value = 0;
  }
}

/// Singleton consumed by header buttons and anywhere else that needs to
/// drive the back/forward UI.
final NavigationSignal navigationSignal = NavigationSignal();
