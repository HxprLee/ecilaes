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
import '../../models/playlist.dart';
import '../../signals/audio_signal.dart';
import '../../signals/settings_signal.dart';
import '../../signals/overlay_signal.dart';
import '../components/app_dialog.dart';
import '../components/playlist_cover.dart';

enum _Section { pinned, all }

class _PlaylistDragData {
  final String playlistId;
  final _Section source;
  final int index;

  const _PlaylistDragData({
    required this.playlistId,
    required this.source,
    required this.index,
  });
}

class ManageSidebarPlaylistsDialog extends StatelessWidget {
  const ManageSidebarPlaylistsDialog({super.key});

  static void show(BuildContext context) {
    overlaySignal.push(ActiveOverlay.managePlaylists);

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => const ManageSidebarPlaylistsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      titleIcon: Icon(
        Icons.settings_outlined,
        color: Theme.of(context).colorScheme.secondary,
        size: 24,
      ),
      title: 'Manage Sidebar Playlists',
      maxWidth: 480,
      maxHeight: 540,
      content: SignalBuilder(builder: (context) {
        final allPlaylists = audioSignal.playlists.value;
        final pinnedIds = settingsSignal.pinnedPlaylistIds.value;

        final pinnedPlaylists = <Playlist>[];
        for (final id in pinnedIds) {
          final playlist = allPlaylists.cast<Playlist?>().firstWhere(
            (p) => p?.id == id,
            orElse: () => null,
          );
          if (playlist != null) pinnedPlaylists.add(playlist);
        }

        final unpinnedPlaylists = allPlaylists
            .where((p) => !pinnedIds.contains(p.id))
            .toList();

        return SizedBox(
          height: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SectionLabel(text: 'Pinned (${pinnedPlaylists.length})'),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PinnedSection(playlists: pinnedPlaylists),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      const _SectionLabel(text: 'All Playlists'),
                      const SizedBox(height: 4),
                      _AllSection(playlists: unpinnedPlaylists),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
      actions: [
        OutlinedButton(
          onPressed: () {
            overlaySignal.pop(ActiveOverlay.managePlaylists);
            Navigator.pop(context);
          },
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.2),
            ),
            shape: const StadiumBorder(),
          ),
          child: Text(
            'Cancel',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ),
        FilledButton(
          onPressed: () {
            overlaySignal.pop(ActiveOverlay.managePlaylists);
            Navigator.pop(context);
          },
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.8),
            foregroundColor: Theme.of(context).colorScheme.surface,
            shape: const StadiumBorder(),
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }

  static Future<void> _handleDrop(
    _PlaylistDragData data,
    _Section target,
    int targetIndex,
  ) async {
    final pinned = List<String>.from(settingsSignal.pinnedPlaylistIds.value);

    if (data.source == _Section.pinned && target == _Section.pinned) {
      if (data.index == targetIndex) return;
      if (data.index < targetIndex) targetIndex -= 1;
      final item = pinned.removeAt(data.index);
      pinned.insert(targetIndex, item);
      await settingsSignal.setPinnedPlaylists(pinned);
      return;
    }

    if (data.source == _Section.pinned && target == _Section.all) {
      if (!pinned.contains(data.playlistId)) return;
      pinned.remove(data.playlistId);
      await settingsSignal.setPinnedPlaylists(pinned);
      return;
    }

    if (data.source == _Section.all && target == _Section.pinned) {
      if (pinned.contains(data.playlistId)) return;
      final clampedIndex = targetIndex.clamp(0, pinned.length);
      pinned.insert(clampedIndex, data.playlistId);
      await settingsSignal.setPinnedPlaylists(pinned);
      return;
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _PinnedSection extends StatelessWidget {
  final List<Playlist> playlists;

  const _PinnedSection({required this.playlists});

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return _EmptyDropZone(
        section: _Section.pinned,
        hint: 'Drag playlists here to pin',
      );
    }

    return DragTarget<_PlaylistDragData>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) =>
          ManageSidebarPlaylistsDialog._handleDrop(
            details.data,
            _Section.pinned,
            playlists.length,
          ),
      builder: (context, candidate, rejected) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < playlists.length; i++) ...[
              _DropSlot(
                section: _Section.pinned,
                index: i,
                key: ValueKey('pinned_slot_$i'),
              ),
              _PinnedPlaylistTile(
                key: ValueKey(playlists[i].id),
                playlist: playlists[i],
                index: i,
              ),
            ],
            _DropSlot(section: _Section.pinned, index: playlists.length),
          ],
        );
      },
    );
  }
}

class _AllSection extends StatelessWidget {
  final List<Playlist> playlists;

  const _AllSection({required this.playlists});

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return _EmptyDropZone(
        section: _Section.all,
        hint: 'All playlists are pinned',
      );
    }

    return DragTarget<_PlaylistDragData>(
      onWillAcceptWithDetails: (details) =>
          details.data.source == _Section.pinned,
      onAcceptWithDetails: (details) =>
          ManageSidebarPlaylistsDialog._handleDrop(
            details.data,
            _Section.all,
            playlists.length,
          ),
      builder: (context, candidate, rejected) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < playlists.length; i++) ...[
              _DropSlot(
                section: _Section.all,
                index: i,
                key: ValueKey('all_slot_$i'),
              ),
              _AllPlaylistTile(
                key: ValueKey(playlists[i].id),
                playlist: playlists[i],
                index: i,
              ),
            ],
            _DropSlot(section: _Section.all, index: playlists.length),
          ],
        );
      },
    );
  }
}

