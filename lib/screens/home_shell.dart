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

class _HomeShellState extends State<HomeShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _playerKey = GlobalKey();
  bool _isSidebarCollapsed = false;
  double? _lastWidth;

  bool get isDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
  bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

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
    const selectedColor = Color(0xFFFCE7AC);
    const unselectedColor = Colors.white54;
    const indicatorColor = Color(0xFFFCE7AC);

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
                color: isSelected ? const Color(0xFF11171C) : unselectedColor,
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

    // Dimensions
    const collapsedWidth = 70.0 + 16.0; // 70 width + 16 margin
    const expandedWidth = 250.0 + 16.0; // 250 width + 16 margin

    // Calculate content left offset
    double contentLeftOffset;
    if (isMobile) {
      contentLeftOffset = 0;
    } else if (isSmallScreen) {
      // Small screen: content always offset by collapsed width
      contentLeftOffset = collapsedWidth;
    } else {
      // Large screen: content offset depends on sidebar state
      contentLeftOffset = _isSidebarCollapsed ? collapsedWidth : expandedWidth;
    }

    final topPadding = MediaQuery.of(context).padding.top;
    final headerHeight = isMobile ? (64.0 + topPadding) : 74.0;

    return Watch((context) {
      final canGoBack = navigationSignal.canGoBack.value;
      final currentRoute = navigationSignal.currentRoute.value;

      return PopScope(
        canPop: !canGoBack,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;

          // Use navigation signal to go back
          if (canGoBack) {
            navigationSignal.goBack(context);
          }
        },
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
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
                // Main Content (from router)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  left: contentLeftOffset,
                  top: 0, // Allow content to scroll behind header
                  right: 0,
                  bottom: 0,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollUpdateNotification) {
                        final metrics = notification.metrics;
                        if (metrics.axis == Axis.vertical) {
                          audioSignal.headerShowBlur.value = metrics.pixels > 0;
                        }
                      }
                      return false;
                    },
                    child: widget.child,
                  ),
                ),

                // Title Bar (Always visible now, layout handled internally)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  top: 0,
                  left: 0,
                  right: 0,
                  height:
                      headerHeight, // Match design height + SafeArea on mobile
                  child: WindowTitleBar(leftOffset: contentLeftOffset),
                ),

                if (kDebugMode && isMobile)
                  Positioned(
                    top: 100,
                    left: 10,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.black54,
                        child: Text(
                          'Route: $currentRoute\nBack: $canGoBack\n${navigationSignal.historyDebugString}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Sidebar and MorphingPlayer with dynamic Z-index
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
                    // Compact height to minimize internal padding
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
                                            filter: ImageFilter.blur(
                                              sigmaX: 20,
                                              sigmaY: 20,
                                            ),
                                            child: Container(
                                              height: mobileNavBarHeight,
                                              padding: EdgeInsets.only(
                                                bottom: bottomPadding,
                                              ),
                                              color: const Color(
                                                0xFF11171C,
                                              ).withValues(alpha: 0.9),
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
                                                    null, // TODO
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
                      children: isExpanded
                          ? [sidebar, player, bottomNavBar]
                          : [player, sidebar, bottomNavBar],
                    );
                  }),
                ),

                // Scanning Indicator
                Positioned(
                  top: 16,
                  right: 16,
                  child: Watch((context) {
                    if (audioSignal.isScanning.value) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFCE7AC),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Scanning...',
                              style: TextStyle(
                                color: Color(0xFFFCE7AC),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ),
              ],
            ),
            bottomNavigationBar: null,
          ),
        ),
      );
    });
  }
}
