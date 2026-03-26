import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';
import '../services/album_art_cache.dart';
import '../theme/app_theme_extensions.dart';

class QuickActionCard extends StatefulWidget {
  final FaIconData icon;
  final String label;

  const QuickActionCard({super.key, required this.icon, required this.label});

  @override
  State<QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<QuickActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        width: 150,
        height: 85,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _isHovered
              ? Theme.of(context)
                    .extension<AppThemeExtension>()!
                    .songCardBackground
                    .withValues(alpha: 0.6)
              : Theme.of(
                  context,
                ).extension<AppThemeExtension>()!.songCardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FaIcon(
              widget.icon,
              color: Theme.of(context).colorScheme.secondary,
              size: 18,
            ),
            Text(
              widget.label,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SongCard extends StatefulWidget {
  final String title;
  final String artist;
  final String? songPath; // Use path for lazy loading
  final Color color;
  final VoidCallback? onTap;

  const SongCard({
    super.key,
    required this.title,
    required this.artist,
    this.songPath,
    required this.color,
    this.onTap,
    this.onAddToPlaylist,
  });

  final VoidCallback? onAddToPlaylist;

  @override
  State<SongCard> createState() => _SongCardState();
}

class _SongCardState extends State<SongCard> {
  bool _isHovered = false;
  File? _albumArt;
  bool _artLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAlbumArt();
  }

  @override
  void didUpdateWidget(SongCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songPath != widget.songPath) {
      _artLoaded = false;
      _albumArt = null;
      _loadAlbumArt();
    }
  }

  Future<void> _loadAlbumArt() async {
    if (widget.songPath == null || _artLoaded) return;

    final art = await AlbumArtCache().getArt(widget.songPath!);
    if (mounted) {
      setState(() {
        _albumArt = art;
        _artLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.0,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: BorderRadius.circular(8),
                        image: _albumArt != null
                            ? DecorationImage(
                                image: ResizeImage(
                                  FileImage(_albumArt!),
                                  width:
                                      200, // Optimize memory: decode at smaller size
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _albumArt == null
                          ? Center(
                              child: FaIcon(
                                FontAwesomeIcons.music,
                                size: 36,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.5),
                              ),
                            )
                          : null,
                    ),
                    if (_isHovered || Platform.isAndroid || Platform.isIOS)
                      Positioned.fill(
                        child: Watch((context) {
                          final currentSong = audioSignal.currentSong.value;
                          final isThisSong =
                              currentSong?.path == widget.songPath;
                          final isPlaying = audioSignal.isPlaying.value;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: isThisSong && isPlaying
                                      ? FaIcon(
                                          FontAwesomeIcons.chartSimple,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                          size: 32,
                                        )
                                      : GestureDetector(
                                          onTap: widget.onTap,
                                          child: FaIcon(
                                            FontAwesomeIcons.play,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                            size: 36,
                                          ),
                                        ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.more_vert,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      size: 24,
                                    ),
                                    onPressed: () => _showContextMenu(context),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final themeExt = Theme.of(context).extension<AppThemeExtension>()!;

    showMenu(
      context: context,
      position: position,
      color: themeExt.songCardBackground,
      items: [
        PopupMenuItem(
          value: 'add_to_playlist',
          child: ListTile(
            leading: Icon(
              Icons.playlist_add,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            title: Text(
              'Add to Playlist',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ),
        PopupMenuItem(
          value: 'play_next',
          child: ListTile(
            leading: Icon(
              Icons.skip_next,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            title: Text(
              'Play Next',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ),
      ],
    ).then((value) {
      if (value == 'add_to_playlist' && widget.onAddToPlaylist != null) {
        widget.onAddToPlaylist!();
      }
    });
  }
}