class _DropSlot extends StatelessWidget {
  final _Section section;
  final int index;

  const _DropSlot({super.key, required this.section, required this.index});

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;

    return DragTarget<_PlaylistDragData>(
      onWillAcceptWithDetails: (details) {
        if (section == _Section.pinned) return true;
        return details.data.source == _Section.pinned;
      },
      onAcceptWithDetails: (details) =>
          ManageSidebarPlaylistsDialog._handleDrop(
            details.data,
            section,
            index,
          ),
      builder: (context, candidate, rejected) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: candidate.isNotEmpty ? 24 : 4,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: candidate.isNotEmpty
                ? secondary.withValues(alpha: 0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }
}

class _EmptyDropZone extends StatelessWidget {
  final _Section section;
  final String hint;

  const _EmptyDropZone({required this.section, required this.hint});

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;

    return DragTarget<_PlaylistDragData>(
      onWillAcceptWithDetails: (details) {
        if (section == _Section.pinned) return true;
        return details.data.source == _Section.pinned;
      },
      onAcceptWithDetails: (details) =>
          ManageSidebarPlaylistsDialog._handleDrop(details.data, section, 0),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: hovering ? secondary : secondary.withValues(alpha: 0.2),
            ),
            color: hovering
                ? secondary.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                section == _Section.pinned
                    ? Icons.push_pin_outlined
                    : Icons.drag_indicator,
                size: 16,
                color: hovering ? secondary : secondary.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 8),
              Text(
                hint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: hovering
                      ? secondary
                      : secondary.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PinnedPlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final int index;

  const _PinnedPlaylistTile({
    super.key,
    required this.playlist,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;
    final dragData = _PlaylistDragData(
      playlistId: playlist.id,
      source: _Section.pinned,
      index: index,
    );

    final tile = ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Draggable<_PlaylistDragData>(
            data: dragData,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            axis: Axis.vertical,
            feedback: _DragFeedback(
              playlist: playlist,
              width: 380,
              isPinned: true,
            ),
            childWhenDragging: Icon(
              Icons.drag_indicator,
              color: secondary.withValues(alpha: 0.3),
            ),
            child: Icon(
              Icons.drag_indicator,
              color: secondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 4),
          PlaylistCover(
            playlist: playlist,
            width: 40,
            height: 40,
            borderRadius: 4,
          ),
        ],
      ),
      title: Text(
        playlist.name,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: secondary),
      ),
      subtitle: Text(
        '${playlist.songPaths.length} songs',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: secondary.withValues(alpha: 0.5),
          fontSize: 12,
        ),
      ),
      trailing: IconButton(
        icon: Icon(Icons.push_pin, color: secondary, size: 18),
        tooltip: 'Unpin',
        onPressed: () => settingsSignal.togglePinnedPlaylist(playlist.id),
      ),
    );

    return tile;
  }
}

class _AllPlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final int index;

  const _AllPlaylistTile({
    super.key,
    required this.playlist,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;
    final dragData = _PlaylistDragData(
      playlistId: playlist.id,
      source: _Section.all,
      index: index,
    );

    final tile = ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Draggable<_PlaylistDragData>(
            data: dragData,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            axis: Axis.vertical,
            feedback: _DragFeedback(
              playlist: playlist,
              width: 380,
              isPinned: false,
            ),
            childWhenDragging: Icon(
              Icons.drag_indicator,
              color: secondary.withValues(alpha: 0.3),
            ),
            child: Icon(
              Icons.drag_indicator,
              color: secondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 4),
          PlaylistCover(
            playlist: playlist,
            width: 40,
            height: 40,
            borderRadius: 4,
          ),
        ],
      ),
      title: Text(
        playlist.name,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: secondary),
      ),
      subtitle: Text(
        '${playlist.songPaths.length} songs',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: secondary.withValues(alpha: 0.5),
          fontSize: 12,
        ),
      ),
      trailing: IconButton(
        icon: Icon(Icons.push_pin_outlined, color: secondary, size: 18),
        tooltip: 'Pin to sidebar',
        onPressed: () => settingsSignal.togglePinnedPlaylist(playlist.id),
      ),
    );

    return tile;
  }
}

class _DragFeedback extends StatelessWidget {
  final Playlist playlist;
  final double width;
  final bool isPinned;

  const _DragFeedback({
    required this.playlist,
    required this.width,
    required this.isPinned,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(8),
      color: scheme.surface,
      shadowColor: Colors.black.withValues(alpha: 0.5),
      child: SizedBox(
        width: width,
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.drag_indicator,
                color: secondary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              PlaylistCover(
                playlist: playlist,
                width: 40,
                height: 40,
                borderRadius: 4,
              ),
            ],
          ),
          title: Text(
            playlist.name,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: secondary),
          ),
          subtitle: Text(
            '${playlist.songPaths.length} songs',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: secondary.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          trailing: Icon(
            isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            color: secondary,
            size: 18,
          ),
        ),
      ),
    );
  }
}
