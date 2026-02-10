import 'dart:io';
import 'dart:ui';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import 'package:window_manager/window_manager.dart';
import '../signals/audio_signal.dart';
import '../signals/settings_signal.dart';
import '../signals/navigation_signal.dart';

class WindowTitleBar extends StatefulWidget {
  final double leftOffset;
  const WindowTitleBar({super.key, this.leftOffset = 0});

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends State<WindowTitleBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: audioSignal.searchQuery.value,
    );

    // Sync controller with signal
    effect(() {
      final query = audioSignal.searchQuery.value;
      if (_searchController.text != query) {
        _searchController.text = query;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

    return Watch((context) {
      final expansion = audioSignal.playerExpansion.value;
      final hideContentOpacity = (1 - expansion * 2).clamp(0.0, 1.0);
      // Only show blur if not expanded and scroll is active
      final showBlur = audioSignal.headerShowBlur.value && expansion < 0.1;
      final topPadding = MediaQuery.of(context).padding.top;

      return IgnorePointer(
        ignoring: expansion > 0.5,
        child: GestureDetector(
          onPanStart: (details) {
            if (isDesktop) {
              windowManager.startDragging();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.only(
              top: isDesktop ? 0 : topPadding,
              left: 2 + widget.leftOffset,
              right: 2,
            ),
            decoration: BoxDecoration(
              gradient: showBlur
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF0D1117).withOpacity(0.9),
                        const Color(0xFF0D1117).withOpacity(0.0),
                      ],
                    )
                  : null,
            ),
            child: Container(
              height: !isDesktop ? 64 : 50,
              padding: EdgeInsets.only(top: 0),
              child: Row(
                children: [
                  // Left: Navigation Buttons (Desktop) or Sidebar Toggle (Android)
                  Opacity(
                    opacity: hideContentOpacity,
                    child: IgnorePointer(
                      ignoring: expansion > 0.5,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 16),
                          if (isDesktop) ...[
                            Watch((context) {
                              final canBack = navigationSignal.canGoBack.value;
                              return _CircularIconButton(
                                icon: Icons.chevron_left,
                                onPressed: canBack
                                    ? () => navigationSignal.goBack(context)
                                    : null,
                                tooltip: 'Back',
                              );
                            }),
                            const SizedBox(width: 8),
                            Watch((context) {
                              final canForward =
                                  navigationSignal.canGoForward.value;
                              return _CircularIconButton(
                                icon: Icons.chevron_right,
                                onPressed: canForward
                                    ? () => navigationSignal.goForward(context)
                                    : null,
                                tooltip: 'Forward',
                              );
                            }),
                          ] else ...[
                            _CircularIconButton(
                              icon: Icons.menu,
                              onPressed: () {
                                Scaffold.of(context).openDrawer();
                              },
                              tooltip: 'Menu',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Center: Search Bar (Responsive)
                  Expanded(
                    child: Center(
                      child: _buildSearchBar(hideContentOpacity, expansion),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Right: Window Buttons (Desktop) or Settings (Android)
                  Opacity(
                    opacity: hideContentOpacity,
                    child: IgnorePointer(
                      ignoring: expansion > 0.5,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isDesktop &&
                              settingsSignal.useCustomWindowControls.value)
                            const WindowButtons()
                          else if (!isDesktop)
                            _CircularIconButton(
                              icon: Icons.settings,
                              onPressed: () => context.go('/settings'),
                              tooltip: 'Settings',
                            ),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildSearchBar(double opacity, double expansion) {
    return Opacity(
      opacity: opacity,
      child: IgnorePointer(
        ignoring: expansion > 0.5,
        child: Container(
          height: 40,
          constraints: const BoxConstraints(maxWidth: 600),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F24),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () {
                if (navigationSignal.canPopSync) {
                  navigationSignal.goBack(context);
                  // Clear search on exit
                  audioSignal.searchQuery.value = '';
                }
              },
            },
            child: TextField(
              controller: _searchController,
              textAlignVertical: TextAlignVertical.center,
              onChanged: (value) => audioSignal.searchQuery.value = value,
              onTap: () {
                final currentRoute = navigationSignal.currentRoute.value;
                if (currentRoute != '/search') {
                  context.go('/search');
                }
              },
              onSubmitted: (value) {
                final currentRoute = navigationSignal.currentRoute.value;
                if (currentRoute != '/search') {
                  context.go('/search');
                }
              },
              decoration: InputDecoration(
                hintText: 'Search songs, albums, artists',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white38,
                  size: 20,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  const _CircularIconButton({
    required this.icon,
    this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: MouseRegion(
          cursor: onPressed != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.3),
            ),
            child: Icon(
              icon,
              size: 20,
              color: onPressed != null ? Colors.white70 : Colors.white24,
            ),
          ),
        ),
      ),
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircularWindowButton(
          icon: Icons.keyboard_arrow_down,
          onPressed: () => appWindow.minimize(),
          tooltip: 'Minimize',
        ),
        const SizedBox(width: 8),
        _CircularWindowButton(
          icon: Icons.keyboard_arrow_up,
          onPressed: () => appWindow.maximizeOrRestore(),
          tooltip: 'Maximize',
        ),
        const SizedBox(width: 8),
        _CircularWindowButton(
          icon: Icons.close,
          onPressed: () async {
            if (settingsSignal.backgroundPlayback.value) {
              await windowManager.hide();
            } else {
              appWindow.close();
            }
          },
          tooltip: 'Close',
          isClose: true,
        ),
      ],
    );
  }
}

class _CircularWindowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final bool isClose;

  const _CircularWindowButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.isClose = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.3),
            ),
            child: Icon(icon, size: 18, color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
