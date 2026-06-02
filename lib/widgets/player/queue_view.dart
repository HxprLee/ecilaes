import 'dart:io';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/song.dart';
import '../../signals/audio_signal.dart';
import '../../signals/queue_signal.dart' as q;
import '../../services/YoutubeDatasource.dart';
import '../common/flyout_sheet.dart';

void showQueueSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    isScrollControlled: true,
    useRootNavigator: true,
    sheetAnimationStyle: AnimationStyle(
      curve: const Cubic(0.68, 0.01, 0.55, 0.99),
      duration: const Duration(milliseconds: 500),
    ),
    useSafeArea: true,
    builder: (context) {
      return const QueueView();
    },
  );
}

class QueueView extends StatefulWidget {
  const QueueView({super.key});

  @override
  State<QueueView> createState() => _QueueViewState();
}

class _QueueViewState extends State<QueueView> {
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;
  int? _draggingIndex;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final visible = _scrollController.offset > 200;
    if (_showBackToTop != visible) {
      setState(() => _showBackToTop = visible);
    }
  }

  void _scrollToTop({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    if (animated) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.fastOutSlowIn,
      );
    } else {
      _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FlyoutSheet(
      mainAxisSize: MainAxisSize.max,
      safeAreaTop: true,
      child: Stack(
        children: [
          Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                    children: [
                      Text(
                        'Queue',
                          style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            color: colorScheme.secondary,
                            ),
                      ),
                      const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, size: 20),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                          color: colorScheme.secondary.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Watch((context) {
                      final total = q.queueSignal.upNextCount +
                          q.queueSignal.historyCount;
                      return Text(
                        '$total tracks',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.secondary.withValues(alpha: 0.6),
                        ),
                        );
                      }),
                    ],
                ),
              ),
              
              const Divider(height: 1),
              
              // Body
              Expanded(
                child: _QueueBody(
                  scrollController: _scrollController,
                  onDraggingChanged: (index) {
                    setState(() => _draggingIndex = index);
                  },
                ),
              ),
            ],
          ),
          
          // Back to top FAB
          if (_showBackToTop && _draggingIndex == null)
            Positioned(
              bottom: 24,
              left: 24,
              child: GestureDetector(
                onTap: () => _scrollToTop(),
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
                  child: const Icon(
                    Icons.arrow_upward,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Queue Body ──────────────────────────────────────────────────────────────

class _QueueBody extends StatefulWidget {
  final ScrollController scrollController;
  final void Function(int?) onDraggingChanged;

  const _QueueBody({
    required this.scrollController,
    required this.onDraggingChanged,
  });

  @override
  State<_QueueBody> createState() => _QueueBodyState();
}

class _QueueBodyState extends State<_QueueBody> {
  bool _playedExpanded = true;
  bool _upNextExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final upNextPaths = q.queueSignal.upNext.value;
      final historyPaths = q.queueSignal.history.value;

      final upNextSongs =
          upNextPaths.map((p) => audioSignal.resolveSong(p)).toList();
      final historySongs = historyPaths.reversed
          .map((p) => audioSignal.resolveSong(p))
          .toList();

      final isEmpty = upNextSongs.isEmpty && historySongs.isEmpty;

      if (isEmpty) {
        return _EmptyQueueState();
      }

      return SingleChildScrollView(
        controller: widget.scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Played Section ────────────────────────────────────────────────
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
            children: [
                  for (int i = 0; i < historySongs.length; i++)
                    _HistoryTile(
                      song: historySongs[i],
                      onTap: () {
                        q.queueSignal
                            .playHistoryItem(historySongs[i].path);
                        audioSignal.playSong(historySongs[i]);
                      },
                      onDismiss: () {
                        q.queueSignal.history.value = [
                          ...q.queueSignal.history.value
                              .where((p) => p != historySongs[i].path)
                        ];
                      },
                    ),
                ],
              ),

            // ── Up Next Section ──────────────────────────────────────────────
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
                      const _SectionEmpty(
                        text: 'Queue is empty — add songs to start listening',
                      ),
                    ]
                  : [
                      _UpNextList(
                        songs: upNextSongs,
                        onDraggingChanged: widget.onDraggingChanged,
                      ),
                    ],
            ),

            const SizedBox(height: 24),
          ],
        ),
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
        // Section header (always visible)
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
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),

        // Section content (collapsible)
        AnimatedCrossFade(
          firstChild: Column(children: children),
          secondChild: const SizedBox.shrink(),
          crossFadeState:
              expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

// ─── Up Next List (reorderable) ─────────────────────────────────────────────

class _UpNextList extends StatefulWidget {
  final List<Song> songs;
  final void Function(int?) onDraggingChanged;

  const _UpNextList({
    required this.songs,
    required this.onDraggingChanged,
  });

  @override
  State<_UpNextList> createState() => _UpNextListState();
}

class _UpNextListState extends State<_UpNextList> {
  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: widget.songs.length,
      onReorder: (oldIndex, newIndex) {
        q.queueSignal.reorderUpNext(oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final elevation =
                Tween<double>(begin: 0, end: 8).animate(animation).value;
            return Material(
              elevation: elevation,
              shadowColor: Colors.black54,
              borderRadius: BorderRadius.circular(4),
              color: Colors.transparent,
              child: child,
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final song = widget.songs[index];
        return _QueueTile(
          key: ValueKey(song.path),
          song: song,
          index: index,
          isDragging: false,
          onTap: () => audioSignal.playSong(song),
          onDismiss: () => q.queueSignal.removeFromUpNext(song.path),
          onMore: () => _showActions(context, song),
          dragHandle: ReorderableDragStartListener(
            index: index,
            child: Icon(
              Icons.drag_handle,
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.35),
              size: 20,
            ),
          ),
        );
      },
    );
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
                _showAddToPlaylist(context, song);
              },
            ),
            _ActionTile(
              icon: Icons.info_outline,
              label: 'Song info',
              onTap: () {
                Navigator.pop(ctx);
                _showSongInfo(context, song);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAddToPlaylist(BuildContext context, Song song) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add to Playlist'),
        content: const Text('Select a playlist from your library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSongInfo(BuildContext context, Song song) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(song.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Artist: ${song.artist}'),
            if (song.album != null) Text('Album: ${song.album}'),
            if (song.duration != null)
              Text('Duration: ${_fmt(song.duration!)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

// ─── Queue Tile ─────────────────────────────────────────────────────────────

class _QueueTile extends StatelessWidget {
  final Song song;
  final int index;
  final bool isDragging;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final VoidCallback onMore;
  final Widget? dragHandle;

  const _QueueTile({
    super.key,
    required this.song,
    required this.index,
    required this.isDragging,
    required this.onTap,
    required this.onDismiss,
    required this.onMore,
    this.dragHandle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final leading = dragHandle != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              dragHandle!,
              const SizedBox(width: 8),
              _Artwork(song: song, size: 48),
            ],
          )
        : _Artwork(song: song, size: 48);

    return Material(
      color: Colors.transparent,
      child: Dismissible(
        key: ValueKey('dismiss_${song.path}'),
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
        onDismissed: (_) => onDismiss(),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            color: Colors.transparent,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 4),
              leading: leading,
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
              trailing: IconButton(
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
      ),
    );
  }
}

// ─── History Tile ────────────────────────────────────────────────────────────

class _HistoryTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _HistoryTile({
    required this.song,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: Dismissible(
      key: ValueKey('hist_${song.path}'),
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
      onDismissed: (_) => onDismiss(),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          color: Colors.transparent,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
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

// ─── Clear Button ─────────────────────────────────────────────────────────────

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
          color:
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.35),
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
    if (!song.hasAlbumArt) {
      return Icon(Icons.music_note,
          color: Colors.white54, size: size * 0.5);
    }

    if (song.path.startsWith('yt:')) {
      final url = youtubeDatasource.getSongArtworkUrl(song);
      return Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: (size * 2).toInt(),
        cacheHeight: (size * 2).toInt(),
        errorBuilder: (_, __, ___) =>
            Icon(Icons.music_note, color: Colors.white54, size: size * 0.5),
      );
    }
    
    return Watch((context) {
      final artDir = audioSignal.albumArtDir.value;
      if (artDir == null) {
        return Icon(Icons.music_note,
            color: Colors.white54, size: size * 0.5);
      }
      final artPath = '$artDir/${song.path.hashCode.abs()}.jpg';
      final file = File(artPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          cacheWidth: (size * 2).toInt(),
          cacheHeight: (size * 2).toInt(),
          errorBuilder: (_, __, ___) =>
              Icon(Icons.music_note, color: Colors.white54, size: size * 0.5),
        );
      }
      return Icon(Icons.music_note,
          color: Colors.white54, size: size * 0.5);
    });
  }
}

// ─── Empty Queue State ───────────────────────────────────────────────────────

class _EmptyQueueState extends StatelessWidget {
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
