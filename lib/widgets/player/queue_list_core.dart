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
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:signals/signals_flutter.dart';
import '../../models/song.dart';
import '../../signals/audio_signal.dart';
import '../../signals/overlay_signal.dart';
import '../../signals/queue_signal.dart' as q;
import '../../services/album_art_cache.dart';
import '../../services/YoutubeDatasource.dart';
import '../../theme/app_theme_tokens.dart';
import '../components/flyout_sheet.dart';
import '../../widgets/dialogs/playlist_dialogs.dart';
import '../../widgets/dialogs/song_info_dialog.dart';

/// Shared queue list body used by the FlyoutSheet queue and the queue pane
/// inside the expanded morphing player. Both surfaces render the same
/// collapsible Played / Up Next list, reorder, dismiss, and more-actions.
class QueueListCore extends StatefulWidget {
  /// When true, the back-to-top FAB is shown after scrolling past 200px.
  final bool showBackToTop;

  /// When true, the sticky "Now playing" row is rendered at the top of the
  /// Up Next section. Embedded pane uses this; the sheet does too.
  final bool showNowPlaying;

  /// Horizontal padding for the tile content. The embedded pane wants more
  /// (32) so list tiles align with the morphing player's interior padding;
  /// the sheet uses 16.
  final double tileHorizontalPadding;

  /// Optional scroll controller. The FlyoutSheet owns one for the back-to-top
  /// FAB; the embedded pane lets the parent drive the scroll position.
  final ScrollController? scrollController;

  /// When true, a dismiss callback can be reported to the parent (used to
  /// hide the back-to-top FAB while a swipe gesture is active).
  final void Function(int? draggingIndex)? onDraggingChanged;

  /// Constrains the height of the scrollable body. Useful when embedding
  /// inside the expanded player where the queue pane has a fixed height.
  final double? maxHeight;

  /// When non-null, the upNext and history lists are filtered to songs whose
  /// title or artist contain this substring (case-insensitive). Owned by the
  /// parent (typically the FlyoutSheet that holds the search field).
  final String? filterText;

  const QueueListCore({
    super.key,
    this.showBackToTop = true,
    this.showNowPlaying = true,
    this.tileHorizontalPadding = 16,
    this.scrollController,
    this.onDraggingChanged,
    this.maxHeight,
    this.filterText,
  });

  @override
  State<QueueListCore> createState() => _QueueListCoreState();
}

class _QueueListCoreState extends State<QueueListCore> {
  bool _playedExpanded = true;
  bool _upNextExpanded = true;
  bool _showBackToTop = false;
  bool _isDragging = false;
  ScrollController? _localScrollController;

  /// Cached lowercase filter text. Refreshed in [didUpdateWidget] so child
  /// sections don't need [findAncestorStateOfType] on every build.
  String? _filterTextLower;

  ScrollController get _scrollController =>
      widget.scrollController ??
      (_localScrollController ??= ScrollController());

  @override
  void initState() {
    super.initState();
    _filterTextLower = widget.filterText?.trim().toLowerCase();
    if (widget.showBackToTop) {
      _scrollController.addListener(_handleScroll);
    }
  }

  @override
  void didUpdateWidget(QueueListCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterText != widget.filterText) {
      _filterTextLower = widget.filterText?.trim().toLowerCase();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _localScrollController?.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final visible = _scrollController.offset > 200;
    if (_showBackToTop != visible) {
      setState(() => _showBackToTop = visible);
    }
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Collapsed state is local — no SignalBuilder needed for it.
    final body = _buildBody();

    if (!widget.showBackToTop || _isDragging) {
      return widget.maxHeight != null
          ? SizedBox(height: widget.maxHeight, child: body)
          : body;
    }

    return Stack(
      children: [
        widget.maxHeight != null
            ? SizedBox(height: widget.maxHeight, child: body)
            : body,
        // Back-to-top FAB is the only signal-derived UI outside the scoped
        // sections. Reading _showBackToTop (set by scroll listener) is safe
        // here — it drives a conditional Positioned, not a SignalBuilder.
        SignalBuilder(builder: (context) {
          final visible = _showBackToTop;
          if (!visible) return const SizedBox.shrink();
          final hasNowPlaying =
              widget.showNowPlaying && audioSignal.currentSong.value != null;
          return Positioned(
            bottom: hasNowPlaying ? 96 : 24,
            left: 24,
            child: _BackToTopButton(onTap: _scrollToTop),
          );
        }),
      ],
    );
  }

