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
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../../signals/audio_signal.dart';

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final List<Widget>? topActions;
  final List<Widget>? underTextActions;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.topActions,
    this.underTextActions,
  });


  @override
  Widget build(BuildContext context) {
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final topPadding = isDesktop
        ? 80.0 // Matches HomeShell headerHeight
        : 64.0 + MediaQuery.of(context).padding.top;

    return SignalBuilder(builder: (context) {
      final progress = audioSignal.headerTitleProgress.value;

      // Interpolate: large title shrinks and fades as it morphs into the header
      final fontSize = lerpDouble(32.0, 22.0, progress)!;
      final titleOpacity = (1.0 - progress * 1.5).clamp(0.0, 1.0);

      final currentTopGap = lerpDouble(24.0 + topPadding, topPadding, progress)!;
      final currentBottomGap = lerpDouble(24.0, 0.0, progress)!;

      return Container(
        padding: EdgeInsets.only(
          top: currentTopGap,
          left: 24.0,
          right: 24.0,
          bottom: currentBottomGap,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: (1.0 - progress).clamp(0.0, 1.0),
                child: Opacity(
                  opacity: titleOpacity,
                  child: Transform.translate(
                    offset: Offset(0, lerpDouble(0.0, -40.0, progress)!),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (leading != null) ...[
                              Transform.scale(
                                scale: lerpDouble(1.0, 0.7, progress)!,
                                alignment: Alignment.bottomLeft,
                                child: leading!,
                              ),
                              const SizedBox(width: 16),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: fontSize,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.secondary,
                                      letterSpacing: -1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (subtitle != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle!,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary.withValues(alpha: 0.7),
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  if (underTextActions != null) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: underTextActions!,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            ...?actions,
                          ],
                        ),
                        if (topActions != null)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: topActions!,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

double? lerpDouble(double a, double b, double t) {
  return a + (b - a) * t;
}
