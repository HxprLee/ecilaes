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
import '../services/navigation/back_handler.dart';

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

  /// True when there is a real "previous" entry to navigate to. The seeded
  /// home root `/` counts as position 0, not as a navigable target — the
  /// back button only lights up once the user has moved past home.
  bool get canGoBack => _backCount.value > 1;
  bool get canGoForward => _forwardCount.value > 0;

  /// Records a navigation event. Call from a listener on
  /// `GoRouter.routerDelegate` so the stack follows the live URL.
  ///
  /// When the location already exists in the back-stack (back-navigation
  /// via system back or GoRouter.pop), trims everything after the existing
  /// entry instead of adding a duplicate — this handles the PopScope path
  /// where recordPop cannot run before the listener fires.
  ///
  /// Consecutive duplicates (same location as last entry) are still skipped
  /// to handle immediate re-navigation to the current URL.
  void recordVisit(String location) {
    if (location.isEmpty) return;

    // Consecutive duplicate — no-op.
    if (_backStack.isNotEmpty && _backStack.last == location) return;

    // Back-navigation: location already exists in the stack.
    // Trim everything after it instead of adding a new entry.
    final existingIndex = _backStack.lastIndexOf(location);
    if (existingIndex != -1 && existingIndex < _backStack.length - 1) {
      _backStack.removeRange(existingIndex + 1, _backStack.length);
      _backCount.value = _backStack.length;
      return;
    }

    // Forward navigation to new location — clear forward stack and add.
    _forwardStack.clear();
    _forwardCount.value = 0;
    _backStack.add(location);
    _backCount.value = _backStack.length;
  }

  /// Removes [location] from the back-stack and moves it to the forward-stack.
  /// Use this when a navigation gesture pops a screen (e.g. `GoRouter.pop`
  /// unwinds a `push`) so the back-stack mirrors the visible state and the
  /// forward-stack keeps a record of the popped screen for later re-entry.
  void recordPop(String location) {
    final index = _backStack.lastIndexOf(location);
    if (index == -1) return;
    if (index != _backStack.length - 1) {
      // Drop intermediate entries above the popped location — they no
      // longer reflect the visible state after the pop.
      _backStack.removeRange(index + 1, _backStack.length);
    } else {
      _backStack.removeLast();
    }
    _forwardStack.add(location);
    _backCount.value = _backStack.length;
    _forwardCount.value = _forwardStack.length;
  }

  /// Step back. Returns `true` if a navigation actually happened.
  ///
  /// Delegates to [AppBackHandler] first so the priority list (minimize
  /// player, close overlay, pop pushed route, history pop) is honoured.
  /// Falls back to [stepBack] when the handler has nothing to do.
  bool goBack(BuildContext context) {
    final result = appBackHandler.invoke(context);
    if (result.handled) return true;
    return stepBack(context);
  }

  /// Pop the local back-stack directly, without re-entering [AppBackHandler].
  /// The handler's `NavigationSignal`-aware step must not call `goBack` here
  /// or the two methods recurse forever.
  ///
  /// The home route `/` is the absolute root and is permanently seeded into
  /// the back-stack at init time; pressing back while at home is a no-op so
  /// the root entry survives future visits. Any single-entry stack is also
  /// a no-op — the desktop shell has no "previous page" to fall back to.
  bool stepBack(BuildContext context) {
    if (_backStack.isEmpty) return false;
    if (_backStack.length == 1) return false;

    final goRouter = GoRouter.of(context);

    final popped = _backStack.removeLast();
    _backCount.value = _backStack.length;
    _forwardStack.add(popped);
    _forwardCount.value = _forwardStack.length;
    goRouter.go(_backStack.last);
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

  // --- Debug accessors ---
  List<String> get backStack => List.unmodifiable(_backStack);
  List<String> get forwardStack => List.unmodifiable(_forwardStack);
}

/// Singleton consumed by header buttons and anywhere else that needs to
/// drive the back/forward UI.
final NavigationSignal navigationSignal = NavigationSignal();
