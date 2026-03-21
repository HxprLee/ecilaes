import 'dart:io';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:window_manager/window_manager.dart';
import '../../signals/audio_signal.dart';
import '../../signals/settings_signal.dart';
import '../../signals/navigation_signal.dart';
import '../../theme/app_theme_extensions.dart';

class DesktopHeaderBar extends StatelessWidget {
  final double leftOffset;
  final double hideContentOpacity;
  final double expansion;
  final TextEditingController searchController;

  const DesktopHeaderBar({
    super.key,
    required this.leftOffset,
    required this.hideContentOpacity,
    required this.expansion,
    required this.searchController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: EdgeInsets.only(left: 2 + leftOffset, right: 2),
      child: Row(
        children: [
          // Left: Navigation Buttons
          Opacity(
            opacity: hideContentOpacity,
            child: IgnorePointer(
              ignoring: expansion > 0.5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 16),
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
                    final canForward = navigationSignal.canGoForward.value;
                    return _CircularIconButton(
                      icon: Icons.chevron_right,
                      onPressed: canForward
                          ? () => navigationSignal.goForward(context)
                          : null,
                      tooltip: 'Forward',
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),
          // Morphing Page Title and Art
          Watch((context) {
            final titleProgress = audioSignal.headerTitleProgress.value;
            final currentRoute = navigationSignal.currentRoute.value;

            // Simplified title logic similar to MobileHeaderBar
            String pageTitle = '';
            if (currentRoute.startsWith('/playlist/')) {
              final id = currentRoute.split('/').last;
              try {
                final playlist = audioSignal.playlists.value.firstWhere(
                  (p) => p.id == id,
                );
                pageTitle = playlist.name;
              } catch (_) {
                pageTitle = 'Playlist';
              }
            }

            if (pageTitle.isEmpty || titleProgress < 0.01) {
              return const SizedBox.shrink();
            }

            return Opacity(
              opacity: titleProgress,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - titleProgress)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (audioSignal.headerArtCover.value != null) ...[
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          image: DecorationImage(
                            image: FileImage(
                              File(audioSignal.headerArtCover.value!),
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      pageTitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            );
          }),

          // Center: Search Bar
          Expanded(
            child: Center(
              child: _buildSearchBar(hideContentOpacity, expansion, context),
            ),
          ),

          const SizedBox(width: 16),

          // Right: Window Buttons
          Opacity(
            opacity: hideContentOpacity,
            child: IgnorePointer(
              ignoring: expansion > 0.5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (settingsSignal.useCustomWindowControls.value)
                    const _WindowButtons(),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(
    double opacity,
    double expansion,
    BuildContext context,
  ) {
    return Opacity(
      opacity: opacity,
      child: IgnorePointer(
        ignoring: expansion > 0.5,
        child: Container(
          height: 40,
          constraints: const BoxConstraints(maxWidth: 600),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).extension<AppThemeExtension>()!.headerBarBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
            ),
          ),
          child: TextField(
            controller: searchController,
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
              hintStyle: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.38),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.38),
                size: 20,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
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
              color: onPressed != null
                  ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.24),
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowButtons extends StatelessWidget {
  const _WindowButtons();

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
            child: Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }
}
