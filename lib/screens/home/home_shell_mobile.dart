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
import '../../signals/overlay_signal.dart';
import '../../services/navigation/back_handler.dart';
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

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final topPadding = MediaQuery.of(context).padding.top;
    final headerHeight = 64.0 + topPadding;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: SignalBuilder(
        builder: (context) {
          if (audioSignal.bottomPadding.value != bottomPadding) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              audioSignal.bottomPadding.value = bottomPadding;
            });
          }

          return PopScope(
            // canPop: false — delegate ALL system-back handling to
            // AppBackHandler. go_router's internal PopScope (canPop:
            // matches.length == 1) + our own canPop: true had an
            // inconsistent interaction: tab routes (last shell child)
            // closed the app because the inner Navigator blocked the
            // pop (didPop=false) and the fallthrough hit the root
            // Navigator's PopScope, popping the entire ShellRoute.
            // With canPop:false the system back is consumed at our
            // PopScope and we steer it through the same prioritised
            // handler used by the in-app back button.
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              // Close drawer synchronously — onDrawerChanged fires
              // post-frame, too late for the handler below.
              final scaffold = _scaffoldKey.currentState;
              if (scaffold != null && scaffold.isDrawerOpen) {
                overlaySignal.isDrawerOpen.value = false;
                scaffold.closeDrawer();
              }
              final handled = appBackHandler.invoke(context).handled;
              if (!handled) SystemNavigator.pop();
            },
            child: Scaffold(
              key: _scaffoldKey,
              extendBody: true,
              onDrawerChanged: (isOpen) {
                overlaySignal.isDrawerOpen.value = isOpen;
              },
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
                  // Player is a stable widget keyed by `_playerKey`. The
                  // shell never recreates it on rebuild — only its
                  // transform/translation tracks `playerExpansion`, which
                  // ticks every animation frame during expand/collapse.
                  // Lifting the player out of the SignalBuilder keeps animation
                  // work in the player's own state, avoiding a per-frame
                  // build of the whole Stack.
                  Positioned.fill(
                    child: Stack(
                      children: [
                        MorphingPlayer(
                          key: _playerKey,
                          leftOffset: 0,
                          bottomOffset: 56.0 + bottomPadding,
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 56.0 + bottomPadding,
                          child: SignalBuilder(
                            builder: (context) {
                              final expansion =
                                  audioSignal.playerExpansion.value;
                              return Transform.translate(
                                offset: Offset(
                                  0,
                                  expansion * (56.0 + bottomPadding),
                                ),
                                child: MobileNavBar(
                                  location: location,
                                  bottomPadding: bottomPadding,
                                  expansion: expansion,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
