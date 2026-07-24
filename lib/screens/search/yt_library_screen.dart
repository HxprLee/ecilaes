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
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:signals/signals_flutter.dart';
import '../../../signals/audio_signal.dart';
import '../../../services/YoutubeDatasource.dart';
import '../../../utils/navigation.dart';
import '../../../widgets/components/sliver_page_header.dart';
import '../../../widgets/components/standard_sliver_list.dart';
import '../../../widgets/components/standard_sliver_grid.dart';
import '../../../widgets/components/grid_card.dart';

enum YTLibraryType { playlists, albums, artists }

class YtLibraryScreen extends StatefulWidget {
  final YTLibraryType type;

  const YtLibraryScreen({super.key, required this.type});

  @override
  State<YtLibraryScreen> createState() => _YtLibraryScreenState();
}

class _YtLibraryScreenState extends State<YtLibraryScreen> {
  List<Map<String, dynamic>>? _items;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    // 1. Load from cache first
    List<Map<String, dynamic>>? cachedItems;
    try {
      switch (widget.type) {
        case YTLibraryType.playlists:
          cachedItems = await youtubeDatasource.getCachedLibraryPlaylists();
          break;
        case YTLibraryType.albums:
          cachedItems = await youtubeDatasource.getCachedLibraryAlbums();
          break;
        case YTLibraryType.artists:
          cachedItems = await youtubeDatasource.getCachedLibraryArtists();
          break;
      }
    } catch (_) {}

    if (cachedItems != null && cachedItems.isNotEmpty) {
      if (mounted) {
        setState(() {
          _items = cachedItems;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = true);
    }

    // 2. Fetch fresh data in background
    try {
      List<Map<String, dynamic>> items = [];
      switch (widget.type) {
        case YTLibraryType.playlists:
          items = await youtubeDatasource.getLibraryPlaylists();
          break;
        case YTLibraryType.albums:
          items = await youtubeDatasource.getLibraryAlbums();
          break;
        case YTLibraryType.artists:
          items = await youtubeDatasource.getLibraryArtists();
          break;
      }

      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          if (_items == null || _items!.isEmpty) {
            _isLoading = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(builder: (context) {
      final title = switch (widget.type) {
        YTLibraryType.playlists => 'Playlists',
        YTLibraryType.albums => 'Albums',
        YTLibraryType.artists => 'Artists',
      };
      
      final isGrid = audioSignal.isYtLibraryGridView.value;

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            SliverPageHeader(
              title: title,
              subtitle: 'YouTube Music Library',
              actions: [
                IconButton(
                  onPressed: () => audioSignal.isYtLibraryGridView.value = !isGrid,
                  icon: FaIcon(
                    isGrid ? FontAwesomeIcons.list : FontAwesomeIcons.borderAll,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 18,
                  ),
                ),
              ],
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Text('Failed to load: $_error'),
                ),
              )
            else if (_items == null || _items!.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text('No $title found in your library.'),
                ),
              )
            else if (isGrid)
              StandardSliverGrid<Map<String, dynamic>>(
                items: _items!,
                itemBuilder: (context, item, index) {
                  final itemTitle = item['title'] ?? 'Unknown';
                  final browseId = item['browseId'];
                  final description = item['description'] ?? '';
                  final thumbnailUrl = item['thumbnailUrl'] ?? '';

                  return GridCard(
                    title: itemTitle,
                    subtitle: description,
                    textAlign: widget.type == YTLibraryType.artists ? TextAlign.center : TextAlign.start,
                    borderRadius: widget.type == YTLibraryType.artists ? 100 : 12,
                    image: Container(
                      decoration: BoxDecoration(
                        borderRadius: widget.type == YTLibraryType.artists ? BorderRadius.circular(100) : BorderRadius.circular(12),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        image: thumbnailUrl.isNotEmpty ? DecorationImage(
                          image: NetworkImage(thumbnailUrl),
                          fit: BoxFit.cover,
                        ) : null,
                      ),
                      child: thumbnailUrl.isEmpty
                          ? Center(
                              child: FaIcon(
                                widget.type == YTLibraryType.artists ? FontAwesomeIcons.user : FontAwesomeIcons.music,
                                size: 32,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                              ),
                            )
                          : null,
                    ),
                    onTap: () {
                      if (browseId != null) {
                        if (widget.type == YTLibraryType.artists) {
                          navigatePush(
                            context,
                            '/youtube/artist/${Uri.encodeComponent(browseId)}',
                            extra: {
                              'name': itemTitle,
                              'thumbnailUrl': thumbnailUrl,
                            },
                          );
                        } else if (widget.type == YTLibraryType.albums) {
                          navigatePush(
                            context,
                            '/youtube/album/${Uri.encodeComponent(browseId)}',
                            extra: {
                              'title': itemTitle,
                              'thumbnailUrl': thumbnailUrl,
                            },
                          );
                        } else {
                          navigatePush(
                            context,
                            '/youtube/playlist/${Uri.encodeComponent(browseId)}',
                            extra: {
                              'title': itemTitle,
                              'thumbnailUrl': thumbnailUrl,
                            },
                          );
                        }
                      }
                    },
                  );
                },
              )
            else
              StandardSliverList<Map<String, dynamic>>(
                items: _items!,
                emptyMessage: 'No $title found in your library.',
                itemBuilder: (context, item, index) {
                  final itemTitle = item['title'] ?? 'Unknown';
                  final browseId = item['browseId'];
                  final description = item['description'] ?? '';
                  final thumbnailUrl = item['thumbnailUrl'] ?? '';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: widget.type == YTLibraryType.artists ? BorderRadius.circular(24) : BorderRadius.circular(8),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        image: thumbnailUrl.isNotEmpty ? DecorationImage(
                          image: NetworkImage(thumbnailUrl),
                          fit: BoxFit.cover,
                        ) : null,
                      ),
                      child: thumbnailUrl.isEmpty
                          ? Center(
                              child: FaIcon(
                                widget.type == YTLibraryType.artists ? FontAwesomeIcons.user : FontAwesomeIcons.music,
                                size: 18,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      itemTitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: description.isNotEmpty ? Text(
                      description,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ) : null,
                    trailing: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                    ),
                    onTap: () {
                      if (browseId != null) {
                        if (widget.type == YTLibraryType.artists) {
                          navigatePush(
                            context,
                            '/youtube/artist/${Uri.encodeComponent(browseId)}',
                            extra: {
                              'name': itemTitle,
                              'thumbnailUrl': thumbnailUrl,
                            },
                          );
                        } else if (widget.type == YTLibraryType.albums) {
                          navigatePush(
                            context,
                            '/youtube/album/${Uri.encodeComponent(browseId)}',
                            extra: {
                              'title': itemTitle,
                              'thumbnailUrl': thumbnailUrl,
                            },
                          );
                        } else {
                          navigatePush(
                            context,
                            '/youtube/playlist/${Uri.encodeComponent(browseId)}',
                            extra: {
                              'title': itemTitle,
                              'thumbnailUrl': thumbnailUrl,
                            },
                          );
                        }
                      }
                    },
                  );
                },
              ),
            SliverToBoxAdapter(
              child: SizedBox(height: audioSignal.reservedHeight.value),
            ),
          ],
        ),
      );
    });
  }
}