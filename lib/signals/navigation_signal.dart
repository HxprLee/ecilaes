import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';

/// Unified navigation history system.
/// Records all visited pages in a single list with a position pointer.
/// Pages can appear multiple times but not consecutively.
/// Example: /Home → /Library → /Settings → /Library → /Folders → /Home
class NavigationSignal {
  static final NavigationSignal _instance = NavigationSignal._internal();
  factory NavigationSignal() => _instance;
  NavigationSignal._internal() {
    // Initialize with home route
    _history.add('/');
  }

  // Single history list tracking all visited pages
  final _history = listSignal<String>([]);

  // Current position in history (0-indexed)
  final _position = signal<int>(0);

  // Computed signals for UI binding
  late final canGoBack = computed(() => _position.value > 0);
  late final canGoForward = computed(
    () => _position.value < _history.value.length - 1,
  );

  // Current route (for convenience)
  late final currentRoute = computed(() {
    if (_history.value.isEmpty) return '/';
    return _history.value[_position.value];
  });

  /// Check if we can go back (for synchronous PopScope canPop).
  bool get canPopSync => _position.value > 0;

  /// Called when user navigates to a new page (e.g. via UI click or deep link).
  /// Adds to history if not the same as current page.
  void onRouteChanged(String newRoute) {
    final current = currentRoute.value;

    // Don't add consecutive duplicates
    if (newRoute == current) return;

    // If we're not at the end of history, truncate forward history
    // This implements standard browser behavior: new navigation clears forward history
    if (_position.value < _history.value.length - 1) {
      _history.value = _history.value.sublist(0, _position.value + 1);
    }

    // Add new route to history
    _history.add(newRoute);
    _position.value = _history.value.length - 1;

    print('History updated: $historyDebugString (Pos: ${_position.value})');
  }

  /// Navigate to a route programmatically.
  void navigateTo(BuildContext context, String route) {
    if (route == currentRoute.value) return;
    context.go(route);
  }

  /// Navigate back in history.
  void goBack(BuildContext context) {
    if (!canPopSync) return;

    _position.value--;
    final route = _history.value[_position.value];

    context.go(route);
    print('Went back to: $route (Pos: ${_position.value})');
  }

  /// Navigate forward in history.
  void goForward(BuildContext context) {
    if (_position.value >= _history.value.length - 1) return;

    _position.value++;
    final route = _history.value[_position.value];

    context.go(route);
    print('Went forward to: $route (Pos: ${_position.value})');
  }

  /// Clear history and reset to home.
  void clear() {
    _history.value = ['/'];
    _position.value = 0;
  }

  /// Debug: Get history as string (e.g., "/Home/Library/Settings")
  String get historyDebugString => _history.value.join(' -> ');
}

/// Navigator observer that syncs route changes with NavigationSignal.
class NavigationObserver extends NavigatorObserver {
  final NavigationSignal _signal;

  NavigationObserver(this._signal);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _updateRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _updateRoute(newRoute);
    }
  }

  void _updateRoute(Route<dynamic> route) {
    final routeName = route.settings.name;
    // GoRouter sometimes sends null names, check path if possible or ensure routes have names
    // For ShellRoutes, we might not get good names.
    // Ideally we rely on the path from GoRouterState, but observer gives us Routes.
    // Let's assume our GoRoutes have paths or we can trust the name if set,
    // or we might need to rely on GoRouterState change listener instead of Observer.
    if (routeName != null && routeName.isNotEmpty) {
      _signal.onRouteChanged(routeName);
    } else {
      // Fallback: This might be an issue if RouteSettings.name is not set.
      // GoRouter usually sets location as name if not specified?
      // Actually GoRouter uses 'path' or 'name' params.
    }
  }
}

final navigationSignal = NavigationSignal();