  Widget _buildBody() {
// Top-level SignalBuilder gates the whole body so an empty queue short-circuits
// before allocating any section widgets. Children use their own SignalBuilder
// blocks so they rebuild independently.
    return SignalBuilder(builder: (context) {
      final upNextCount = q.queueSignal.upNextCount;
      final historyCount = q.queueSignal.historyCount;

      if (upNextCount == 0 && historyCount == 0) {
        // QueueListCore is hosted by box parents (SizedBox / Expanded), never
        // a CustomScrollView, so an empty queue renders as a Centered box
        // rather than a SliverFillRemaining.
        return const _EmptyQueueState();
      }

      return CustomScrollView(
        controller: _scrollController,
        slivers: [
          _HistorySection(
            horizontalPadding: widget.tileHorizontalPadding,
            expanded: _playedExpanded,
            filterTextLower: _filterTextLower,
            onToggle: () =>
                setState(() => _playedExpanded = !_playedExpanded),
            onClear: () => _confirmClearHistory(context),
          ),
          _UpNextSection(
            horizontalPadding: widget.tileHorizontalPadding,
            expanded: _upNextExpanded,
            filterTextLower: _filterTextLower,
            onToggle: () =>
                setState(() => _upNextExpanded = !_upNextExpanded),
            onDraggingChanged: widget.onDraggingChanged,
            onDragStateChanged: (isDragging) {
              setState(() => _isDragging = isDragging);
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      );
    });
  }

  void _confirmClearHistory(BuildContext context) {
    overlaySignal.push(ActiveOverlay.clearHistoryConfirm);

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History?'),
        content: const Text('This will remove all songs from history.'),
        actions: [
          TextButton(
            onPressed: () {
              overlaySignal.pop(ActiveOverlay.clearHistoryConfirm);
              Navigator.pop(ctx);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              overlaySignal.pop(ActiveOverlay.clearHistoryConfirm);
              Navigator.pop(ctx);
              q.queueSignal.clearHistory();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

}

// ─── History Section ──────────────────────────────────────────────────────────

/// Owns its own SignalBuilder block so history changes don't rebuild the Up Next
/// section.
class _HistorySection extends StatelessWidget {
  final double horizontalPadding;
  final bool expanded;
  final String? filterTextLower;
  final VoidCallback onToggle;
  final VoidCallback onClear;

  const _HistorySection({
    required this.horizontalPadding,
    required this.expanded,
    required this.filterTextLower,
    required this.onToggle,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(builder: (context) {
      final historyPaths = q.queueSignal.history.value;
      final currentPath = audioSignal.currentSong.value?.path;
      final songMap = audioSignal.songMap.value;

      // Pre-filter with cheap path comparison; only resolve a Song when
      // the filter text is set, and even then prefer the O(1) songMap
      // lookup over resolveSong's multi-list scan.
      var items = historyPaths.where((p) => p != currentPath).toList();
      final filter = filterTextLower;
      if (filter != null && filter.isNotEmpty) {
        items = items.where((p) {
          final s = songMap[p] ?? audioSignal.resolveSong(p);
          return s.title.toLowerCase().contains(filter) ||
              s.artist.toLowerCase().contains(filter);
        }).toList();
      }
      if (historyPaths.isEmpty) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
      return _CollapsibleSection(
        title: 'Played',
        count: items.length,
        expanded: expanded,
        onToggle: onToggle,
        trailing: items.isNotEmpty
            ? _ClearButton(
                label: 'Clear',
                onTap: onClear,
              )
            : null,
        contentSlivers: items.isNotEmpty
            ? [
                _AnimatedHistoryList(
                  songPaths: items,
                  horizontalPadding: horizontalPadding,
                ),
              ]
            : [_SliverSectionEmpty(text: 'No played songs')],
      );
    });
  }
}

// ─── Up Next Section ─────────────────────────────────────────────────────────

/// Owns its own SignalBuilder block so Up Next changes don't rebuild the History
/// section.
class _UpNextSection extends StatelessWidget {
  final double horizontalPadding;
  final bool expanded;
  final String? filterTextLower;
  final VoidCallback onToggle;
  final void Function(int? draggingIndex)? onDraggingChanged;
  final void Function(bool isDragging)? onDragStateChanged;

  const _UpNextSection({
    required this.horizontalPadding,
    required this.expanded,
    required this.filterTextLower,
    required this.onToggle,
    this.onDraggingChanged,
    this.onDragStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(builder: (context) {
      final currentIdx = q.queueSignal.currentIndex.value;
      final activeLen = q.queueSignal.activeLength;
// Read shuffleOrder + playbackOrder so the SignalBuilder subscribes to
// them — pathAtActiveIndex() reads them internally but the
// dependency wouldn't otherwise be visible to the analyzer.
      // ignore: unused_local_variable
      final shuffleOrder = q.queueSignal.shuffleOrder.value;
      // ignore: unused_local_variable
      final playbackOrder = q.queueSignal.playbackOrder.value;

      List<(String, int)> items;
      if (currentIdx >= 0 && currentIdx < activeLen - 1) {
        items = [
          for (int i = currentIdx + 1; i < activeLen; i++)
            (
              q.queueSignal.pathAtActiveIndex(i) ?? '',
              i,
            ),
        ];
      } else {
        items = [];
      }
      items = items.where((e) => e.$1.isNotEmpty).toList();

      final filter = filterTextLower;
      if (filter != null && filter.isNotEmpty) {
        final songMap = audioSignal.songMap.value;
        items = items.where((e) {
          final s = songMap[e.$1] ?? audioSignal.resolveSong(e.$1);
          return s.title.toLowerCase().contains(filter) ||
              s.artist.toLowerCase().contains(filter);
        }).toList();
      }

      return _CollapsibleSection(
        title: 'Up Next',
        count: items.length,
        expanded: expanded,
        onToggle: onToggle,
        trailing: items.isNotEmpty
            ? _ClearButton(label: 'Clear', onTap: () => q.queueSignal.clearUpNext())
            : null,
        contentSlivers: items.isNotEmpty
            ? [
                _AnimatedUpNextList(
                  items: items,
                  horizontalPadding: horizontalPadding,
                  onDraggingChanged: onDraggingChanged,
                  onDragStateChanged: onDragStateChanged,
                ),
              ]
            : [
                _SliverSectionEmpty(
                  text: 'Queue is empty — add songs to start listening',
                ),
              ],
      );
    });
  }
}

// ─── Back to Top Button ──────────────────────────────────────────────────────

class _BackToTopButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackToTopButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
      ),
    );
  }
}

// ─── Collapsible Section ────────────────────────────────────────────────────

class _CollapsibleSection extends StatelessWidget {
  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget? trailing;

  /// Slivers rendered when [expanded] is true. When collapsed, an empty
  /// sliver replaces them so the header still anchors to the same place.
  final List<Widget> contentSlivers;

  const _CollapsibleSection({
    required this.title,
    required this.count,
    required this.expanded,
    required this.onToggle,
    this.trailing,
    required this.contentSlivers,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final header = InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 24, 8),
        child: Row(
          children: [
            AnimatedRotation(
              turns: expanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: colorScheme.secondary.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.secondary.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '($count)',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.secondary.withValues(alpha: 0.35),
                fontWeight: FontWeight.w400,
              ),
            ),
            const Spacer(),
            trailing ?? const SizedBox.shrink(),
          ],
        ),
      ),
    );

    // SliverMainAxisGroup is required so the header and content slivers
    // share a single sliver context. SliverAnimatedOpacity provides the
    // fade that AnimatedCrossFade previously delivered; the cross-axis
    // geometry still snaps instantly because slivers can't be smoothly
    // height-animated, but content stays visible long enough that the
    // chevron + count animating give the collapse a clean feel.
    final content = expanded
        ? SliverMainAxisGroup(slivers: contentSlivers)
        : const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: header),
        SliverAnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: expanded ? 1.0 : 0.0,
          sliver: content,
        ),
      ],
    );
  }
}

