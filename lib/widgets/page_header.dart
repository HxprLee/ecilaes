import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/navigation_signal.dart';
import '../signals/audio_signal.dart';

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final Widget? leading;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = false,
    this.onBack,
    this.actions,
    this.leading,
  });

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final topPadding = isDesktop
        ? 50.0
        : 64.0 + MediaQuery.of(context).padding.top;

    return Watch((context) {
      final progress = audioSignal.headerTitleProgress.value;

      // Interpolate: large title shrinks and fades as it morphs into the header
      final fontSize = lerpDouble(28.0, 18.0, progress)!;
      final titleOpacity = (1.0 - progress * 1.5).clamp(0.0, 1.0);

      return Padding(
        padding: EdgeInsets.only(
          top: 24.0 + topPadding,
          left: 24.0,
          right: 24.0,
          bottom: 24.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (showBackButton && !_isMobile) ...[
                  IconButton(
                    onPressed: onBack ?? () => navigationSignal.goBack(context),
                    icon: FaIcon(
                      FontAwesomeIcons.chevronLeft,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (leading != null) ...[
                  Opacity(
                    opacity: titleOpacity,
                    child: Transform.scale(
                      scale: lerpDouble(1.0, 0.3, progress)!,
                      alignment: Alignment.centerLeft,
                      child: leading!,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Opacity(
                    opacity: titleOpacity,
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
                              ).colorScheme.onSurface.withOpacity(0.54),
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (actions != null) ...actions!,
              ],
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
