import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../widgets/sidebar.dart';
import '../widgets/morphing_player.dart';
import '../widgets/window_title_bar.dart';
import '../signals/audio_signal.dart';
import '../signals/navigation_signal.dart';
import '../signals/settings_signal.dart';

/// Shell widget that wraps all routes with common UI elements:
/// - Sidebar (desktop)
/// - MorphingPlayer (bottom bar)
/// - BottomNavigationBar (mobile)
class HomeShell extends StatefulWidget {
  final Widget child;

  const HomeShell({super.key, required this.child});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _playerKey = GlobalKey();
  bool _isSidebarCollapsed = false;
  double? _lastWidth;
  String? _lastLocation;

  bool get isDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
  bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (isDesktop) {
      final width = MediaQuery.of(context).size.width;

      if (_lastWidth == null) {
        // Initial state
        _isSidebarCollapsed = width < 1200;
      } else {
        // Handle breakpoint changes
        if (_lastWidth! >= 1200 && width < 1200) {
          _isSidebarCollapsed = true;
        } else if (_lastWidth! < 1200 && width >= 1200) {
          _isSidebarCollapsed = false;
        }
      }
      _lastWidth = width;
    }
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  int _getSelectedIndex(String location) {
    if (location == '/') return 0;
    if (location.startsWith('/library')) return 2;
    if (location.startsWith('/explorer')) return 2;
    if (location.startsWith('/playlist')) return 2;
    return -1;
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    String? route,
    String currentLocation,
    int index,
  ) {
    final isSelected = _getSelectedIndex(currentLocation) == index;
    final selectedColor = Theme.of(context).colorScheme.secondary;
    final unselectedColor = Theme.of(
      context,
    ).colorScheme.onSurface.withOpacity(0.54);
    final indicatorColor = Theme.of(context).colorScheme.secondary;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: route != null ? () => context.go(route) : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? indicatorColor : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: FaIcon(
                icon,
                size: 20,
                color: isSelected
                    ? Theme.of(context).colorScheme.surface
                    : unselectedColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? selectedColor : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1000;
    final location = GoRouterState.of(context).uri.toString();

    // Reset header signals on navigation
    if (_lastLocation != location) {
      _lastLocation = location;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        audioSignal.headerShowBlur.value = false;
        audioSignal.headerTitleProgress.value = 0.0;
        audioSignal.headerArtCover.value = null;
      });
    }

    // Dimensions
    const collapsedWidth = 70.0 + 16.0;
    const expandedWidth = 250.0 + 16.0;

    // Calculate content left offset
    double contentLeftOffset;
    if (isMobile) {
      contentLeftOffset = 0;
    } else if (isSmallScreen) {
      contentLeftOffset = collapsedWidth;
    } else {
      contentLeftOffset = _isSidebarCollapsed ? collapsedWidth : expandedWidth;
    }