// ─── Animated Up Next List (reorderable) ─────────────────────────────────────

class _AnimatedUpNextList extends StatefulWidget {
  /// Pairs of (song path, queue index in playbackOrder).
  final List<(String path, int queueIndex)> items;
  final double horizontalPadding;
  final void Function(int? draggingIndex)? onDraggingChanged;
  final void Function(bool isDragging)? onDragStateChanged;

  const _AnimatedUpNextList({
    required this.items,
    required this.horizontalPadding,
    this.onDraggingChanged,
    this.onDragStateChanged,
  });

  @override
  State<_AnimatedUpNextList> createState() => _AnimatedUpNextListState();
}

class _AnimatedUpNextListState extends State<_AnimatedUpNextList> {
  static const _identityAnimation = AlwaysStoppedAnimation(1.0);

  /// Stable keys so Dismissible state is retained across rebuilds.
  final List<Key> _itemKeys = [];
  List<(String path, int queueIndex)> _displayedItems = [];

  @override
  void initState() {
    super.initState();
    _syncFromSignal();
  }

  @override
  void didUpdateWidget(_AnimatedUpNextList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFromSignal();
  }

  void _syncFromSignal() {
    final newKeys = <Key>[];
    for (int i = 0; i < widget.items.length; i++) {
      if (i < _displayedItems.length &&
          _displayedItems[i].$1 == widget.items[i].$1) {
        newKeys.add(_itemKeys[i]);
      } else {
        newKeys.add(UniqueKey());
      }
    }
    _displayedItems = List<(String, int)>.from(widget.items);
    _itemKeys
      ..clear()
      ..addAll(newKeys);
  }

