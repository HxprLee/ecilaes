import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../signals/audio_signal.dart';
import '../signals/navigation_signal.dart';
import '../models/song.dart';
import '../services/album_art_cache.dart';
import 'package:path/path.dart' as p;

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
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFCE7AC)),
        ),
      );
    }

    final currentPath = _currentPath ?? '';

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
                    const Text(
                      'Folders',
                      style: TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFFCE7AC),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white54),
                      onPressed: () {
                        if (navigationSignal.canPopSync) {
                          navigationSignal.goBack(context);
                        } else {
                          // If we can't pop, try to go up one level manually
                          final parent = Directory(currentPath).parent;
                          if (currentPath.endsWith('Music')) {
                            context.go('/');
                          } else {
                            context.go(
                              '/explorer/${Uri.encodeComponent(parent.path)}',
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        currentPath,
                        style: const TextStyle(
                          color: Colors.white38,
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
                ? const Center(
                    child: Text(
                      'No music files found in this folder',
                      style: TextStyle(color: Colors.white54),
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
                            context.push(
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
      leading: const FaIcon(
        FontAwesomeIcons.solidFolder,
        color: Color(0xFFFCE7AC),
        size: 20,
      ),
      title: Text(
        name,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
      trailing: IconButton(
        icon: const Icon(Icons.more_vert, color: Colors.white54),
        onPressed: () => _showFolderMenu(context),
      ),
      hoverColor: Colors.white.withOpacity(0.05),
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

    showMenu(
      context: context,
      position: position,
      color: const Color(0xFF1E222B),
      items: [
        PopupMenuItem(
          value: 'add_to_playlist',
          child: const ListTile(
            leading: Icon(Icons.playlist_add, color: Colors.white70),
            title: Text(
              'Add Folder to Playlist',
              style: TextStyle(color: Colors.white),
            ),
          ),
          onTap: () {
            // We need to show another menu to pick the playlist
            Future.delayed(const Duration(milliseconds: 100), () {
              _showPlaylistPicker(context, directory.path);
            });
          },
        ),
      ],
    );
  }

  void _showPlaylistPicker(BuildContext context, String folderPath) {
    // We need to watch playlists here to show them in the dialog
    // Since this is a method, we can't use Watch directly, but we can access the signal value
    final playlists = audioSignal.playlists.value;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E222B),
        title: const Text(
          'Select Playlist',
          style: TextStyle(color: Colors.white),
        ),
        content: playlists.isEmpty
            ? const Text(
                'No playlists created yet.',
                style: TextStyle(color: Colors.white70),
              )
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    return ListTile(
                      title: Text(
                        playlist.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        audioSignal.addFolderToPlaylist(
                          playlist.id,
                          folderPath,
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added folder to ${playlist.name}'),
                            backgroundColor: const Color(0xFF1E222B),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
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
          color: const Color(0xFF1E222B),
          borderRadius: BorderRadius.circular(4),
          image: _albumArt != null
              ? DecorationImage(
                  image: ResizeImage(FileImage(_albumArt!), width: 50),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: _albumArt == null
            ? const Center(
                child: FaIcon(
                  FontAwesomeIcons.music,
                  color: Colors.white,
                  size: 16,
                ),
              )
            : null,
      ),
      title: Text(
        _song!.title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _song!.artist,
        style: const TextStyle(color: Colors.white54, fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: widget.onTap,
      trailing: IconButton(
        icon: const Icon(Icons.more_vert, color: Colors.white54),
        onPressed: () => _showFileMenu(context),
      ),
      hoverColor: Colors.white.withOpacity(0.05),
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
      color: const Color(0xFF1E222B),
      items: [
        PopupMenuItem(
          value: 'add_to_playlist',
          child: const ListTile(
            leading: Icon(Icons.playlist_add, color: Colors.white70),
            title: Text(
              'Add to Playlist',
              style: TextStyle(color: Colors.white),
            ),
          ),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              _showPlaylistPicker(context, widget.file.path);
            });
          },
        ),
      ],
    );
  }

  void _showPlaylistPicker(BuildContext context, String songPath) {
    final playlists = audioSignal.playlists.value;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E222B),
        title: const Text(
          'Select Playlist',
          style: TextStyle(color: Colors.white),
        ),
        content: playlists.isEmpty
            ? const Text(
                'No playlists created yet.',
                style: TextStyle(color: Colors.white70),
              )
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    return ListTile(
                      title: Text(
                        playlist.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        audioSignal.addSongToPlaylist(playlist.id, songPath);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added to ${playlist.name}'),
                            backgroundColor: const Color(0xFF1E222B),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }
}
