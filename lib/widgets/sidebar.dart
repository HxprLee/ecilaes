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
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';
import '../signals/settings_signal.dart';
import '../theme/app_theme_tokens.dart';
import '../models/playlist.dart';
import 'components/playlist_cover.dart';
import 'dart:io';

class Sidebar extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback onToggle;
  final bool isDrawer;

  const Sidebar({
    super.key,
    required this.isCollapsed,
    required this.onToggle,
    this.isDrawer = false,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    if (!widget.isCollapsed) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(Sidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCollapsed != oldWidget.isCollapsed) {
      if (widget.isCollapsed) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final isSettings = location.startsWith('/settings');

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        final expandedWidth = lerpDouble(70.0, 250.0, value)!;

        return Container(
          margin: widget.isDrawer
              ? const EdgeInsets.all(12)
              : const EdgeInsets.all(8),
          child: SafeArea(
            child: ClipRRect(
              borderRadius: widget.isDrawer
                  ? BorderRadius.circular(8)
                  : BorderRadius.circular(6),
              child: BackdropFilter(
                filter: settingsSignal.enableGlobalBlur.value
                    ? ImageFilter.blur(sigmaX: 20, sigmaY: 20)
                    : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: Container(
                  width: expandedWidth,
                  decoration: BoxDecoration(
                    color: context.tokens.sidebarBackground.withValues(
                      alpha: settingsSignal.enableGlobalBlur.value
                          ? 0.67
                          : 1.0,
                    ),
                    border: Border.all(
                      color: context.accentBorder(0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      // Menu Toggle (hide on mobile drawer)
                      if (!widget.isDrawer)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Tooltip(
                                message: value < 0.5
                                    ? (widget.isCollapsed
                                        ? 'Expand Sidebar'
                                        : 'Collapse Sidebar')
                                    : '',
                                child: InkWell(
                                  onTap: widget.onToggle,
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 52,
                                    height: 48,
                                    child: Center(
                                      child: SvgPicture.asset(
                                        'assets/app_icon.svg',
                                        width: 24,
                                        height: 24,
                                        colorFilter: ColorFilter.mode(
                                          Theme.of(context).colorScheme.secondary,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                                if (value > 0.05)
                                  Expanded(
                                    child: Opacity(
                                      opacity: value,
                                      child: Transform.translate(
                                        offset: Offset(
                                          lerpDouble(-20, 0, value)!,
                                          0,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 12),
                                          child: Text(
                                            'ecilaes',
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.secondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.fade,
                                            softWrap: false,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      if (!widget.isDrawer) const SizedBox(height: 20),

                      // Navigation Items
                      Expanded(
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                          child: SingleChildScrollView(
                            child: Watch((context) {
                            final pinnedItemsIds =
                                settingsSignal.pinnedSidebarItems.value;
                            final currentLocation = GoRouterState.of(
                              context,
                            ).uri.toString();

                            final allAvailableItems = {
                              'albums': {
                                'icon': FontAwesomeIcons.compactDisc,
                                'label': 'Albums',
                                'onTap': () => context.go('/albums'),
                                'isSelected': currentLocation == '/albums',
                              },
                              'songs': {
                                'icon': FontAwesomeIcons.music,
                                'label': 'Songs',
                                'onTap': () => context.go('/songs'),
                                'isSelected': currentLocation == '/songs',
                              },
                              'playlists': {
                                'icon': FontAwesomeIcons.list,
                                'label': 'Playlists',
                                'onTap': () => context.go('/playlists'),
                                'isSelected': currentLocation.startsWith(
                                  '/playlists',
                                ),
                              },
                              'folders': {
                                'icon': FontAwesomeIcons.solidFolder,
                                'label': 'Folders',
                                'onTap': () => context.go('/explorer'),
                                'isSelected': currentLocation.startsWith(
                                  '/explorer',
                                ),
                              },
                              'artists': {
                                'icon': FontAwesomeIcons.user,
                                'label': 'Artists',
                                'onTap': () => context.go('/artists'),
                                'isSelected': currentLocation == '/artists',
                              },
                              'downloaded': {
                                'icon': FontAwesomeIcons.circleCheck,
                                'label': 'Downloaded',
                                'onTap': () {}, // Placeholder
                                'isSelected': currentLocation == '/downloaded',
                              },
                            };

                            final pinnedItems = pinnedItemsIds
                                .where(
                                  (id) => allAvailableItems.containsKey(id),
                                )
                                .map((id) => allAvailableItems[id]!)
                                .toList();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildNavItem(
                                  FontAwesomeIcons.solidHouse,
                                  'Home',
                                  value,
                                  isSelected: currentLocation == '/',
                                  onTap: () => context.go('/'),
                                ),
                                _buildNavItem(
                                  FontAwesomeIcons.youtube,
                                  'YouTube Music',
                                  value,
                                  isSelected: currentLocation == '/youtube',
                                  onTap: () => context.go('/youtube'),
                                ),
                                _buildNavItem(
                                  FontAwesomeIcons.recordVinyl,
                                  'Library',
                                  value,
                                  isSelected: currentLocation.startsWith(
                                    '/library',
                                  ),
                                  onTap: () => context.go('/library'),
                                ),
                                if (pinnedItems.isNotEmpty) ...[
                                  Divider(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withValues(alpha: 0.1),
                                    height: 16,
                                  ),
                                  if (value > 0.5)
                                    _buildSectionTitle('Library', value),
                                ],
                                ...pinnedItems.map(
                                  (item) => _buildNavItem(
                                    item['icon'] as FaIconData,
                                    item['label'] as String,
                                    value,
                                    isSelected: item['isSelected'] as bool,
                                    onTap: item['onTap'] as VoidCallback?,
                                  ),
                                ),
                                Divider(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withValues(alpha: 0.1),
                                  height: 32,
                                ),
                                if (value > 0.5)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 12,
                                      right: 12,
                                      bottom: 8,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Playlists',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.54),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.settings_outlined,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.54),
                                            size: 16,
                                          ),
                                          onPressed: () =>
                                              _showManagePlaylistsDialog(
                                                context,
                                              ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ),
                                Watch((context) {
                                  final playlists = audioSignal.playlists.value;
                                  final pinnedIds =
                                      settingsSignal.pinnedPlaylistIds.value;

                                  if (pinnedIds.isEmpty) {
                                    return const SizedBox.shrink();
                                  }

                                  // Filter and sort pinned playlists
                                  final pinnedPlaylists = <Playlist>[];
                                  for (final id in pinnedIds) {
                                    try {
                                      final p = playlists.firstWhere(
                                        (p) => p.id == id,
                                      );
                                      pinnedPlaylists.add(p);
                                    } catch (_) {}
                                  }

                                  return Column(
                                    children: pinnedPlaylists.map((playlist) {
                                      final playlistPath =
                                          '/playlist/${playlist.id}';
                                      return _buildNavItem(
                                        FontAwesomeIcons.list,
                                        playlist.name,
                                        value,
                                        isSelected: currentLocation.startsWith(
                                          playlistPath,
                                        ),
                                        onTap: () => context.go(playlistPath),
                                        imagePath: playlist.imagePath,
                                      );
                                    }).toList(),
                                  );
                                }),
                                const SizedBox(height: 100),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),

                      // Settings at bottom (hide on mobile drawer)
                      _buildNavItem(
                        FontAwesomeIcons.gear,
                        'Settings',
                        value,
                        isSelected: isSettings,
                        onTap: () => context.go('/settings'),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, double value) {
    return Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(lerpDouble(-20, 0, value)!, 0),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 12),
          child: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    FaIconData icon,
    String title,
    double value, {
    bool isSelected = false,
    VoidCallback? onTap,
    String? imagePath,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.secondary
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Tooltip(
        message: value < 0.5 ? title : '',
        child: InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Center(
                    child: Watch((context) {
                      final playlists = audioSignal.playlists.value;
                      Playlist? playlist;
                      try {
                        playlist = playlists.firstWhere((p) => p.name == title);
                      } catch (_) {}

                      if (playlist != null) {
                        return PlaylistCover(
                          playlist: playlist,
                          width: 18,
                          height: 18,
                          borderRadius: 4,
                          iconColor: isSelected
                              ? Theme.of(context).colorScheme.onSecondary
                              : Theme.of(context).colorScheme.secondary,
                        );
                      }

                      return imagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.file(
                                File(imagePath),
                                width: 18,
                                height: 18,
                                fit: BoxFit.cover,
                              ),
                            )
                          : FaIcon(
                              icon,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onSecondary
                                  : Theme.of(context).colorScheme.secondary,
                              size: 18,
                            );
                    }),
                  ),
                ),
                if (value > 0.05)
                  Expanded(
                    child: Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(lerpDouble(-20, 0, value)!, 0),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text(
                            title,
                            style: TextStyle(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onSecondary
                                  : Theme.of(context)
                                      .colorScheme
                                      .secondary
                                      .withValues(alpha: 0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showManagePlaylistsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Watch((context) {
          final allPlaylists = audioSignal.playlists.value;
          final pinnedIds = settingsSignal.pinnedPlaylistIds.value;

          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.settings_outlined,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                const Text('Manage Sidebar Playlists'),
              ],
            ),
            content: SizedBox(
              width: 400,
              height: 500,
              child: Column(
                children: [
                  Expanded(
                    child: ReorderableListView(
                      onReorder: (oldIndex, newIndex) {
                        settingsSignal.reorderPinnedPlaylists(
                          oldIndex,
                          newIndex,
                        );
                      },
                      children: [
                        for (int i = 0; i < pinnedIds.length; i++)
                          FutureBuilder<Playlist?>(
                            key: ValueKey('pinned_${pinnedIds[i]}'),
                            future: Future.value(
                              allPlaylists.cast<Playlist?>().firstWhere(
                                (p) => p?.id == pinnedIds[i],
                                orElse: () => null,
                              ),
                            ),
                            builder: (context, snapshot) {
                              final playlist = snapshot.data;
                              if (playlist == null) {
                                return SizedBox(
                                  key: ValueKey('missing_${pinnedIds[i]}'),
                                );
                              }

                              return ListTile(
                                key: ValueKey(playlist.id),
                                leading: const Icon(Icons.drag_handle),
                                title: Text(playlist.name),
                                trailing: IconButton(
                                  icon: const Icon(Icons.pin_end),
                                  onPressed: () => settingsSignal
                                      .togglePinnedPlaylist(playlist.id),
                                  tooltip: 'Unpin',
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'All Playlists',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: allPlaylists.length,
                      itemBuilder: (context, index) {
                        final playlist = allPlaylists[index];
                        final isPinned = pinnedIds.contains(playlist.id);

                        return ListTile(
                          title: Text(playlist.name),
                          trailing: Checkbox(
                            value: isPinned,
                            onChanged: (_) => settingsSignal
                                .togglePinnedPlaylist(playlist.id),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => _showCreatePlaylistDialog(context),
                child: const Text('New Playlist'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                child: const Text('Done'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _CreatePlaylistDialog(),
    );
  }
}

class _CreatePlaylistDialog extends StatefulWidget {
  const _CreatePlaylistDialog();

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Playlist'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Playlist Name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final name = _controller.text.trim();
            if (name.isNotEmpty) {
              try {
                await audioSignal.createPlaylist(name);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                debugPrint('Error creating playlist: $e');
              }
            }
          },
          style: FilledButton.styleFrom(shape: const StadiumBorder()),
          child: const Text('Create'),
        ),
      ],
    );
  }
}