  void _dismissItem(int displayIndex) {
    if (displayIndex < 0 || displayIndex >= _displayedItems.length) return;
    final (_, queueIndex) = _displayedItems[displayIndex];
    _displayedItems.removeAt(displayIndex);
    _itemKeys.removeAt(displayIndex);
    setState(() {});
    audioSignal.removeFromUpNext(queueIndex);
  }

  void _showActions(BuildContext context, Song song, int queueIndex) {
    overlaySignal.push(ActiveOverlay.unknown);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) => FlyoutSheet(
        showHandle: true,
        maxWidth: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionTile(
              icon: Icons.play_arrow,
              label: 'Play now',
              onTap: () {
                Navigator.pop(ctx);
                overlaySignal.pop(ActiveOverlay.unknown);
                audioSignal.playSong(song);
              },
            ),
            _ActionTile(
              icon: Icons.keyboard_arrow_up,
              label: 'Move to top',
              onTap: () {
                Navigator.pop(ctx);
                overlaySignal.pop(ActiveOverlay.unknown);
                q.queueSignal.moveToTop(song.path);
              },
            ),
            _ActionTile(
              icon: Icons.remove_circle_outline,
              label: 'Remove from queue',
              onTap: () {
                Navigator.pop(ctx);
                overlaySignal.pop(ActiveOverlay.unknown);
                audioSignal.removeFromUpNext(queueIndex);
              },
            ),
            _ActionTile(
              icon: Icons.playlist_add,
              label: 'Add to playlist',
              onTap: () {
                Navigator.pop(ctx);
                overlaySignal.pop(ActiveOverlay.unknown);
                PlaylistPickerDialog.show(context, song: song);
              },
            ),
            _ActionTile(
              icon: Icons.info_outline,
              label: 'Song info',
              onTap: () {
                Navigator.pop(ctx);
                overlaySignal.pop(ActiveOverlay.unknown);
                showSongInfoDialog(context, song);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: _displayedItems.length,
      itemBuilder: (context, index) {
        if (index >= _displayedItems.length) {
          return const SizedBox.shrink();
        }
        final (path, queueIndex) = _displayedItems[index];
        final itemKey = _itemKeys[index];
        final song = audioSignal.resolveSong(path);

        return LongPressDraggable<int>(
          data: index,
          feedback: Material(
            elevation: 8,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(4),
            color: Theme.of(context).colorScheme.surface,
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 32,
              child: _UpNextTileContent(
                song: song,
                horizontalPadding: widget.horizontalPadding,
                isDragFeedback: true,
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _AnimatedTile(
              song: song,
              itemKey: itemKey,
              animation: _identityAnimation,
              isRemoval: false,
              onDismissed: null,
            ),
          ),
          onDragStarted: () {
            widget.onDragStateChanged?.call(true);
            widget.onDraggingChanged?.call(index);
          },
          onDragEnd: (_) {
            widget.onDragStateChanged?.call(false);
            widget.onDraggingChanged?.call(null);
          },
          child: DragTarget<int>(
            onWillAcceptWithDetails: (details) => details.data != index,
            onAcceptWithDetails: (details) {
              final oldDisplayIndex = details.data;
              if (oldDisplayIndex < 0 || oldDisplayIndex == index) return;
              final oldQueueIdx = _displayedItems[oldDisplayIndex].$2;
              final newQueueIdx = _displayedItems[index].$2;
              audioSignal.reorderUpNext(oldQueueIdx, newQueueIdx);
            },
            builder: (context, candidateData, rejectedData) {
              return _AnimatedTile(
                song: song,
                itemKey: itemKey,
                animation: _identityAnimation,
                isRemoval: false,
                showDragTargetHint: candidateData.isNotEmpty,
                onDismissed: () => _dismissItem(index),
                childBuilder: (context) => _UpNextTileContent(
                  song: song,
                  horizontalPadding: widget.horizontalPadding,
                  onTap: () => audioSignal.playSong(song),
                  onMore: () => _showActions(context, song, queueIndex),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ─── Animated History List (non-reorderable) ─────────────────────────────────

class _AnimatedHistoryList extends StatefulWidget {
  final List<String> songPaths;
  final double horizontalPadding;

  const _AnimatedHistoryList({
    required this.songPaths,
    required this.horizontalPadding,
  });

  @override
  State<_AnimatedHistoryList> createState() => _AnimatedHistoryListState();
}

class _AnimatedHistoryListState extends State<_AnimatedHistoryList> {
  static const _identityAnimation = AlwaysStoppedAnimation(1.0);

  final List<Key> _itemKeys = [];
  List<String> _displayedPaths = [];
  int _expandedLimit = 100;

  @override
  void initState() {
    super.initState();
    _syncFromSignal();
  }

  @override
  void didUpdateWidget(_AnimatedHistoryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFromSignal();
  }

  void _syncFromSignal() {
    final newKeys = <Key>[];
    final limit = _expandedLimit.clamp(0, widget.songPaths.length);
    for (int i = 0; i < limit; i++) {
      if (i < _displayedPaths.length &&
          _displayedPaths[i] == widget.songPaths[i]) {
        newKeys.add(_itemKeys[i]);
      } else {
        newKeys.add(UniqueKey());
      }
    }
    _displayedPaths = widget.songPaths.take(limit).toList();
    _itemKeys
      ..clear()
      ..addAll(newKeys);
  }

  void _loadMore() {
    if (!mounted) return;
    final nextLimit = (_expandedLimit + 100)
        .clamp(0, widget.songPaths.length);
    if (nextLimit == _expandedLimit) return;
    setState(() => _expandedLimit = nextLimit);
  }

  void _dismissItem(int index) {
    if (index < 0 || index >= _displayedPaths.length) return;
    final path = _displayedPaths[index];
    _displayedPaths.removeAt(index);
    _itemKeys.removeAt(index);
    setState(() {});
    q.queueSignal.removeFromHistory(path);
  }

  void _playFromHistory(String path) {
    final song = q.queueSignal.playFromHistory(path);
    if (song != null) {
      audioSignal.playSong(song);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.songPaths.length - _displayedPaths.length;
    final showLoadMore = remaining > 0;

    return SliverMainAxisGroup(
      slivers: [
        SliverList.builder(
          itemCount: _displayedPaths.length,
          itemBuilder: (context, index) {
            if (index >= _displayedPaths.length) {
              return const SizedBox.shrink();
            }
            final path = _displayedPaths[index];
            final itemKey = _itemKeys[index];
            final song = audioSignal.resolveSong(path);

            return _AnimatedTile(
              song: song,
              itemKey: itemKey,
              animation: _identityAnimation,
              isRemoval: false,
              onDismissed: () => _dismissItem(index),
              childBuilder: (context) => _HistoryTileContent(
                song: song,
                horizontalPadding: widget.horizontalPadding,
                onTap: () => _playFromHistory(path),
              ),
            );
          },
        ),
        if (showLoadMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: _loadMore,
                child: Text(
                  'Load $remaining more',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Shared Animated Tile ───────────────────────────────────────────────────────

/// Wraps a tile in slide+fade animation and Dismissible with a stable key.
class _AnimatedTile extends StatelessWidget {
  final Song song;
  final Key itemKey;
  final Animation<double> animation;
  final bool isRemoval;
  final bool showDragTargetHint;
  final VoidCallback? onDismissed;
  final Widget Function(BuildContext)? childBuilder;

  const _AnimatedTile({
    required this.song,
    required this.itemKey,
    required this.animation,
    required this.isRemoval,
    this.showDragTargetHint = false,
    this.onDismissed,
    this.childBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final slideAnim = Tween<Offset>(
      begin: Offset(isRemoval ? -0.15 : 0.15, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: isRemoval ? Curves.easeIn : Curves.easeOut,
      ),
    );

    return SlideTransition(
      position: slideAnim,
      child: FadeTransition(
        opacity: animation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: showDragTargetHint
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                )
              : null,
          // RepaintBoundary isolates this tile from its siblings — a
          // re-render of one row (e.g. drag-feedback) no longer dirties
          // the others. Dismissible handles the swipe gesture and key
          // stability. The thin Material wrapper gives ListTile's
          // onTap an InkWell ancestor for the ripple.
          child: RepaintBoundary(
            child: Dismissible(
              key: itemKey,
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                color: colorScheme.error.withValues(alpha: 0.15),
                child: Icon(
                  Icons.remove_circle_outline,
                  color: colorScheme.error,
                  size: 22,
                ),
              ),
              onDismissed: (_) => onDismissed?.call(),
              child: Material(
                type: MaterialType.transparency,
                child: childBuilder?.call(context) ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Up Next Tile Content ─────────────────────────────────────────────────────

class _UpNextTileContent extends StatelessWidget {
  final Song song;
  final double horizontalPadding;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final bool isDragFeedback;

  const _UpNextTileContent({
    required this.song,
    required this.horizontalPadding,
    this.onTap,
    this.onMore,
    this.isDragFeedback = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: ListTile(
        contentPadding: EdgeInsets.only(
          left: horizontalPadding,
          right: horizontalPadding,
          top: 4,
          bottom: 4,
        ),
        leading: _Artwork(song: song, size: 48),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colorScheme.secondary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          song.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colorScheme.secondary.withValues(alpha: 0.65),
            fontSize: 12,
          ),
        ),
        trailing: isDragFeedback
            ? null
            : IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onMore,
                icon: Icon(
                  Icons.more_horiz,
                  color: colorScheme.secondary.withValues(alpha: 0.45),
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
        onTap: onTap,
      ),
    );
  }
}

// ─── History Tile Content ─────────────────────────────────────────────────────

class _HistoryTileContent extends StatelessWidget {
  final Song song;
  final double horizontalPadding;
  final VoidCallback? onTap;

  const _HistoryTileContent({
    required this.song,
    required this.horizontalPadding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 4,
        ),
        leading: _Artwork(song: song, size: 48),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colorScheme.secondary.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          song.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colorScheme.secondary.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

// ─── Action Tile ─────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Ink(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(icon, color: colorScheme.secondary),
          title: Text(
            label,
            style: TextStyle(color: colorScheme.secondary, fontSize: 15),
          ),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          dense: true,
        ),
      ),
    );
  }
}

// ─── Clear Button ────────────────────────────────────────────────────────────

class _ClearButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ClearButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.secondary.withValues(alpha: 0.5),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─── Section Empty ───────────────────────────────────────────────────────────

class _SliverSectionEmpty extends StatelessWidget {
  final String text;

  const _SliverSectionEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .secondary
                .withValues(alpha: 0.35),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Artwork ─────────────────────────────────────────────────────────────────

class _Artwork extends StatelessWidget {
  final Song song;
  final double size;

  const _Artwork({required this.song, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[800],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildImage(context),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    final fallbackIcon = Icon(
      Icons.music_note,
      color: context.tokens.placeholderIcon,
      size: size * 0.5,
    );

    if (!song.hasAlbumArt) return fallbackIcon;

    if (song.path.startsWith('yt:')) {
      final url = youtubeDatasource.getSongArtworkUrl(song);
      return Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: (size * 2).toInt(),
        cacheHeight: (size * 2).toInt(),
        errorBuilder: (_, _, _) => fallbackIcon,
      );
    }

    // For local songs, prefer the in-memory songMap's `hasAlbumArt` flag
    // (no I/O). Fall back to a synchronous AlbumArtCache lookup only when
    // the song isn't in the library (e.g. cold start before scan).
    final known = audioSignal.songMap.value[song.path];
    if (known == null) {
      final cachedPath = AlbumArtCache().getArtPathSync(song.path);
      if (cachedPath == null) return fallbackIcon;
      return Image.file(
        File(cachedPath),
        fit: BoxFit.cover,
        cacheWidth: (size * 2).toInt(),
        cacheHeight: (size * 2).toInt(),
        errorBuilder: (_, _, _) => fallbackIcon,
      );
    }

    final artDir = audioSignal.albumArtDir.value;
    if (artDir == null) return fallbackIcon;
    final artPath = '$artDir/${song.path.hashCode.abs()}.jpg';
    return Image.file(
      File(artPath),
      fit: BoxFit.cover,
      cacheWidth: (size * 2).toInt(),
      cacheHeight: (size * 2).toInt(),
      errorBuilder: (_, _, _) => fallbackIcon,
    );
  }
}

// ─── Empty Queue State ───────────────────────────────────────────────────────

class _EmptyQueueState extends StatelessWidget {
  const _EmptyQueueState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            FontAwesomeIcons.music,
            size: 48,
            color: Theme.of(context)
                .colorScheme
                .secondary
                .withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Queue is empty',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .secondary
                      .withValues(alpha: 0.5),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add songs to start listening',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .secondary
                      .withValues(alpha: 0.35),
                ),
          ),
        ],
      ),
    );
  }
}
