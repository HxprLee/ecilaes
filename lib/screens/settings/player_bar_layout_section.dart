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
import 'package:signals/signals_flutter.dart';
import '../../signals/audio_signal.dart';
import '../../signals/settings_signal.dart';
import '../../theme/app_theme_tokens.dart';
import '../../widgets/components/settings_section.dart';
import '../../widgets/components/sliver_page_header.dart';

class PlayerBarLayoutSection extends StatelessWidget {
  const PlayerBarLayoutSection({super.key});

  static const List<String> _allActionIds = [
    'add_to_playlist',
    'play_next',
    'add_to_queue',
    'remove_from_playlist',
    'go_to_album',
    'go_to_artist',
    'sleep_timer',
    'speed',
    'info',
    'share',
    'shuffle',
    'repeat',
    'lyrics',
    'queue',
    'more',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          const SliverPageHeader(title: 'Player Bar Layout', maxWidth: 600),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    const SettingsSectionLabel('Player Bar Actions'),
                    _buildActionsList(
                      context: context,
                      actionsSignal: settingsSignal.playerBarActions,
                      collectionId: 'player',
                    ),

                    const SizedBox(height: 32),
                    _buildHiddenActions(context),

                    const SizedBox(height: 32),
                    SignalBuilder(builder: (context) =>
                          SizedBox(height: audioSignal.reservedHeight.value),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsList({
    required BuildContext context,
    required ListSignal<String> actionsSignal,
    required String collectionId,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SignalBuilder(builder: (context) {
        final actions = actionsSignal.value;

        return DragTarget<_ActionDragData>(
          onWillAcceptWithDetails: (details) => details.data.id != '',
          onAcceptWithDetails: (details) {
            _handleDrop(details.data, collectionId, actions.length);
          },
          builder: (context, candidateData, rejectedData) {
            return Container(
              decoration: BoxDecoration(
                color: context.tokens.sidebarBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: candidateData.isNotEmpty
                      ? context.colorScheme.secondary
                      : context.accentBorder(0.1),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < actions.length; i++) ...[
                    _buildDropZone(collectionId, i),
                    _buildActionTile(
                      context: context,
                      actionId: actions[i],
                      collectionId: collectionId,
                      index: i,
                    ),
                  ],
                  if (actions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Empty - Drag actions here',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    )
                  else
                    _buildDropZone(collectionId, actions.length),
                ],
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildDropZone(String collectionId, int index) {
    return DragTarget<_ActionDragData>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        _handleDrop(details.data, collectionId, index);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: candidateData.isNotEmpty ? 40 : 4,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty
                ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: candidateData.isNotEmpty
              ? const Center(child: Icon(Icons.add, size: 16))
              : null,
        );
      },
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required String actionId,
    required String collectionId,
    required int index,
  }) {
    final icon = _getSimplifiedActionIcon(actionId);
    final label = _getSimplifiedActionLabel(actionId);
    final dragData = _ActionDragData(
      id: actionId,
      sourceCollection: collectionId,
      index: index,
    );

    final tile = ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.secondary,
        size: 20,
      ),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              Icons.close,
              size: 18,
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
            ),
            onPressed: () => _hideAction(actionId),
            tooltip: 'Hide Action',
          ),
          const Icon(Icons.drag_handle, size: 20),
        ],
      ),
    );

    return LongPressDraggable<_ActionDragData>(
      data: dragData,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surface,
        child: Container(
          width: 300,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.secondary),
            borderRadius: BorderRadius.circular(8),
          ),
          child: tile,
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: tile),
      child: tile,
    );
  }

  void _handleDrop(
    _ActionDragData data,
    String targetCollection,
    int targetIndex,
  ) {
    if (data.sourceCollection == targetCollection &&
        data.index == targetIndex) {
      return;
    }

    final player = List<String>.from(settingsSignal.playerBarActions.value);

    // Remove from source (if it was from player)
    String? removedId;
    if (data.sourceCollection == 'player') {
      removedId = player.removeAt(data.index);
    } else if (data.sourceCollection == 'hidden') {
      removedId = data.id;
    }

    if (removedId == null) return;

    // Adjust target index if moving within the same list
    var adjustedIndex = targetIndex;
    if (data.sourceCollection == targetCollection && data.index < targetIndex) {
      adjustedIndex -= 1;
    }

    // Insert into target
    if (targetCollection == 'player') {
      player.insert(adjustedIndex.clamp(0, player.length), removedId);
    }

    settingsSignal.updatePlayerBarActions(player);
  }

  void _hideAction(String actionId) {
    final player = List<String>.from(settingsSignal.playerBarActions.value);
    player.remove(actionId);
    settingsSignal.updatePlayerBarActions(player);
  }

  Widget _buildHiddenActions(BuildContext context) {
    return SignalBuilder(builder: (context) {
      final player = settingsSignal.playerBarActions.value;
      final hidden = _allActionIds.where((id) => !player.contains(id)).toList();

      if (hidden.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsSectionLabel('Hidden Actions'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DragTarget<_ActionDragData>(
              onWillAcceptWithDetails: (details) =>
                  details.data.sourceCollection != 'hidden',
              onAcceptWithDetails: (details) {
                _handleDrop(details.data, 'hidden', 0);
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  decoration: BoxDecoration(
                    color: context.tokens.sidebarBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: candidateData.isNotEmpty
                          ? context.colorScheme.error.withValues(alpha: 0.5)
                          : context.accentBorder(0.1),
                    ),
                  ),
                  child: Column(
                    children: hidden.asMap().entries.map((entry) {
                      final i = entry.key;
                      final id = entry.value;
                      final icon = _getSimplifiedActionIcon(id);
                      final label = _getSimplifiedActionLabel(id);
                      final dragData = _ActionDragData(
                        id: id,
                        sourceCollection: 'hidden',
                        index: i,
                      );

                      final tile = ListTile(
                        leading: Icon(
                          icon,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                          size: 20,
                        ),
                        title: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.add,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          onPressed: () => _addAction(id),
                          tooltip: 'Add to Player Bar',
                        ),
                      );

                      return LongPressDraggable<_ActionDragData>(
                        data: dragData,
                        feedback: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          color: Theme.of(context).colorScheme.surface,
                          child: Container(
                            width: 300,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: tile,
                          ),
                        ),
                        childWhenDragging: Opacity(opacity: 0.3, child: tile),
                        child: tile,
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  void _addAction(String actionId) {
    final player = List<String>.from(settingsSignal.playerBarActions.value);
    player.add(actionId);
    settingsSignal.updatePlayerBarActions(player);
  }

  IconData _getSimplifiedActionIcon(String id) {
    switch (id) {
      case 'add_to_playlist':
        return Icons.playlist_add;
      case 'play_next':
        return Icons.playlist_play;
      case 'add_to_queue':
        return Icons.queue_music;
      case 'remove_from_playlist':
        return Icons.playlist_remove;
      case 'go_to_album':
        return Icons.album_outlined;
      case 'go_to_artist':
        return Icons.person_outline;
      case 'sleep_timer':
        return Icons.timer_outlined;
      case 'speed':
        return Icons.speed;
      case 'info':
        return Icons.info_outline;
      case 'share':
        return Icons.share_outlined;
      case 'shuffle':
        return Icons.shuffle;
      case 'repeat':
        return Icons.repeat;
      case 'lyrics':
        return Icons.music_note;
      case 'queue':
        return Icons.format_list_bulleted;
      case 'more':
        return Icons.more_horiz;
      default:
        return Icons.help_outline;
    }
  }

  String _getSimplifiedActionLabel(String id) {
    switch (id) {
      case 'add_to_playlist':
        return 'Add to playlist';
      case 'play_next':
        return 'Play next';
      case 'add_to_queue':
        return 'Add to queue';
      case 'remove_from_playlist':
        return 'Remove from playlist';
      case 'go_to_album':
        return 'Go to album';
      case 'go_to_artist':
        return 'Go to artist';
      case 'sleep_timer':
        return 'Sleep timer';
      case 'speed':
        return 'Playback speed';
      case 'info':
        return 'Song info';
      case 'share':
        return 'Share';
      case 'shuffle':
        return 'Shuffle mode';
      case 'repeat':
        return 'Repeat mode';
      case 'lyrics':
        return 'Lyrics';
      case 'queue':
        return 'Queue';
      case 'more':
        return 'More options';
      default:
        return 'Unknown';
    }
  }
}

class _ActionDragData {
  final String id;
  final String sourceCollection;
  final int index;

  _ActionDragData({
    required this.id,
    required this.sourceCollection,
    required this.index,
  });
}
