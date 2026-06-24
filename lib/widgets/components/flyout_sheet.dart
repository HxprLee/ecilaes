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

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../signals/settings_signal.dart';
import '../../theme/app_theme_tokens.dart';

class FlyoutSheet extends StatelessWidget {
  final Widget child;
  final bool showHandle;
  final double maxWidth;
  final double? height;
  final BorderRadius borderRadius;
  final Color? backgroundColor;
  final bool showBorder;
  final MainAxisSize mainAxisSize;

  final bool safeAreaTop;
  final bool safeAreaBottom;

  const FlyoutSheet({
    super.key,
    required this.child,
    this.showHandle = true,
    this.maxWidth = 600,
    this.height,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(8)),
    this.backgroundColor,
    this.showBorder = true,
    this.mainAxisSize = MainAxisSize.min,
    this.safeAreaTop = false,
    this.safeAreaBottom = true,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: height ?? double.infinity,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: settingsSignal.enableGlobalBlur.value
                ? ImageFilter.blur(sigmaX: 20, sigmaY: 20)
                : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor ??
                    context.tokens.sidebarBackground.withValues(
                      alpha: settingsSignal.enableGlobalBlur.value
                          ? 0.67
                          : 1.0,
                    ),
                borderRadius: borderRadius,
                border: showBorder
                    ? Border(
                        top: BorderSide(color: context.accentBorder(0.15)),
                        left: BorderSide(color: context.accentBorder(0.15)),
                        right: BorderSide(color: context.accentBorder(0.15)),
                      )
                    : null,
              ),
              child: SafeArea(
                top: safeAreaTop,
                bottom: safeAreaBottom,
                child: Column(
                  mainAxisSize: mainAxisSize,
                  children: [
                    if (showHandle)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.accentOf(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    if (mainAxisSize == MainAxisSize.max)
                      Expanded(child: child)
                    else
                      child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
