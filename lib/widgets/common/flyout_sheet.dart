import 'dart:ui';
import 'package:flutter/material.dart';
import '../../signals/settings_signal.dart';
import '../../theme/app_theme_extensions.dart';

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
                    Theme.of(context)
                        .extension<AppThemeExtension>()!
                        .sidebarBackground
                        .withValues(
                          alpha: settingsSignal.enableGlobalBlur.value
                              ? 0.67
                              : 1.0,
                        ),
                borderRadius: borderRadius,
                border: showBorder
                    ? Border(
                        top: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withValues(alpha: 0.15),
                        ),
                        left: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withValues(alpha: 0.15),
                        ),
                        right: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withValues(alpha: 0.15),
                        ),
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
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withValues(alpha: 0.2),
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
