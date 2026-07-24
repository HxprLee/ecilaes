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
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:signals_flutter/signals_flutter.dart';
import '../services/lyrics_service.dart';
import '../signals/audio_signal.dart';
import '../signals/settings_signal.dart';

class MobileLyricsView extends StatefulWidget {
  final String lyricsText;

  /// Called when the user manually scrolls down (to show controls).
  final VoidCallback? onUserScrollDown;

  const MobileLyricsView({
    super.key,
    required this.lyricsText,
    this.onUserScrollDown,
  });

  @override
  State<MobileLyricsView> createState() => _MobileLyricsViewState();
}

class _MobileLyricsViewState extends State<MobileLyricsView> {
  late List<LyricLine> _lines;
  final AutoScrollController _controller = AutoScrollController(
    viewportBoundaryGetter: () => const Rect.fromLTRB(0, 80, 0, 0),
  );
  int _lastScrolledIndex = -1;

  bool _userScrolling = false;
  bool _isAutoScrolling = false;
  double _lastScrollOffset = 0;
  bool _isSynced = false;

  @override
  void initState() {
    super.initState();
    _lines = parseLyrics(widget.lyricsText);
    _isSynced = _lines.any((l) => l.time != Duration.zero);
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant MobileLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyricsText != widget.lyricsText) {
      _lines = parseLyrics(widget.lyricsText);
      _isSynced = _lines.any((l) => l.time != Duration.zero);
      _lastScrolledIndex = -1;
      _userScrolling = false;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isAutoScrolling) return;

    // Detect user-initiated scroll
    if (_controller.hasClients) {
      final currentOffset = _controller.offset;
      final scrolledDown = currentOffset > _lastScrollOffset;
      _lastScrollOffset = currentOffset;

      if (!_userScrolling) {
        setState(() {
          _userScrolling = true;
        });
      }

      // Show controls whenever the user scrolls UP (to read past lyrics)
      if (!scrolledDown) {
        widget.onUserScrollDown?.call();
      }
    }
  }

  void _resumeAutoScroll() {
    setState(() {
      _userScrolling = false;
      _lastScrolledIndex = -1; // Force re-scroll to current position
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_lines.isEmpty) {
      return Center(
        child: Text(
          'No lyrics available.',
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.5),
            fontSize: 16,
          ),
        ),
      );
    }

    final alignment = settingsSignal.lyricsAlignment.value;
    final horizontalPadding = alignment == TextAlign.center ? 24.0 : 32.0;
    final activeFontSize = settingsSignal.lyricsActiveFontSize.value;
    final inactiveFontSize = settingsSignal.lyricsInactiveFontSize.value;
    final plainFontSize = settingsSignal.plainLyricsFontSize.value;
    final showRomanized = settingsSignal.showRomanizedLyrics.value;
    final isCentered = alignment == TextAlign.center;

    return Stack(
      children: [
        // Lyrics list. The auto-scroll trigger lives in a separate SignalBuilder so
        // the heavy ListView+ShaderMask subtree only repaints when the
        // active line index actually changes (1-2/s, not 8-20/s).
        _LyricsAutoScrollDriver(
          isSynced: _isSynced,
          controller: _controller,
          lastScrolledIndex: _lastScrolledIndex,
          onAutoScroll: (index) {
            _lastScrolledIndex = index;
            if (!_isSynced || _userScrolling) return;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_controller.hasClients) return;
              _isAutoScrolling = true;
              _controller
                  .scrollToIndex(
                    index,
                    preferPosition: AutoScrollPosition.begin,
                    duration: const Duration(milliseconds: 300),
                  )
                  .then((_) {
                    _isAutoScrolling = false;
                    if (_controller.hasClients) {
                      _lastScrollOffset = _controller.offset;
                    }
                  });
            });
          },
        ),

        // Lyrics list
        NotificationListener<ScrollStartNotification>(
          onNotification: (notification) {
            // Detect user-initiated drags (not programmatic scrolls)
            if (notification.dragDetails != null && !_isAutoScrolling) {
              // User started dragging
            }
            return false;
          },
          child: RepaintBoundary(
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.1, 0.9, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: ListView.separated(
                controller: _controller,
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: _isSynced ? 80 : 24,
                ),
                itemCount: _lines.length,
                separatorBuilder: (context, index) =>
                    SizedBox(height: _isSynced ? 32 : 16),
                itemBuilder: (context, index) {
                  final line = _lines[index];

                  return AutoScrollTag(
                    key: ValueKey(index),
                    controller: _controller,
                    index: index,
                    child: _LyricLineTile(
                      line: line,
                      index: index,
                      isSynced: _isSynced,
                      alignment: alignment,
                      activeFontSize: activeFontSize,
                      inactiveFontSize: inactiveFontSize,
                      plainFontSize: plainFontSize,
                      showRomanized: showRomanized,
                      isCentered: isCentered,
                      onTap: _isSynced
                          ? () {
                              audioSignal.seek(line.time);
                              if (_userScrolling) {
                                _resumeAutoScroll();
                              }
                            }
                          : null,
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // Floating "return to current lyric" button
        if (_userScrolling)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: _resumeAutoScroll,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.surface,
              elevation: 4,
              child: const Icon(Icons.lyrics, size: 20),
            ),
          ),
      ],
    );
  }
}

