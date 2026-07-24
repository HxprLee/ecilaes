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

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:signals/signals_flutter.dart';

import '../../router.dart' show rootNavigatorKey;
import '../../signals/settings_signal.dart';
import '../../signals/shell_layout_signal.dart';
import '../../theme/app_theme_tokens.dart';

/// Severity / semantic flavor of a toast. Controls the leading icon and the
/// accent stripe color so a glance is enough to tell success from failure.
enum AppToastVariant { info, success, warning, error }

/// One entry in the global toast queue. The service owns the queue; widgets
/// only call `ToastService.show(...)`.
class AppToastEntry {
  final String message;
  final AppToastVariant variant;
  final FaIconData icon;
  final DateTime createdAt;
  final String id;

  AppToastEntry({
    required this.message,
    required this.variant,
    required this.icon,
    required this.createdAt,
    required this.id,
  });
}

/// App-wide toast host. Mounted once at the [MaterialApp] root via
/// `builder:`. Captures the root [Overlay] so toasts can be installed via
/// [OverlayEntry] — this is what allows the toasts' [BackdropFilter]s to
/// find an [Overlay] ancestor and gives them the screen-bounded size they
/// need for proper layout.
///
/// Callers enqueue toasts from anywhere with [ToastService.show]; no
/// [BuildContext] is required, which means it works from services, sheets
/// that have already popped, and async callbacks that captured an expired
/// context.
class AppToastHost extends StatefulWidget {
  final Widget child;

  const AppToastHost({super.key, required this.child});

  @override
  State<AppToastHost> createState() => AppToastHostState();
}

class AppToastHostState extends State<AppToastHost> {
  OverlayState? _overlay;
  final Map<String, _MountedToast> _mounted = {};
  Timer? _gcTimer;

