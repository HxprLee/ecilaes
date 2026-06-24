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

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:window_manager/window_manager.dart';
import '../../signals/audio_signal.dart';
import '../../signals/search_signal.dart';
import '../../widgets/header/desktop/desktop_header_bar.dart';
import '../../widgets/header/mobile/mobile_header_bar.dart';

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
      text: searchSignal.searchQuery.value,
    );

    // Sync controller with signal
    effect(() {
      final query = searchSignal.searchQuery.value;
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
      final showBlur = audioSignal.headerShowBlur.value && expansion < 0.1;

      return IgnorePointer(
        ignoring: expansion > 0.5,
        child: GestureDetector(
          onPanStart: isDesktop
              ? (details) {
                  windowManager.startDragging();
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: showBlur
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.9),
                        Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.0),
                      ],
                    )
                  : null,
            ),
            child: isDesktop
                ? DesktopHeaderBar(
                    leftOffset: widget.leftOffset,
                    hideContentOpacity: hideContentOpacity,
                    expansion: expansion,
                    searchController: _searchController,
                  )
                : MobileHeaderBar(
                    leftOffset: widget.leftOffset,
                    hideContentOpacity: hideContentOpacity,
                    expansion: expansion,
                    searchController: _searchController,
                  ),
          ),
        ),
      );
    });
  }
}
