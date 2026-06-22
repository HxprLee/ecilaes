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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:signals/signals_flutter.dart';
import '../../signals/audio_signal.dart';
import '../../signals/queue_signal.dart' as q;
import '../common/flyout_sheet.dart';
import 'now_playing_row.dart';
import 'queue_list_core.dart';

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
      return const QueueSheetBody();
    },
  );
}

class QueueSheetBody extends StatefulWidget {
  const QueueSheetBody({super.key});

  @override
  State<QueueSheetBody> createState() => _QueueSheetBodyState();
}

class _QueueSheetBodyState extends State<QueueSheetBody> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _filterText = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() => _filterText = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FlyoutSheet(
      mainAxisSize: MainAxisSize.max,
      safeAreaTop: true,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (mounted) Navigator.pop(context);
          },
          const SingleActivator(LogicalKeyboardKey.keyR, control: true):
              () => audioSignal.toggleRepeat(),
          const SingleActivator(LogicalKeyboardKey.keyR, meta: true):
              () => audioSignal.toggleRepeat(),
          const SingleActivator(
            LogicalKeyboardKey.keyS,
            shift: true,
            control: true,
          ): () => audioSignal.toggleShuffle(),
          const SingleActivator(
            LogicalKeyboardKey.keyS,
            shift: true,
            meta: true,
          ): () => audioSignal.toggleShuffle(),
          const SingleActivator(LogicalKeyboardKey.keyF, control: true):
              () => _searchFocusNode.requestFocus(),
          const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
              () => _searchFocusNode.requestFocus(),
          const SingleActivator(
            LogicalKeyboardKey.arrowUp,
            control: true,
          ): () {
            final upNext = q.queueSignal.upNextPaths;
            if (upNext.isNotEmpty) q.queueSignal.moveToTop(upNext.first);
          },
          const SingleActivator(
            LogicalKeyboardKey.arrowUp,
            meta: true,
          ): () {
            final upNext = q.queueSignal.upNextPaths;
            if (upNext.isNotEmpty) q.queueSignal.moveToTop(upNext.first);
          },
        },
        child: Column(
        children: [
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
                    Watch((context) {
                      final total = q.queueSignal.upNextCount +
                          q.queueSignal.historyCount;
                      final filtered = _filterText.trim().isEmpty;
                      return Text(
                        filtered
                            ? '$total tracks'
                            : '$total / filtered',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.secondary.withValues(alpha: 0.6),
                        ),
                      );
                    }),
                    const SizedBox(width: 8),
                    Watch((context) {
                      final isShuffle = audioSignal.isShuffleMode.value;
                      return IconButton(
                        onPressed: () => audioSignal.toggleShuffle(),
                        icon: Icon(
                          Icons.shuffle,
                          size: 20,
                          color: isShuffle
                              ? colorScheme.primary
                              : colorScheme.secondary.withValues(alpha: 0.4),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Shuffle',
                      );
                    }),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: colorScheme.secondary.withValues(alpha: 0.8),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Watch((context) {
                  final current = audioSignal.currentSong.value;
                  if (current == null) return const SizedBox.shrink();
                  return NowPlayingRow(song: current);
                }),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Search queue',
                    isDense: true,
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: colorScheme.secondary.withValues(alpha: 0.5),
                    ),
                    suffixIcon: _filterText.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: QueueListCore(
              showNowPlaying: true,
              showBackToTop: true,
              filterText: _filterText,
            ),
          ),
        ],
        ),
      ),
    );
  }
}
