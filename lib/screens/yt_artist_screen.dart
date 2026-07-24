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
import '../router/routes.dart';
import '../signals/audio_signal.dart';
import '../signals/search_signal.dart';
import '../models/song.dart';
import '../services/YoutubeDatasource.dart';
import '../utils/navigation.dart';
import '../widgets/components/sliver_page_header.dart';
import '../widgets/components/song_list_view.dart';
import '../widgets/song_actions_sheet.dart';
import '../theme/app_theme_tokens.dart';

class YtArtistScreen extends StatefulWidget {
  final String channelId;
  final String name;
  final String thumbnailUrl;

  const YtArtistScreen({
    super.key,
    required this.channelId,
    required this.name,
    this.thumbnailUrl = '',
  });

  @override
  State<YtArtistScreen> createState() => _YtArtistScreenState();
}

class _YtArtistScreenState extends State<YtArtistScreen> {
  late final Signal<Map<String, dynamic>> _artistData;
  late final Signal<bool> _loading;

  @override
  void initState() {
    super.initState();
    _artistData = signal<Map<String, dynamic>>({});
    _loading = signal<bool>(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      audioSignal.headerPageTitle.value = widget.name;
      final thumb = widget.thumbnailUrl;
      if (thumb.isNotEmpty) {
        audioSignal.headerArtCover.value = thumb;
        audioSignal.headerArtCoverIsNetwork.value = true;
      }
    });
    _load();
  }

  @override
  void dispose() {
    audioSignal.headerPageTitle.value = null;
    audioSignal.headerArtCover.value = null;
    audioSignal.headerArtCoverIsNetwork.value = false;
    _artistData.dispose();
    _loading.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await youtubeDatasource.getArtistDetail(widget.channelId);
    if (!mounted) return;
    _artistData.value = data;
    _loading.value = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      audioSignal.headerPageTitle.value = data['name'] ?? widget.name;
      final thumb = data['thumbnailUrl'] ?? '';
      if (thumb.isNotEmpty) {
        audioSignal.headerArtCover.value = thumb;
        audioSignal.headerArtCoverIsNetwork.value = true;
      }
      final topSongs = data['topSongs'] as List<Song>? ?? [];
      if (topSongs.isNotEmpty) {
        searchSignal.ytBrowseResults.value = [
          ...searchSignal.ytBrowseResults.value,
          ...topSongs,
        ];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final data = _artistData.value;
        final loading = _loading.value;
        final name = data['name'] ?? widget.name;
        final thumbUrl = data['thumbnailUrl'] ?? widget.thumbnailUrl;
        final subscribers = data['subscribers'] ?? '';
        final topSongs = (data['topSongs'] as List<Song>?) ?? [];
        final albums = (data['albums'] as List<Map<String, dynamic>>?) ?? [];
        final singles = (data['singles'] as List<Map<String, dynamic>>?) ?? [];

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: CustomScrollView(
            slivers: [
              SliverPageHeader(
                title: name,
                subtitle: subscribers.isNotEmpty
                    ? '$subscribers subscribers'
                    : null,
                leading: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.surfaceContainerHighest,
                    image: thumbUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(thumbUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: thumbUrl.isEmpty
                      ? Center(
                          child: FaIcon(
                            FontAwesomeIcons.user,
                            size: 48,
                            color: cs.secondary.withValues(alpha: 0.5),
                          ),
                        )
                      : null,
                ),
                underTextActions: !loading && topSongs.isNotEmpty
                    ? [
                        ElevatedButton.icon(
                          onPressed: () => audioSignal.playSong(
                            topSongs.first,
                            fromList: topSongs,
                          ),
                          icon: const FaIcon(FontAwesomeIcons.play, size: 14),
                          label: const Text('Play'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.secondary,
                            foregroundColor: cs.onSecondary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            shape: const StadiumBorder(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () =>
                              audioSignal.playShuffledFromList(topSongs),
                          style: OutlinedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(12),
                            side: BorderSide(
                              color: cs.secondary.withValues(alpha: 0.3),
                            ),
                            foregroundColor: cs.secondary,
                          ),
                          child: FaIcon(
                            FontAwesomeIcons.shuffle,
                            size: 14,
                            color: cs.secondary,
                          ),
                        ),
                      ]
                    : null,
                backgroundImage: thumbUrl.isNotEmpty
                    ? NetworkImage(thumbUrl)
                    : null,
              ),

              if (loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                // Top Songs header
                if (topSongs.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 12.0,
                      ),
                      child: Text(
                        'Popular Songs',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  SongListView(
                    songs: topSongs,
                    showIndex: false,
                    addBottomPadding: false,
                    trailingBuilder: (context, song, index) => IconButton(
                      onPressed: () => showSongMoreActionsSheet(
                        context: context,
                        song: song,
                      ),
                      icon: FaIcon(
                        FontAwesomeIcons.ellipsisVertical,
                        size: 16,
                        color: cs.onSurface.withValues(alpha: 0.38),
                      ),
                    ),
                  ),
                ],

                // Albums
                if (albums.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                      child: Text(
                        'Albums',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 220,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: albums.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final album = albums[index];
                          final thumbs = album['thumbnails'];
                          String artUrl = '';
                          if (thumbs is List && thumbs.isNotEmpty) {
                            artUrl = youtubeDatasource.transformThumbnail(
                              thumbs.last['url']?.toString() ?? '',
                            );
                          }
                          return _AlbumCard(
                            title: album['title'] ?? '',
                            subtitle: album['year']?.toString() ?? '',
                            thumbnailUrl: artUrl,
                            onTap: () {
                              if (album['browseId'] != null) {
                                navigatePush(
                                  context,
                                  '${AppRoutes.youtube}/album/${Uri.encodeComponent(album['browseId'])}',
                                  extra: {
                                    'title': album['title'] ?? '',
                                    'thumbnailUrl': artUrl,
                                  },
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // Singles
                if (singles.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                      child: Text(
                        'Singles',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 220,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: singles.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final single = singles[index];
                          final thumbs = single['thumbnails'];
                          String artUrl = '';
                          if (thumbs is List && thumbs.isNotEmpty) {
                            artUrl = youtubeDatasource.transformThumbnail(
                              thumbs.last['url']?.toString() ?? '',
                            );
                          }
                          return _AlbumCard(
                            title: single['title'] ?? '',
                            subtitle: single['year']?.toString() ?? '',
                            thumbnailUrl: artUrl,
                            onTap: () {
                              if (single['browseId'] != null) {
                                navigatePush(
                                  context,
                                  '${AppRoutes.youtube}/album/${Uri.encodeComponent(single['browseId'])}',
                                  extra: {
                                    'title': single['title'] ?? '',
                                    'thumbnailUrl': artUrl,
                                  },
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],

              SliverToBoxAdapter(
                child: SignalBuilder(
                  builder: (context) =>
                      SizedBox(height: audioSignal.reservedHeight.value),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String thumbnailUrl;
  final VoidCallback onTap;

  const _AlbumCard({
    required this.title,
    required this.subtitle,
    required this.thumbnailUrl,
    required this.onTap,
  });

  static Color _placeholderIconColor(BuildContext context) {
    if (context.isMaterial3) {
      return context.colorScheme.onSurface.withValues(alpha: 0.2);
    }
    return Colors.white24;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: thumbnailUrl.isNotEmpty
                    ? Image.network(
                        thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, _, _) => Container(
                          color: Colors.grey[900],
                          child: Icon(
                            Icons.album,
                            color: _AlbumCard._placeholderIconColor(context),
                          ),
                        ),
                      )
                    : Container(color: Colors.grey[900]),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
