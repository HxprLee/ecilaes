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
import '../../signals/audio_signal.dart';

/// A compact header with back button and title that morphs on mobile.
/// Used by settings pages and other subpages.
class SubpageHeader extends StatelessWidget {
  final String title;

  const SubpageHeader({super.key, required this.title});

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(builder: (context) {
      final progress = _isMobile ? audioSignal.headerTitleProgress.value : 0.0;

      // Morph: shrink and fade the title as it scrolls into the header bar
      final fontSize = _lerp(28.0, 18.0, progress);
      final titleOpacity = (1.0 - progress * 1.5).clamp(0.0, 1.0);

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Opacity(
          opacity: titleOpacity,
          child: Text(
            title,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ),
      );
    });
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;
}
