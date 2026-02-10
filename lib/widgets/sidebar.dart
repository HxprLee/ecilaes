import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';

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
    final isHome = location == '/';
    final isExplorer = location.startsWith('/explorer');
    final isSettings = location.startsWith('/settings');
    final isLibrary = location.startsWith('/library');
    final isSongs = location == '/songs';

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
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: expandedWidth,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(170, 17, 23, 28),
                    border: Border.all(
                      color: const Color.fromARGB(38, 255, 239, 175),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      // Menu Toggle (hide on mobile drawer)
                      if (!widget.isDrawer)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: lerpDouble(4, 12, value)!,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 48,
                                child: Center(
                                  child: IconButton(
                                    icon: const FaIcon(
                                      FontAwesomeIcons.bars,
                                      color: Colors.white70,
                                      size: 20,
                                    ),
                                    onPressed: widget.onToggle,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(
                                      lerpDouble(-20, 0, value)!,
                                      0,
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.only(left: 12),
                                      child: Text(
                                        'Music',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFCE7AC),
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
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (value > 0.5)
                                _buildSectionTitle('Pinned', value),
                              _buildNavItem(
                                FontAwesomeIcons.solidHouse,
                                'Home',
                                value,
                                isSelected: isHome,
                                onTap: () => context.go('/'),
                              ),
                              _buildNavItem(
                                FontAwesomeIcons.youtube,
                                'YouTube Music',
                                value,
                              ),
                              _buildNavItem(
                                FontAwesomeIcons.recordVinyl,
                                'Library',
                                value,
                                isSelected: isLibrary,
                                onTap: () => context.go('/library'),
                              ),
                              const Divider(color: Colors.white10, height: 32),
                              if (value > 0.5)
                                _buildSectionTitle('Library', value),
                              _buildNavItem(
                                FontAwesomeIcons.compactDisc,
                                'Albums',
                                value,
                              ),
                              _buildNavItem(
                                FontAwesomeIcons.music,
                                'Songs',
                                value,
                                isSelected: isSongs,
                                onTap: () => context.go('/songs'),
                              ),
                              _buildNavItem(
                                FontAwesomeIcons.list,
                                'Playlists',
                                value,
                                isSelected: false,
                              ),
                              _buildNavItem(
                                FontAwesomeIcons.solidFolder,
                                'Folders',
                                value,
                                isSelected: isExplorer,
                                onTap: () => context.go('/explorer'),
                              ),
                              _buildNavItem(
                                FontAwesomeIcons.user,
                                'Artists',
                                value,
                              ),
                              _buildNavItem(
                                FontAwesomeIcons.circleCheck,
                                'Downloaded',
                                value,
                              ),
                              const Divider(color: Colors.white10, height: 32),
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
                                      const Text(
                                        'Playlists',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add,
                                          color: Colors.white54,
                                          size: 16,
                                        ),
                                        onPressed: () =>
                                            _showCreatePlaylistDialog(context),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ),
                              Watch((context) {
                                final playlists = audioSignal.playlists.value;
                                return Column(
                                  children: playlists.map((playlist) {
                                    final playlistPath =
                                        '/playlist/${playlist.id}';
                                    return _buildNavItem(
                                      FontAwesomeIcons.list,
                                      playlist.name,
                                      value,
                                      isSelected: location.startsWith(
                                        playlistPath,
                                      ),
                                      onTap: () => context.go(playlistPath),
                                    );
                                  }).toList(),
                                );
                              }),
                              const SizedBox(height: 100),
                            ],
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
            style: const TextStyle(
              color: Colors.white54,
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
    IconData icon,
    String title,
    double value, {
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFCE7AC) : Colors.transparent,
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
                    child: FaIcon(
                      icon,
                      color: isSelected
                          ? Colors.black87
                          : const Color.fromARGB(255, 252, 231, 172),
                      size: 18,
                    ),
                  ),
                ),
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
                                ? Colors.black87
                                : Color.fromARGB(160, 252, 231, 172),
                            fontSize: 16,
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

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                audioSignal.createPlaylist(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
