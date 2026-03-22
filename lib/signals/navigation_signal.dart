import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';

/// Unified navigation history system.
/// Records all visited pages in a single list with a position pointer.
/// Pages can appear multiple times but not consecutively.
/// Example: /Home → /Library → /Settings → /Library → /Folders → /Home
class NavigationSignal {
  static const int _maxHistorySize = 50;

  static final NavigationSignal _instance = NavigationSignal._internal();
  factory NavigationSignal() => _instance;
  NavigationSignal._internal();

  // Single history list (Source of Truth)
  final List<String> _history = ['/'];

  // Position signal (UI Trigger)
  final _position = signal<int>(0);

  // External signals for UI binding
  late final canGoBack = computed(() => _position.value > 0);
  late final canGoForward = computed(
    () => _position.value < _history.length - 1,
  );
  late final currentRoute = computed(() => _history[_position.value]);

  /// Check if we can go back (for synchronous PopScope canPop).
  bool get canPopSync => _position.value > 0;

  // Manual navigation state
  bool _isLocked = false;
  String? _targetRoute;
  DateTime? _lastManualNavTime;

  /// Helper to normalize routes
  String _normalize(String route) {
    if (route == '/' || route.isEmpty) return '/';
    String result = route;
    if (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  /// Called when GoRouter reports a location change.
  void onRouteChanged(String newRoute) {
    final normalized = _normalize(newRoute);

    // 1. GLOBAL LOCK: If we just performed a manual BACK/FORWARD,
    // ignore ALL events for 500ms to allow the router and OS to settle.
    if (_isLocked) {
      if (normalized == _targetRoute) {
        _isLocked = false;
        _targetRoute = null;
        _lastManualNavTime = DateTime.now();
      }
      return;
    }

    // 2. COOLDOWN: Protect against late "stale" events immediately after lock.
    if (_lastManualNavTime != null) {
      final elapsed = DateTime.now().difference(_lastManualNavTime!);
      if (elapsed < const Duration(milliseconds: 150)) {
        return;
      }
      // Cooldown expired, clear it so we stop checking
      _lastManualNavTime = null;
    }

    final current = _history[_position.value];
    if (normalized == current) return;

    // 3. COLLAPSE: If navigating to the route that is immediately behind us
    // in history (e.g. /settings/appearance → /settings where /settings is
    // already at position-1), treat it as a "go back" instead of a new entry.
    // This prevents loops like /settings → /settings/appearance → /settings → ...
    if (_position.value > 0 && _history[_position.value - 1] == normalized) {
      // Remove current entry and move position back
      _history.removeAt(_position.value);
      _position.value--;
      return;
    }

    // 4. NEW NAVIGATION: User clicked a link or typed a URL.
    // Standard browser behavior: new navigation clears forward history.
    if (_position.value < _history.length - 1) {
      _history.removeRange(_position.value + 1, _history.length);
    }

    _history.add(normalized);
    _position.value = _history.length - 1;

    // Cap history size to prevent unbounded growth
    if (_history.length > _maxHistorySize) {
      final excess = _history.length - _maxHistorySize;
      _history.removeRange(0, excess);
      _position.value = _history.length - 1;
    }
  }

  /// Navigate programmatically
  void navigateTo(BuildContext context, String route) {
    final normalized = _normalize(route);
    if (normalized == currentRoute.value) return;
    context.go(normalized);
  }

  /// Go back in history
  void goBack(BuildContext context) {
    if (!canPopSync || _isLocked) return;

    _position.value--;
    final target = _history[_position.value];

    _isLocked = true;
    _targetRoute = target;

    context.go(target);

    // Safety timeout to prevent permanent lock
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (_isLocked && _targetRoute == target) {
        _isLocked = false;
        _targetRoute = null;
      }
    });
  }

  /// Go forward in history
  void goForward(BuildContext context) {
    if (_position.value >= _history.length - 1 || _isLocked) return;

    _position.value++;
    final target = _history[_position.value];

    _isLocked = true;
    _targetRoute = target;

    context.go(target);

    // Safety timeout
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (_isLocked && _targetRoute == target) {
        _isLocked = false;
        _targetRoute = null;
      }
    });
  }

  /// Clear history and reset to home.
  void clear() {
    _history.clear();
    _history.add('/');
    _position.value = 0;
  }

  /// Debug: Get history as string
  String get historyDebugString => _history.join(' -> ');
}

final navigationSignal = NavigationSignal();
