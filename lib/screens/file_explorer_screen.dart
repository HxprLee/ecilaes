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
import '../signals/audio_signal.dart';
import '../signals/overlay_signal.dart';
import '../models/song.dart';
import '../services/album_art_cache.dart';
import '../services/navigation/back_handler.dart';
import '../utils/navigation.dart';
import 'package:path/path.dart' as p;
import '../widgets/dialogs/playlist_dialogs.dart';

class FileExplorerScreen extends StatefulWidget {
  final String? initialPath;

  const FileExplorerScreen({super.key, this.initialPath});

  @override
  State<FileExplorerScreen> createState() => _FileExplorerScreenState();
}

class _FileExplorerScreenState extends State<FileExplorerScreen> {
  List<FileSystemEntity>? _items;
  String? _currentPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void didUpdateWidget(FileExplorerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPath != oldWidget.initialPath) {
      _loadItems();
    }
  }

  Future<void> _loadItems() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final path = widget.initialPath ?? await audioSignal.getMusicPath();
    final items = await audioSignal.fetchExplorerItems(path);

    if (mounted) {
      setState(() {
        _currentPath = path;
        _items = items;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _items == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      );
    }

    final currentPath = _currentPath ?? '';

    return SignalBuilder(builder: (context) {
      // The shell's central PopScope + AppBackHandler now owns back
      // navigation. Directory drilling is push-based (`navigatePush`), so
      // a normal system-back pop unwinds the explorer stack until the root
      // is reached; at the root `router.canPop()` is false and the OS takes
      // over. The desktop-only header back arrow delegates to the same
      // handler so the priority list (player minimize, overlay close, push
      // pop, history pop) is honoured.
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.only(
                top:
                    24.0 +
                    ((Platform.isAndroid || Platform.isIOS)
                        ? (50.0 + MediaQuery.of(context).padding.top)
                        : 50.0),
                left: 24.0,
                right: 24.0,
                bottom: 24.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!(Platform.isAndroid || Platform.isIOS)) ...[
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.54),
                          ),
                          onPressed: () => appBackHandler.invoke(context),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          currentPath,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.38),
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Explorer List
            Expanded(
              child: _items!.isEmpty
                  ? Center(
                      child: Text(
                        'No music files found in this folder',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.54),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        0,
                        24,
                        audioSignal.reservedHeight.value,
                      ),
                      itemCount: _items!.length,
                      itemBuilder: (context, index) {
                        final item = _items![index];
                        if (item is Directory) {
                          return _FolderTile(
                            directory: item,
                            onTap: () {
                              navigatePush(
                                context,
                                '/explorer/${Uri.encodeComponent(item.path)}',
                              );
                            },
                          );
                        } else if (item is File) {
                          return _FileTile(
                            file: item,
                            onTap: () => audioSignal.playFile(item),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
            ),
          ],
        ),
      );
    });
  }
}

class _FolderTile extends StatelessWidget {
  final Directory directory;
  final VoidCallback onTap;

  const _FolderTile({required this.directory, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = p.basename(directory.path);

    return ListTile(
      leading: FaIcon(
        FontAwesomeIcons.solidFolder,
        color: Theme.of(context).colorScheme.secondary,
        size: 20,
      ),
      title: Text(
        name,
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
      trailing: IconButton(
        icon: Icon(
          Icons.more_vert,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
        ),
        onPressed: () => _showFolderMenu(context),
      ),
      hoverColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  void _showFolderMenu(BuildContext context) {
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

    overlaySignal.push(ActiveOverlay.folderMenu);

    showMenu(
      context: context,
      position: position,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      items: [
        PopupMenuItem(
          value: 'add_to_playlist',
          child: ListTile(
            leading: Icon(
              Icons.playlist_add,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            title: Text(
              'Add Folder to Playlist',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          onTap: () {
            overlaySignal.pop(ActiveOverlay.folderMenu);
            // We need to show another menu to pick the playlist
            Future.delayed(const Duration(milliseconds: 100), () {
              PlaylistPickerDialog.show(context, folderPath: directory.path);
            });
          },
        ),
      ],
    ).then((_) => overlaySignal.pop(ActiveOverlay.folderMenu));
  }
}

class _FileTile extends StatefulWidget {
  final File file;
  final VoidCallback onTap;

  const _FileTile({required this.file, required this.onTap});

  @override
  State<_FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<_FileTile> {
  Song? _song;
  File? _albumArt;
  bool _artLoaded = false;

  @override
  void initState() {
    super.initState();
    _initSong();
  }

  @override
  void didUpdateWidget(_FileTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.file.path != oldWidget.file.path) {
      _song = null;
      _albumArt = null;
      _artLoaded = false;
      _initSong();
    }
  }

  Future<void> _initSong() async {
    final song = await audioSignal.getExplorerSong(widget.file);
    if (mounted) {
      setState(() {
        _song = song;
      });
      _loadAlbumArt();
    }
  }

  Future<void> _loadAlbumArt() async {
    if (_artLoaded || _song == null) return;
    final art = await AlbumArtCache().getArt(_song!.path);
    if (mounted) {
      setState(() {
        _albumArt = art;
        _artLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_song == null) {
      return const SizedBox(height: 56); // Placeholder height
    }

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
          image: _albumArt != null
              ? DecorationImage(
                  image: ResizeImage(FileImage(_albumArt!), width: 50),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: _albumArt == null
            ? Center(
                child: FaIcon(
                  FontAwesomeIcons.music,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 16,
                ),
              )
            : null,
      ),
      title: Text(
        _song!.title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _song!.artist,
        style: TextStyle(
          color: Theme.of(
            context,
          ).colorScheme.secondary.withValues(alpha: 0.7),
          fontSize: 12,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: widget.onTap,
      trailing: IconButton(
        icon: Icon(
          Icons.more_vert,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
        ),
        onPressed: () => _showFileMenu(context),
      ),
      hoverColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  void _showFileMenu(BuildContext context) {
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

    showMenu(
      context: context,
      position: position,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      items: [
        PopupMenuItem(
          value: 'add_to_playlist',
          child: ListTile(
            leading: Icon(
              Icons.playlist_add,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            title: Text(
              'Add to Playlist',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              PlaylistPickerDialog.show(context, song: _song);
            });
          },
        ),
      ],
    );
  }
}
