import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../signals/audio_signal.dart';

/// A self-contained sliver header that collapses as the user scrolls.
///
/// Replaces the old [PageHeader] + global scroll listener approach.
/// This widget uses [SliverPersistentHeader] internally, so it must be
/// placed directly inside a [CustomScrollView]'s slivers list.
class SliverPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final List<Widget>? topActions;
  final List<Widget>? underTextActions;
  final double? maxWidth;
  final bool pinned;
  final PreferredSizeWidget? bottom;

  const SliverPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.topActions,
    this.underTextActions,
    this.maxWidth,
    this.pinned = false,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final topPadding = isDesktop
        ? 80.0 // Matches HomeShell headerHeight
        : 64.0 + MediaQuery.of(context).padding.top;

    // Calculate the max extent based on content
    double contentHeight = 0;
    contentHeight += 24.0; // top gap below header bar
    if (leading != null) {
      contentHeight += math.max(140.0, 120.0); // leading widget height
    } else {
      contentHeight += 42.0; // title text height estimate
    }
    contentHeight += 24.0; // bottom gap

    final bottomHeight = bottom?.preferredSize.height ?? 0.0;
    final maxExtent = topPadding + contentHeight + bottomHeight;
    final minExtent = topPadding + bottomHeight;

    return SliverPersistentHeader(
      pinned: pinned,
      delegate: _SliverPageHeaderDelegate(
        title: title,
        subtitle: subtitle,
        actions: actions,
        leading: leading,
        topActions: topActions,
        underTextActions: underTextActions,
        maxWidth: maxWidth,
        maxExtent: maxExtent,
        minExtent: minExtent,
        topPadding: topPadding,
        bottom: bottom,
      ),
    );
  }
}

class _SliverPageHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final List<Widget>? topActions;
  final List<Widget>? underTextActions;
  final double? maxWidth;
  final double topPadding;
  final PreferredSizeWidget? bottom;

  @override
  final double maxExtent;

  @override
  final double minExtent;

  _SliverPageHeaderDelegate({
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.topActions,
    this.underTextActions,
    this.maxWidth,
    required this.maxExtent,
    required this.minExtent,
    required this.topPadding,
    this.bottom,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Progress 0.0 = fully expanded, 1.0 = fully collapsed
    final range = maxExtent - minExtent;
    final progress = range > 0 ? (shrinkOffset / range).clamp(0.0, 1.0) : 0.0;

    // Sync to global signal so header bars can still show the title
    WidgetsBinding.instance.addPostFrameCallback((_) {
      audioSignal.headerTitleProgress.value = progress;
      audioSignal.headerShowBlur.value = progress > 0;
    });

    // Interpolations
    final fontSize = _lerp(32.0, 22.0, progress);
    final titleOpacity = (1.0 - progress * 1.5).clamp(0.0, 1.0);
    final currentTopGap = _lerp(24.0 + topPadding, topPadding, progress);
    final currentBottomGap = _lerp(24.0, 0.0, progress);

    Widget content = Padding(
      padding: EdgeInsets.only(
        top: currentTopGap,
        left: 24.0,
        right: 24.0,
        bottom: currentBottomGap,
      ),
      child: ClipRect(
        child: Opacity(
          opacity: titleOpacity,
          child: OverflowBox(
            alignment: Alignment.topCenter,
            maxHeight: range + 48, // enough room for fully expanded content
            child: Transform.translate(
              offset: Offset(0, _lerp(0.0, -40.0, progress)),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (leading != null) ...[
                        Transform.scale(
                          scale: _lerp(1.0, 0.7, progress),
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
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
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
                                ),
                                if (actions != null) ...actions!,
                              ],
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle!,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary
                                      .withValues(alpha: 0.7),
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
    );

    if (maxWidth != null) {
      content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth!),
          child: content,
        ),
      );
    }

    if (bottom != null) {
      return Stack(
        children: [
          content,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: bottom!,
          ),
        ],
      );
    }

    return SizedBox.expand(child: content);
  }

  @override
  bool shouldRebuild(covariant _SliverPageHeaderDelegate oldDelegate) {
    return title != oldDelegate.title ||
        subtitle != oldDelegate.subtitle ||
        actions != oldDelegate.actions ||
        leading != oldDelegate.leading ||
        topActions != oldDelegate.topActions ||
        underTextActions != oldDelegate.underTextActions ||
        maxExtent != oldDelegate.maxExtent ||
        minExtent != oldDelegate.minExtent ||
        bottom != oldDelegate.bottom;
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;
}
