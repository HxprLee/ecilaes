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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../../signals/audio_signal.dart';
import '../../widgets/sidebar.dart';
import '../../widgets/morphing_player.dart';
import '../../widgets/components/window_title_bar.dart';

class HomeShellDesktop extends StatefulWidget {
  final Widget child;
  const HomeShellDesktop({super.key, required this.child});

  @override
  State<HomeShellDesktop> createState() => _HomeShellDesktopState();
}

class _HomeShellDesktopState extends State<HomeShellDesktop> {
  final GlobalKey _playerKey = GlobalKey();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSidebarCollapsed = false;
  double? _lastWidth;
  String? _lastLocation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final width = MediaQuery.of(context).size.width;

    if (_lastWidth == null) {
      _isSidebarCollapsed = width < 1200;
    } else {
      if (_lastWidth! >= 1200 && width < 1200) {
        _isSidebarCollapsed = true;
      } else if (_lastWidth! < 1200 && width >= 1200) {
        _isSidebarCollapsed = false;
      }
    }
    _lastWidth = width;
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1000;
    final location = GoRouterState.of(context).uri.toString();
    const headerHeight = 80.0;

    if (_lastLocation != location) {
      _lastLocation = location;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        audioSignal.headerShowBlur.value = false;
        audioSignal.headerTitleProgress.value = 0.0;
        audioSignal.headerArtCover.value = null;
      });
    }

    const collapsedWidth = 70.0 + 16.0;
    const expandedWidth = 250.0 + 16.0;

    double contentLeftOffset;
    if (isSmallScreen) {
      contentLeftOffset = collapsedWidth;
    } else {
      contentLeftOffset = _isSidebarCollapsed ? collapsedWidth : expandedWidth;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Watch((context) {
        if (audioSignal.bottomPadding.value != 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            audioSignal.bottomPadding.value = 0;
          });
        }

        return PopScope(
          canPop: audioSignal.playerExpansion.value < 0.001,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              audioSignal.minimizePlayerTrigger.value++;
            }
          },
          child: Scaffold(
            key: _scaffoldKey,
            extendBody: true,
            body: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  left: contentLeftOffset,
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context),
                    child: widget.child,
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  top: 0,
                  left: 0,
                  right: 0,
                  height: headerHeight,
                  child: WindowTitleBar(leftOffset: contentLeftOffset),
                ),
                // Sidebar always above player; z-order handled by paint order
                Positioned(
                  key: const ValueKey('sidebar'),
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Sidebar(
                    isCollapsed: _isSidebarCollapsed,
                    onToggle: _toggleSidebar,
                  ),
                ),
                MorphingPlayer(
                  key: _playerKey,
                  leftOffset: contentLeftOffset,
                  bottomOffset: 0.0,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