  @override
  void initState() {
    super.initState();
    _captureOverlay();
    ToastService.attachHost(this);
    _gcTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      final expired = _mounted.entries
          .where((entry) => now.isAfter(entry.value.expiresAt))
          .map((entry) => entry.key)
          .toList();
      for (final id in expired) {
        _dismiss(id);
      }
    });
  }

  void _captureOverlay() {
    // The host lives above the Navigator in the widget tree (it's mounted
    // from MaterialApp.builder), so [Overlay.of(context)] can't see the
    // root overlay from here. Capture it via the router's [GlobalKey]
    // instead — that gives us the root [OverlayState] directly. The
    // post-frame retry covers the startup window before the Navigator
    // mounts.
    _overlay = rootNavigatorKey.currentState?.overlay;
    if (_overlay == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _captureOverlay();
      });
    }
  }

  @override
  void dispose() {
    _gcTimer?.cancel();
    ToastService.detachHost(this);
    for (final m in _mounted.values) {
      m.entry.remove();
    }
    _mounted.clear();
    super.dispose();
  }

  void addEntry(AppToastEntry entry, Duration duration) {
    if (!mounted) return;
    final overlay = _overlay;
    if (overlay == null) {
      // The overlay isn't ready yet — try again next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) addEntry(entry, duration);
      });
      return;
    }
    final key = GlobalKey<_ToastCardState>();
    final overlayEntry = OverlayEntry(
      builder: (ctx) => _ToastCard(
        key: key,
        entry: entry,
        onDismiss: () => ToastService.dismiss(entry.id),
        onDismissed: () => _dismiss(entry.id),
      ),
    );
    overlay.insert(overlayEntry);
    _mounted[entry.id] = _MountedToast(
      entry: overlayEntry,
      expiresAt: DateTime.now().add(duration),
      cardKey: key,
    );
    Timer(duration + const Duration(milliseconds: 350), () {
      _dismiss(entry.id);
    });
  }

  void _dismiss(String id) {
    final mounted = _mounted[id];
    if (mounted == null) return;
    // Play the exit animation; the overlay entry is removed when the card
    // finishes its reverse animation (see _ToastCardState.dismiss()). If
    // the card state is already gone (e.g. host rebuilt), remove
    // immediately.
    final state = mounted.cardKey.currentState;
    if (state == null || state.isDismissing) {
      _mounted.remove(id)?.entry.remove();
      return;
    }
    state.dismiss();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _MountedToast {
  final OverlayEntry entry;
  final DateTime expiresAt;
  final GlobalKey<_ToastCardState> cardKey;

  _MountedToast({
    required this.entry,
    required this.expiresAt,
    required this.cardKey,
  });
}

class _ToastCard extends StatefulWidget {
  final AppToastEntry entry;
  final VoidCallback onDismiss;

  /// Called by the card once its exit animation has finished playing, so
  /// the host can remove the [OverlayEntry] from the tree.
  final VoidCallback onDismissed;

  const _ToastCard({
    super.key,
    required this.entry,
    required this.onDismiss,
    required this.onDismissed,
  });

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  /// True once [dismiss] has been invoked. Guards against double-dismiss
  /// races (e.g. auto-timeout firing after the user already clicked the
  /// close button).
  bool isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _offset = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Begin the exit animation. Safe to call once; subsequent calls are
  /// ignored. When the reverse animation finishes, [widget.onDismissed]
  /// fires so the host can pull the [OverlayEntry] out of the tree.
  void dismiss() {
    if (isDismissing) return;
    isDismissing = true;
    _controller.reverse().whenComplete(() {
      if (!mounted) return;
      widget.onDismissed();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Subscribing to blur + sidebar-width here keeps each toast anchored
    // over the content area; toggling the sidebar re-anchors live toasts
    // without a re-render of the host. The animation below is driven by
    // [_controller], which has its own listener and is unaffected by
    // [SignalBuilder].
    return SignalBuilder(builder: (context) {
      final blur = settingsSignal.enableGlobalBlur.value;
      final sidebarWidth = shellLayoutSignal.sidebarWidth.value;

      return Positioned(
        left: sidebarWidth + 16,
        right: 16,
        bottom: MediaQuery.viewPaddingOf(context).bottom + 24,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: IgnorePointer(
            ignoring: false,
            child: FadeTransition(
              opacity: _opacity,
              child: SlideTransition(
                position: _offset,
                child: _ToastCardBody(
                  blur: blur,
                  entry: widget.entry,
                  onDismiss: widget.onDismiss,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Pure layout for a single toast — extracted so [_ToastCardState.build]
/// can wrap the positioning in a [SignalBuilder] without dragging the animation
/// controller's listeners into the rebuild path.
class _ToastCardBody extends StatelessWidget {
  final bool blur;
  final AppToastEntry entry;
  final VoidCallback onDismiss;

  const _ToastCardBody({
    required this.blur,
    required this.entry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(64),
        child: BackdropFilter(
          filter: blur
              ? ImageFilter.blur(sigmaX: 20, sigmaY: 20)
              : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            decoration: BoxDecoration(
              color: context.tokens.sidebarBackground.withValues(
                alpha: blur ? 0.88 : 1.0,
              ),
              borderRadius: BorderRadius.circular(64),
              border: Border.all(color: context.accentBorder(0.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 14),
                FaIcon(
                  entry.icon,
                  color: context.colorScheme.secondary,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    entry.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.secondary,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: context.onSurfaceOf(0.6),
                  ),
                  onPressed: onDismiss,
                  tooltip: 'Dismiss',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Process-wide toast controller. Decoupled from any [BuildContext] so it
/// can be invoked from anywhere (services, async callbacks, dismissed
/// sheets). The host widget ([AppToastHost]) must be mounted in the tree
/// for queued toasts to actually render — see [main.dart].
class ToastService {
  static AppToastHostState? _host;
  static int _seq = 0;

  static void attachHost(AppToastHostState host) {
    _host = host;
  }

  static void detachHost(AppToastHostState host) {
    if (identical(_host, host)) _host = null;
  }

  /// Enqueue a toast. [variant] picks the icon and accent stripe. If
  /// [icon] is supplied it overrides the default variant icon.
  static void show(
    String message, {
    AppToastVariant variant = AppToastVariant.info,
    FaIconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    final resolvedIcon = icon ?? _defaultIcon(variant);
    final id = '${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
    final host = _host;
    if (host == null) return;
    host.addEntry(
      AppToastEntry(
        message: message,
        variant: variant,
        icon: resolvedIcon,
        createdAt: DateTime.now(),
        id: id,
      ),
      duration,
    );
  }

  /// Dismiss a toast by its id. If the id is unknown, this is a no-op.
  static void dismiss(String id) {
    _host?._dismissPublic(id);
  }

  static FaIconData _defaultIcon(AppToastVariant variant) {
    switch (variant) {
      case AppToastVariant.info:
        return FontAwesomeIcons.circleInfo;
      case AppToastVariant.success:
        return FontAwesomeIcons.circleCheck;
      case AppToastVariant.warning:
        return FontAwesomeIcons.triangleExclamation;
      case AppToastVariant.error:
        return FontAwesomeIcons.circleXmark;
    }
  }
}

extension on AppToastHostState {
  void _dismissPublic(String id) => _dismiss(id);
}
