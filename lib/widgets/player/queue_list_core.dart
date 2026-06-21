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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:signals/signals_flutter.dart';
import '../../models/song.dart';
import '../../signals/audio_signal.dart';
import '../../signals/queue_signal.dart' as q;
import '../../services/YoutubeDatasource.dart';
import '../../theme/app_theme_tokens.dart';
import '../common/flyout_sheet.dart';
import '../playlist_dialogs.dart';
import '../song_info_dialog.dart';

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

  ScrollController get _scrollController =>
      widget.scrollController ??
      (_localScrollController ??= ScrollController());

  @override
  void initState() {
    super.initState();
    if (widget.showBackToTop) {
      _scrollController.addListener(_handleScroll);
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
    return Watch((context) {
      final upNextPaths = q.queueSignal.upNext.value;
      final historyPaths = q.queueSignal.history.value;
      final currentSong = audioSignal.currentSong.value;
      // While a song is playing, it is the "now playing" anchor rendered by
      // the parent. Drop it from the Played list so the same song doesn't
      // appear twice (once as "Played", once as "Now playing").
      final currentPath = currentSong?.path;
      final upNextSongs = upNextPaths
          .map((p) => audioSignal.resolveSong(p))
          .toList();
      final historySongs = historyPaths.reversed
          .where((p) => p != currentPath)
          .map((p) => audioSignal.resolveSong(p))
          .toList();

      // Apply client-side filter (FlyoutSheet-owned search field).
      final filter = widget.filterText?.trim().toLowerCase();
      if (filter != null && filter.isNotEmpty) {
        bool matches(Song s) =>
            s.title.toLowerCase().contains(filter) ||
            s.artist.toLowerCase().contains(filter);
        upNextSongs.removeWhere((s) => !matches(s));
        historySongs.removeWhere((s) => !matches(s));
      }
      final isEmpty = upNextSongs.isEmpty && historySongs.isEmpty;
      // NowPlayingRow is now rendered by the parent wrapper (above the
      // search bar). The `showNowPlaying` widget flag still controls FAB
      // offset, since the parent decides whether the row is visible.
      final hasNowPlaying = widget.showNowPlaying && currentSong != null;

      Widget body;
      if (isEmpty) {
        body = const _EmptyQueueState();
      } else {
        body = SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (historySongs.isNotEmpty)
                _CollapsibleSection(
                  title: 'Played',
                  count: historySongs.length,
                  expanded: _playedExpanded,
                  onToggle: () =>
                      setState(() => _playedExpanded = !_playedExpanded),
                  trailing: _ClearButton(
                    label: 'Clear',
                    onTap: () => _confirmClearHistory(context),
                  ),
                  children: historySongs.isEmpty
                      ? [_SectionEmpty(text: 'No played songs')]
                      : [
                          _AnimatedHistoryList(
                            songs: historySongs,
                            horizontalPadding: widget.tileHorizontalPadding,
                            onPlay: (path) {
                              q.queueSignal.playHistoryItem(path);
                            },
                            onDismiss: (path) {
                              q.queueSignal.history.value = [
                                ...q.queueSignal.history.value.where(
                                  (p) => p != path,
                                ),
                              ];
                            },
                          ),
                        ],
                ),
              _CollapsibleSection(
                title: 'Up Next',
                count: upNextSongs.length,
                expanded: _upNextExpanded,
                onToggle: () =>
                    setState(() => _upNextExpanded = !_upNextExpanded),
                trailing: upNextSongs.isNotEmpty
                    ? _ClearButton(
                        label: 'Clear',
                        onTap: () => _confirmClearUpNext(context),
                      )
                    : null,
                children: upNextSongs.isEmpty
                    ? [
                        _SectionEmpty(
                          text: 'Queue is empty — add songs to start listening',
                        ),
                      ]
                    : [
                        _AnimatedUpNextList(
                          songs: upNextSongs,
                          horizontalPadding: widget.tileHorizontalPadding,
                          onDraggingChanged: widget.onDraggingChanged,
                          onDragStateChanged: (isDragging) {
                            setState(() => _isDragging = isDragging);
                          },
                        ),
                      ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }

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
          if (_showBackToTop)
            Positioned(
              bottom: hasNowPlaying ? 96 : 24,
              left: 24,
              child: _BackToTopButton(onTap: _scrollToTop),
            ),
        ],
      );
    });
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History?'),
        content: const Text('This will remove all songs from history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              q.queueSignal.clearHistory();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _confirmClearUpNext(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Up Next?'),
        content: const Text('This will remove all songs from the queue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              q.queueSignal.clearUpNext();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
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
  final List<Widget> children;

  const _CollapsibleSection({
    required this.title,
    required this.count,
    required this.expanded,
    required this.onToggle,
    required this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
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
                ?trailing,
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: Column(children: children),
          secondChild: const SizedBox.shrink(),
          crossFadeState: expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

// ─── Animated Up Next List (reorderable) ─────────────────────────────────────

class _AnimatedUpNextList extends StatefulWidget {
  final List<Song> songs;
  final double horizontalPadding;
  final void Function(int? draggingIndex)? onDraggingChanged;
  final void Function(bool isDragging)? onDragStateChanged;

  const _AnimatedUpNextList({
    required this.songs,
    required this.horizontalPadding,
    this.onDraggingChanged,
    this.onDragStateChanged,
  });

  @override
  State<_AnimatedUpNextList> createState() => _AnimatedUpNextListState();
}

class _AnimatedUpNextListState extends State<_AnimatedUpNextList> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  static const _identityAnimation = AlwaysStoppedAnimation(1.0);

  /// Stable keys so Dismissible state is retained across rebuilds.
  final Map<String, GlobalKey> _itemKeys = {};

  List<Song> _displayedSongs = [];

  @override
  void initState() {
    super.initState();
    _displayedSongs = List.from(widget.songs);
    for (final s in widget.songs) {
      _itemKeys[s.path] ??= GlobalKey();
    }
  }

  @override
  void didUpdateWidget(_AnimatedUpNextList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFromSignal();
  }

  void _syncFromSignal() {
    _displayedSongs = List.from(widget.songs);
    // Ensure all paths have a stable key.
    for (final s in widget.songs) {
      _itemKeys[s.path] ??= GlobalKey();
    }
  }

  void _dismissItem(int index) {
    if (index < 0 || index >= _displayedSongs.length) return;
    final song = _displayedSongs[index];
    _displayedSongs.removeAt(index);
    _itemKeys.remove(song.path);
    setState(() {});
    q.queueSignal.removeFromUpNext(song.path);
  }

  void _showActions(BuildContext context, Song song) {
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
                audioSignal.playSong(song);
              },
            ),
            _ActionTile(
              icon: Icons.keyboard_arrow_up,
              label: 'Move to top',
              onTap: () {
                Navigator.pop(ctx);
                q.queueSignal.moveToTop(song.path);
              },
            ),
            _ActionTile(
              icon: Icons.remove_circle_outline,
              label: 'Remove from queue',
              onTap: () {
                Navigator.pop(ctx);
                q.queueSignal.removeFromUpNext(song.path);
              },
            ),
            _ActionTile(
              icon: Icons.playlist_add,
              label: 'Add to playlist',
              onTap: () {
                Navigator.pop(ctx);
                PlaylistPickerDialog.show(context, song: song);
              },
            ),
            _ActionTile(
              icon: Icons.info_outline,
              label: 'Song info',
              onTap: () {
                Navigator.pop(ctx);
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
    return ListView.builder(
      key: _listKey,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _displayedSongs.length,
      itemBuilder: (context, index) {
        if (index >= _displayedSongs.length) {
          return const SizedBox.shrink();
        }
        final song = _displayedSongs[index];
        final itemKey = _itemKeys[song.path]!;

        return LongPressDraggable<Song>(
          data: song,
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
          child: DragTarget<Song>(
            onWillAcceptWithDetails: (details) =>
                details.data.path != song.path,
            onAcceptWithDetails: (details) {
              final oldIdx = _displayedSongs.indexWhere(
                (s) => s.path == details.data.path,
              );
              if (oldIdx < 0 || oldIdx == index) return;
              q.queueSignal.reorderUpNext(oldIdx, index);
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
                  onMore: () => _showActions(context, song),
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
  final List<Song> songs;
  final double horizontalPadding;
  final void Function(String songPath) onPlay;
  final void Function(String songPath) onDismiss;

  const _AnimatedHistoryList({
    required this.songs,
    required this.horizontalPadding,
    required this.onPlay,
    required this.onDismiss,
  });

  @override
  State<_AnimatedHistoryList> createState() => _AnimatedHistoryListState();
}

class _AnimatedHistoryListState extends State<_AnimatedHistoryList> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  static const _identityAnimation = AlwaysStoppedAnimation(1.0);

  /// Stable keys so Dismissible state is retained across rebuilds.
  final Map<String, GlobalKey> _itemKeys = {};

  List<Song> _displayedSongs = [];

  @override
  void initState() {
    super.initState();
    _displayedSongs = List.from(widget.songs);
    for (final s in widget.songs) {
      _itemKeys[s.path] ??= GlobalKey();
    }
  }

  @override
  void didUpdateWidget(_AnimatedHistoryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFromSignal();
  }

  void _syncFromSignal() {
    _displayedSongs = List.from(widget.songs);
    for (final s in widget.songs) {
      _itemKeys[s.path] ??= GlobalKey();
    }
  }

  void _dismissItem(int index) {
    if (index < 0 || index >= _displayedSongs.length) return;
    final song = _displayedSongs[index];
    _displayedSongs.removeAt(index);
    _itemKeys.remove(song.path);
    setState(() {});
    widget.onDismiss(song.path);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: _listKey,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _displayedSongs.length,
      itemBuilder: (context, index) {
        if (index >= _displayedSongs.length) {
          return const SizedBox.shrink();
        }
        final song = _displayedSongs[index];
        final itemKey = _itemKeys[song.path]!;
        return _AnimatedTile(
          song: song,
          itemKey: itemKey,
          animation: _identityAnimation,
          isRemoval: false,
          onDismissed: () => _dismissItem(index),
          childBuilder: (context) => _HistoryTileContent(
            song: song,
            horizontalPadding: widget.horizontalPadding,
            onTap: () {
              widget.onPlay(song.path);
              audioSignal.playSong(song);
            },
          ),
        );
      },
    );
  }
}

// ─── Shared Animated Tile ───────────────────────────────────────────────────────

/// Wraps a tile in slide+fade animation and Dismissible with a stable key.
class _AnimatedTile extends StatelessWidget {
  final Song song;
  final GlobalKey itemKey;
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

    final slideAnim =
        Tween<Offset>(
          begin: Offset(isRemoval ? -0.15 : 0.15, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: isRemoval ? Curves.easeIn : Curves.easeOut,
          ),
        );

    final child = childBuilder?.call(context) ?? const SizedBox.shrink();

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
              color: Colors.transparent,
              child: Ink(
                color: Colors.transparent,
                child: child is SizedBox ? const SizedBox.shrink() : child,
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Material(
        key: ValueKey('upnext-${song.path}'),
        color: Colors.transparent,
        child: Ink(
          color: Colors.transparent,
          child: ListTile(
            contentPadding: EdgeInsets.only(
              left: horizontalPadding,
              right: horizontalPadding,
              top: 4,
              bottom: 4,
            ),
            leading: SizedBox(
              width: 56,
              height: 48,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(left: 0, top: 0, child: _Artwork(song: song, size: 48)),
                  Positioned(
                    left: 28,
                    top: 14,
                    child: Icon(
                      Icons.drag_handle,
                      color: colorScheme.secondary.withValues(alpha: 0.35),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
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
        ),
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
    return Material(
      color: Colors.transparent,
      child: Ink(
        color: Colors.transparent,
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

class _SectionEmpty extends StatelessWidget {
  final String text;

  const _SectionEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(
            context,
          ).colorScheme.secondary.withValues(alpha: 0.35),
          fontSize: 13,
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

    return Watch((context) {
      final artDir = audioSignal.albumArtDir.value;
      if (artDir == null) return fallbackIcon;
      final artPath = '$artDir/${song.path.hashCode.abs()}.jpg';
      final file = File(artPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          cacheWidth: (size * 2).toInt(),
          cacheHeight: (size * 2).toInt(),
          errorBuilder: (_, _, _) => fallbackIcon,
        );
      }
      return fallbackIcon;
    });
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
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Queue is empty',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add songs to start listening',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}
