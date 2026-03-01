import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';

/// A compact header with back button and title that morphs on mobile.
/// Used by settings pages and other subpages.
class SubpageHeader extends StatelessWidget {
  final String title;

  const SubpageHeader({super.key, required this.title});

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
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
