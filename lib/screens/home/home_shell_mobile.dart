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
import '../../theme/app_theme_tokens.dart';
import '../../widgets/sidebar.dart';
import '../../widgets/morphing_player.dart';
import '../../widgets/components/window_title_bar.dart';
import 'mobile/mobile_nav_bar.dart';

class HomeShellMobile extends StatefulWidget {
  final Widget child;
  const HomeShellMobile({super.key, required this.child});

  @override
  State<HomeShellMobile> createState() => _HomeShellMobileState();
}

class _HomeShellMobileState extends State<HomeShellMobile> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _playerKey = GlobalKey();

  String? _lastRoute;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final location = GoRouterState.of(context).uri.toString();
    final topPadding = MediaQuery.of(context).padding.top;
    final headerHeight = 64.0 + topPadding;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (_lastRoute != location) {
      _lastRoute = location;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        audioSignal.headerShowBlur.value = false;
        audioSignal.headerTitleProgress.value = 0.0;
        audioSignal.headerArtCover.value = null;
      });
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
        if (audioSignal.bottomPadding.value != bottomPadding) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            audioSignal.bottomPadding.value = bottomPadding;
          });
        }

        return PopScope(
          canPop: !router.canPop() &&
              audioSignal.playerExpansion.value < 0.001,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            final expansion = audioSignal.playerExpansion.value;
            if (expansion > 0.001) {
              audioSignal.minimizePlayerTrigger.value++;
              return;
            }
            if (router.canPop()) {
              router.pop();
            }
          },
          child: Scaffold(
            key: _scaffoldKey,
            extendBody: true,
            drawer: Drawer(
              backgroundColor: Colors.transparent,
              elevation: 0,
              width: 250 + 16,
              child: Sidebar(
                isCollapsed: false,
                onToggle: () {},
                isDrawer: true,
              ),
            ),
            body: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  left: 0,
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
                  child: const WindowTitleBar(leftOffset: 0),
                ),
                Positioned.fill(
                  child: Watch((context) {
                    final expansion = audioSignal.playerExpansion.value;
                    const navBarHeight = 56.0;
                    final mobileNavBarHeight = navBarHeight + bottomPadding;

                    final player = MorphingPlayer(
                      key: _playerKey,
                      leftOffset: 0,
                      bottomOffset: mobileNavBarHeight,
                    );

                    return Stack(
                      children: [
                        player,
                        MobileNavBar(
                          location: location,
                          bottomPadding: bottomPadding,
                          expansion: expansion,
                        ),
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