/// Invisible watcher that subscribes to [audioSignal.lyricsActiveIndex] and
/// triggers programmatic scrolls when the active line changes. Lives outside
/// the heavy ListView/ShaderMask subtree so per-tick position changes don't
/// repaint lyrics content.
class _LyricsAutoScrollDriver extends StatelessWidget {
  final bool isSynced;
  final AutoScrollController controller;
  final int lastScrolledIndex;
  final void Function(int index) onAutoScroll;

  const _LyricsAutoScrollDriver({
    required this.isSynced,
    required this.controller,
    required this.lastScrolledIndex,
    required this.onAutoScroll,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSynced) return const SizedBox.shrink();
    return SignalBuilder(builder: (context) {
      final idx = audioSignal.lyricsActiveIndex.value;
      if (idx >= 0 && idx != lastScrolledIndex) {
        onAutoScroll(idx);
      }
      return const SizedBox.shrink();
    });
  }
}

class _LyricLineTile extends StatelessWidget {
  final LyricLine line;
  final int index;
  final bool isSynced;
  final TextAlign alignment;
  final double activeFontSize;
  final double inactiveFontSize;
  final double plainFontSize;
  final bool showRomanized;
  final bool isCentered;
  final VoidCallback? onTap;

  const _LyricLineTile({
    required this.line,
    required this.index,
    required this.isSynced,
    required this.alignment,
    required this.activeFontSize,
    required this.inactiveFontSize,
    required this.plainFontSize,
    required this.showRomanized,
    required this.isCentered,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final base = Theme.of(context).textTheme.bodyMedium!;
    final showRomanizedLine = showRomanized && line.romanizedContent != null;
    return SignalBuilder(builder: (context) {
      final activeIndex = isSynced ? audioSignal.lyricsActiveIndex.value : -1;
      final isActive = isSynced ? activeIndex == index : true;
      final isHighlighted = isActive || !isSynced;
    final mainFontSize = isHighlighted
        ? (isSynced ? activeFontSize : plainFontSize)
        : inactiveFontSize;
      final mainColor = isHighlighted
          ? colorScheme.secondary
          : colorScheme.secondary.withValues(alpha: 0.3);
      final mainWeight = isActive ? FontWeight.w900 : FontWeight.w600;

      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                style: base.copyWith(
                  color: mainColor,
                  fontSize: mainFontSize,
                  fontWeight: mainWeight,
                ),
                child: Text(
                  line.content,
                  textAlign: alignment,
                  maxLines: 4,
                ),
              ),
            ),
            if (showRomanizedLine) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  style: base.copyWith(
                    color: isHighlighted
                        ? colorScheme.secondary.withValues(alpha: 0.8)
                        : colorScheme.secondary.withValues(alpha: 0.2),
                    fontSize: mainFontSize * 0.7,
                    fontWeight:
                        isHighlighted ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: Text(
                    line.romanizedContent!,
                    textAlign: alignment,
                    maxLines: 4,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}
