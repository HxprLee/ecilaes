// Ecilaes - Cross-platform music player
// Copyright (C) 2024  Anton Borri
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

    return Watch((context) {
      final position = audioSignal.position.value;

      // Find current line index using binary search (O(log n) vs O(n))
      int currentIndex = -1;
      if (_isSynced) {
        int low = 0, high = _lines.length - 1;
        while (low <= high) {
          final mid = (low + high) ~/ 2;
          final cmp = _lines[mid].time.compareTo(position);
          if (cmp <= 0) {
            currentIndex = mid;
            low = mid + 1;
          } else {
            high = mid - 1;
          }
        }
      }

      // Auto-scroll to current line if it changed and user is not manually scrolling
      if (_isSynced && !_userScrolling && currentIndex != _lastScrolledIndex) {
        _lastScrolledIndex = currentIndex;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_controller.hasClients) {
            _isAutoScrolling = true;
            _controller
                .scrollToIndex(
                  currentIndex,
                  preferPosition: AutoScrollPosition.begin,
                  duration: const Duration(milliseconds: 300),
                )
                .then((_) {
                  _isAutoScrolling = false;
                  if (_controller.hasClients) {
                    _lastScrollOffset = _controller.offset;
                  }
                });
          }
        });
      }

      return Stack(
        children: [
          // Lyrics list
          NotificationListener<ScrollStartNotification>(
            onNotification: (notification) {
              // Detect user-initiated drags (not programmatic scrolls)
              if (notification.dragDetails != null && !_isAutoScrolling) {
                // User started dragging
              }
              return false;
            },
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
                  horizontal:
                      settingsSignal.lyricsAlignment.value == TextAlign.center
                      ? 24
                      : 32,
                  vertical: _isSynced ? 200 : 24,
                ),
                itemCount: _lines.length,
                separatorBuilder: (context, index) =>
                    SizedBox(height: _isSynced ? 32 : 16),
                itemBuilder: (context, index) {
                  final line = _lines[index];
                  final isActive = index == currentIndex;

                  return AutoScrollTag(
                    key: ValueKey(index),
                    controller: _controller,
                    index: index,
                    child: GestureDetector(
                      onTap: _isSynced
                          ? () {
                              audioSignal.seek(line.time);
                              // Resume auto-scroll when user taps a lyric line
                              if (_userScrolling) {
                                _resumeAutoScroll();
                              }
                            }
                          : null,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                              style: Theme.of(context).textTheme.bodyMedium!
                                  .copyWith(
                                    color: (isActive || !_isSynced)
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.secondary
                                        : Theme.of(context)
                                              .colorScheme
                                              .secondary
                                              .withValues(alpha: 0.3),
                                    fontSize: (isActive || !_isSynced)
                                        ? (_isSynced
                                              ? settingsSignal
                                                    .lyricsActiveFontSize
                                                    .value
                                              : settingsSignal
                                                    .plainLyricsFontSize
                                                    .value)
                                        : settingsSignal
                                              .lyricsInactiveFontSize
                                              .value,
                                    fontWeight: isActive
                                        ? FontWeight.w900
                                        : FontWeight.w600,
                                  ),
                              child: Text(
                                line.content,
                                textAlign: settingsSignal.lyricsAlignment.value,
                                maxLines: 4,
                              ),
                            ),
                          ),
                          if (settingsSignal.showRomanizedLyrics.value &&
                              line.romanizedContent != null) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                                style: Theme.of(context).textTheme.bodyMedium!
                                    .copyWith(
                                      color: (isActive || !_isSynced)
                                          ? Theme.of(context)
                                                .colorScheme
                                                .secondary
                                                .withValues(alpha: 0.8)
                                          : Theme.of(context)
                                                .colorScheme
                                                .secondary
                                                .withValues(alpha: 0.2),
                                      fontSize:
                                          ((isActive || !_isSynced)
                                              ? (_isSynced
                                                    ? settingsSignal
                                                          .lyricsActiveFontSize
                                                          .value
                                                    : settingsSignal
                                                          .plainLyricsFontSize
                                                          .value)
                                              : settingsSignal
                                                    .lyricsInactiveFontSize
                                                    .value) *
                                          0.7,
                                      fontWeight: (isActive || !_isSynced)
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                child: Text(
                                  line.romanizedContent!,
                                  textAlign:
                                      settingsSignal.lyricsAlignment.value,
                                  maxLines: 4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
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
    });
  }
}
