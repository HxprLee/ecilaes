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
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../router.dart' as app_router;
import '../../../signals/audio_signal.dart';
import '../../../signals/settings_signal.dart';
import '../../../signals/navigation_signal.dart';
import '../../../models/playlist.dart';
import '../../../theme/app_theme_tokens.dart';
import '../../playlist_cover.dart';

class DesktopHeaderBar extends StatefulWidget {
  final double leftOffset;
  final double hideContentOpacity;
  final double expansion;
  final TextEditingController searchController;

  const DesktopHeaderBar({
    super.key,
    required this.leftOffset,
    required this.hideContentOpacity,
    required this.expansion,
    required this.searchController,
  });

  @override
  State<DesktopHeaderBar> createState() => _DesktopHeaderBarState();
}

class _DesktopHeaderBarState extends State<DesktopHeaderBar> {
  final FocusNode _searchFocusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _removeOverlay();
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final focused = _searchFocusNode.hasFocus;
    if (_isFocused != focused) {
      setState(() => _isFocused = focused);
      if (focused) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(builder: (context) => _buildOverlay(context));
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  String _getPageTitle(String route) {
    if (route == '/') return 'Home';
    if (route == '/songs') return 'Songs';
    if (route == '/search') return 'Search';
    if (route == '/library') return 'Library';
    if (route == '/explorer') return 'Folders';
    if (route == '/recently-played') return 'Recently Played';
    if (route == '/recently-added') return 'Recently Added';
    if (route == '/playlists') return 'Playlists';
    if (route == '/albums') return 'Albums';
    if (route == '/artists') return 'Artists';
    if (route == '/youtube') return 'YouTube Music';
    if (route.startsWith('/youtube/album')) return 'Album';
    if (route.startsWith('/youtube/artist')) return 'Artist';
    if (route.startsWith('/youtube/playlist')) return 'Playlist';
    if (route.startsWith('/albums/')) {
      final parts = route.split('/');
      if (parts.length >= 4) return Uri.decodeComponent(parts.last);
    }
    if (route.startsWith('/artists/')) {
      final parts = route.split('/');
      if (parts.length >= 3) return Uri.decodeComponent(parts.last);
    }
    if (route == '/settings') return 'Settings';
    if (route == '/settings/customization') return 'Customization';
    if (route == '/settings/playback') return 'Playback';
    if (route == '/settings/library') return 'Library';
    if (route == '/settings/about') return 'About';
    if (route == '/settings/customization/player-layout') return 'Player Bar Layout';
    if (route == '/settings/customization/lyrics-layout') return 'Lyrics Layout';
    if (route == '/settings/customization/actions-layout') return 'Actions Sheet Layout';
    if (route == '/settings/customization/sidebar-layout') return 'Sidebar Items';
    if (route == '/settings/customization/discord-presence') return 'Discord Rich Presence';
    if (route == '/settings/library/manage_cache') return 'Cache Management';
    if (route.startsWith('/explorer/')) return 'Folders';
    if (route.startsWith('/playlist/')) {
      final id = route.split('/').last;
      try {
        final playlist = audioSignal.playlists.value.firstWhere(
          (p) => p.id == id,
        );
        return playlist.name;
      } catch (_) {
        return 'Playlist';
      }
    }
    return '';
  }

  void _selectSuggestion(String suggestion) {
    widget.searchController.text = suggestion;
    widget.searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    audioSignal.searchQuery.value = suggestion;
    audioSignal.searchSuggestions.value = [];
    _removeOverlay();
    _searchFocusNode.unfocus();
    app_router.router.go('/search');
  }

  Widget _buildOverlay(BuildContext context) {
    return Watch((context) {
      final suggestions = audioSignal.searchSuggestions.value;
      final query = audioSignal.searchQuery.value;

      if (suggestions.isEmpty || query.trim().isEmpty || !_isFocused) {
        return const SizedBox.shrink();
      }

      return Positioned(
        width: 600,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 44),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    return ListTile(
                      dense: true,
                      leading: FaIcon(
                        FontAwesomeIcons.magnifyingGlass,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      title: Text(
                        suggestion,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                      onTap: () => _selectSuggestion(suggestion),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Trigger overlay rebuild when suggestions change
    Watch.builder(
      builder: (context) {
        audioSignal.searchSuggestions.value;
        audioSignal.searchQuery.value;
        _updateOverlay();
        return const SizedBox.shrink();
      },
    );

    return Container(
      height: 80,
      padding: EdgeInsets.only(left: 2 + widget.leftOffset, right: 2),
      child: Row(
        children: [
          // Left: Navigation Buttons
          Opacity(
            opacity: widget.hideContentOpacity,
            child: IgnorePointer(
              ignoring: widget.expansion > 0.5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 16),
                  Watch((context) {
                    final canBack = navigationSignal.canGoBack.value;
                    return _CircularIconButton(
                      icon: Icons.chevron_left,
                      onPressed: canBack
                          ? () => navigationSignal.goBack(context)
                          : null,
                      tooltip: 'Back',
                    );
                  }),
                  const SizedBox(width: 8),
                  Watch((context) {
                    final canForward = navigationSignal.canGoForward.value;
                    return _CircularIconButton(
                      icon: Icons.chevron_right,
                      onPressed: canForward
                          ? () => navigationSignal.goForward(context)
                          : null,
                      tooltip: 'Forward',
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),
          // Morphing Page Title and Art
          Watch((context) {
            final titleProgress = audioSignal.headerTitleProgress.value;
            final currentRoute = navigationSignal.currentRoute.value;
            debugPrint('HEADER: currentRoute=$currentRoute');
            final routeTitle = _getPageTitle(currentRoute);
            debugPrint('HEADER: routeTitle=$routeTitle');
            final pageTitle = audioSignal.headerPageTitle.value ?? routeTitle;
            final isVisible = pageTitle.isNotEmpty && titleProgress >= 0.01;

            if (!isVisible) return const SizedBox(width: 0);

            final titleWidth = pageTitle.length * 12.0 + 64.0;
            return SizedBox(
              width: titleWidth,
              child: Opacity(
                opacity: titleProgress,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - titleProgress)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Builder(builder: (context) {
                        final playlistId = currentRoute.startsWith('/playlist/')
                            ? currentRoute.split('/').last
                            : null;
                        Playlist? playlist;
                        if (playlistId != null) {
                          try {
                            playlist = audioSignal.playlists.value.firstWhere(
                              (p) => p.id == playlistId,
                            );
                          } catch (_) {}
                        }

                        if (playlist != null) {
                          return PlaylistCover(
                            playlist: playlist,
                            width: 32,
                            height: 32,
                            borderRadius: 4,
                          );
                        }

                        if (audioSignal.headerArtCover.value != null) {
                          return Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              image: DecorationImage(
                                image: audioSignal.headerArtCoverIsNetwork.value
                                    ? NetworkImage(audioSignal.headerArtCover.value!)
                                    : FileImage(File(audioSignal.headerArtCover.value!)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          pageTitle,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Search Bar — expands to fill remaining space
          Expanded(
            child: Center(
              child: _buildSearchBar(context),
            ),
          ),

          const SizedBox(width: 16),

          // Right: Window Buttons
          AnimatedOpacity(
            opacity: widget.hideContentOpacity,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: widget.expansion > 0.5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (settingsSignal.useCustomWindowControls.value)
                    const _WindowButtons(),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final scheme = context.colorScheme;
    return Opacity(
      opacity: widget.hideContentOpacity,
      child: IgnorePointer(
        ignoring: widget.expansion > 0.5,
        child: CompositedTransformTarget(
          link: _layerLink,
          child: Container(
            height: 40,
            constraints: const BoxConstraints(maxWidth: 600),
            decoration: BoxDecoration(
              color: context.tokens.headerBarBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: scheme.onSurface.withValues(alpha: 0.1),
              ),
            ),
            child: TextField(
              controller: widget.searchController,
              focusNode: _searchFocusNode,
              textAlignVertical: TextAlignVertical.center,
              onChanged: (value) => audioSignal.searchQuery.value = value,
              onSubmitted: (value) {
                audioSignal.searchSuggestions.value = [];
                _removeOverlay();
                final currentRoute = navigationSignal.currentRoute.value;
                if (currentRoute != '/search') {
                  context.go('/search');
                }
              },
              decoration: InputDecoration(
                hintText: 'Search songs, albums, artists',
                hintStyle: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: scheme.onSurface.withValues(alpha: 0.38),
                  size: 20,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  const _CircularIconButton({
    required this.icon,
    this.onPressed,
    required this.tooltip,
  });

  static Color _circleBackground(BuildContext context) {
    return context.tokens.circleIconBackground;
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: MouseRegion(
          cursor: onPressed != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _circleBackground(context),
            ),
            child: Icon(
              icon,
              size: 20,
              color: onPressed != null
                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowButtons extends StatelessWidget {
  const _WindowButtons();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircularWindowButton(
          icon: Icons.keyboard_arrow_down,
          onPressed: () => appWindow.minimize(),
          tooltip: 'Minimize',
        ),
        const SizedBox(width: 8),
        _CircularWindowButton(
          icon: Icons.keyboard_arrow_up,
          onPressed: () => appWindow.maximizeOrRestore(),
          tooltip: 'Maximize',
        ),
        const SizedBox(width: 8),
        _CircularWindowButton(
          icon: Icons.close,
          onPressed: () async {
            if (settingsSignal.backgroundPlayback.value) {
              await windowManager.hide();
            } else {
              appWindow.close();
            }
          },
          tooltip: 'Close',
          isClose: true,
        ),
      ],
    );
  }
}

class _CircularWindowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final bool isClose;

  const _CircularWindowButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.isClose = false,
  });

  static Color _circleBackground(BuildContext context) {
    return context.tokens.circleIconBackground;
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _circleBackground(context),
            ),
            child: Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