    final topPadding = MediaQuery.of(context).padding.top;
    final headerHeight = isMobile ? (64.0 + topPadding) : 80.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Watch((context) {
        // Sync bottom padding to audio signal for dynamic spacing
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        if (audioSignal.bottomPadding.value != bottomPadding) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            audioSignal.bottomPadding.value = bottomPadding;
          });
        }

        return PopScope(
          canPop: !navigationSignal.canGoBack.value &&
              audioSignal.playerExpansion.value < 0.001,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;

            final expansion = audioSignal.playerExpansion.value;
            final canGoBack = navigationSignal.canGoBack.value;

            // 1. Priority: If player is even SLIGHTLY open, minimize it first
            if (expansion > 0.001) {
              audioSignal.minimizePlayerTrigger.value++;
              return;
            }

            // 2. Priority: Only if player is fully closed, go back in history
            if (canGoBack) {
              navigationSignal.goBack(context);
            }
          },
          child: Scaffold(
            key: _scaffoldKey,
            extendBody: true,
            drawer: isMobile
                ? Drawer(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    width: 250 + 16,
                    child: Sidebar(
                      isCollapsed: false,
                      onToggle: () {},
                      isDrawer: true,
                    ),
                  )
                : null,
            body: Stack(
              children: [
                // Main Content
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  left: contentLeftOffset,
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollUpdateNotification) {
                        final metrics = notification.metrics;
                        if (metrics.axis == Axis.vertical) {
                          audioSignal.headerShowBlur.value = metrics.pixels > 0;
                          // Map scroll 0–80px to progress 0.0–1.0 for title morph
                          final progress = (metrics.pixels / 80.0).clamp(
                            0.0,
                            1.0,
                          );
                          audioSignal.headerTitleProgress.value = progress;
                        }
                      } else if (notification is ScrollEndNotification) {
                        // Ensure progress is updated on scroll end too
                        final metrics = notification.metrics;
                        if (metrics.axis == Axis.vertical) {
                          final progress = (metrics.pixels / 80.0).clamp(
                            0.0,
                            1.0,
                          );
                          audioSignal.headerTitleProgress.value = progress;
                        }
                      }
                      return false;
                    },
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context),
                      child: widget.child,
                    ),
                  ),
                ),

                // Title Bar
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  top: 0,
                  left: 0,
                  right: 0,
                  height: headerHeight,
                  child: WindowTitleBar(leftOffset: contentLeftOffset),
                ),

                if (kDebugMode && isMobile)
                  Watch(
                    (context) => Positioned(
                      top: 100,
                      left: 10,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.black54,
                          child: Text(
                            'Route: ${navigationSignal.currentRoute.value}\nBack: ${navigationSignal.canGoBack.value}\n${navigationSignal.historyDebugString}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Sidebar and MorphingPlayer
                Positioned.fill(
                  child: Watch((context) {
                    final expansion = audioSignal.playerExpansion.value;
                    final isExpanded = expansion >= 0.5;

                    final sidebar = !isMobile
                        ? Positioned(
                            key: const ValueKey('sidebar'),
                            left: 0,
                            top: 0,
                            bottom: 0,
                            child: Sidebar(
                              isCollapsed: _isSidebarCollapsed,
                              onToggle: _toggleSidebar,
                            ),
                          )
                        : const SizedBox.shrink();

                    final bottomPadding = MediaQuery.of(context).padding.bottom;
                    const navBarHeight = 56.0;
                    final mobileNavBarHeight = navBarHeight + bottomPadding;

                    final player = MorphingPlayer(
                      key: _playerKey,
                      leftOffset: contentLeftOffset,
                      bottomOffset: isMobile ? mobileNavBarHeight : 0.0,
                    );

                    final bottomNavBar = isMobile
                        ? Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Watch((context) {
                              final expansion =
                                  audioSignal.playerExpansion.value;
                              return Transform.translate(
                                offset: Offset(
                                  0,
                                  expansion * mobileNavBarHeight,
                                ),
                                child: Opacity(
                                  opacity: (1 - expansion * 2).clamp(0.0, 1.0),
                                  child: expansion > 0.8
                                      ? const SizedBox.shrink()
                                      : ClipRRect(
                                          child: BackdropFilter(
                                            filter:
                                                settingsSignal
                                                    .enableGlobalBlur
                                                    .value
                                                ? ImageFilter.blur(
                                                    sigmaX: 20,
                                                    sigmaY: 20,
                                                  )
                                                : ImageFilter.blur(
                                                    sigmaX: 0,
                                                    sigmaY: 0,
                                                  ),
                                            child: Container(
                                              height: mobileNavBarHeight,
                                              padding: EdgeInsets.only(
                                                bottom: bottomPadding,
                                              ),
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surface
                                                  .withValues(
                                                    alpha:
                                                        settingsSignal
                                                            .enableGlobalBlur
                                                            .value
                                                        ? 0.9
                                                        : 1.0,
                                                  ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceAround,
                                                children: [
                                                  _buildNavItem(
                                                    context,
                                                    FontAwesomeIcons.solidHouse,
                                                    'Home',
                                                    '/',
                                                    location,
                                                    0,
                                                  ),
                                                  _buildNavItem(
                                                    context,
                                                    FontAwesomeIcons.youtube,
                                                    'YouTube',
                                                    null,
                                                    location,
                                                    1,
                                                  ),
                                                  _buildNavItem(
                                                    context,
                                                    FontAwesomeIcons
                                                        .recordVinyl,
                                                    'Library',
                                                    '/library',
                                                    location,
                                                    2,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              );
                            }),
                          )
                        : const SizedBox.shrink();

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (isExpanded) ...[
                          sidebar,
                          player,
                          bottomNavBar,
                        ] else ...[
                          player,
                          sidebar,
                          bottomNavBar,
                        ],
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

