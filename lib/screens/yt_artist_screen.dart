import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';
import '../models/song.dart';
import '../services/YoutubeDatasource.dart';
import '../widgets/sliver_page_header.dart';
import '../widgets/song_list_view.dart';
import '../widgets/song_actions_sheet.dart';

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
  Map<String, dynamic> _artistData = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await youtubeDatasource.getArtistDetail(widget.channelId);
    if (mounted) setState(() { _artistData = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = _artistData['name'] ?? widget.name;
    final thumbUrl = _artistData['thumbnailUrl'] ?? widget.thumbnailUrl;
    final subscribers = _artistData['subscribers'] ?? '';
    final topSongs = (_artistData['topSongs'] as List<Song>?) ?? [];
    final albums = (_artistData['albums'] as List<Map<String, dynamic>>?) ?? [];
    final singles = (_artistData['singles'] as List<Map<String, dynamic>>?) ?? [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverPageHeader(
            title: name,
            subtitle: subscribers.isNotEmpty ? '$subscribers subscribers' : '',
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
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: thumbUrl.isEmpty
                  ? Center(
                      child: FaIcon(FontAwesomeIcons.user, size: 48,
                        color: cs.secondary.withValues(alpha: 0.5)),
                    )
                  : null,
            ),
          ),

          // Play / Shuffle top songs
          if (!_loading && topSongs.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => audioSignal.playSong(topSongs.first, fromList: topSongs),
                      icon: const FaIcon(FontAwesomeIcons.play, size: 16),
                      label: const Text('Play All'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.secondary,
                        foregroundColor: cs.onSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        final shuffled = List<Song>.from(topSongs)..shuffle();
                        audioSignal.playSong(shuffled.first, fromList: shuffled);
                      },
                      icon: const FaIcon(FontAwesomeIcons.shuffle, size: 16),
                      label: const Text('Shuffle'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cs.secondary.withValues(alpha: 0.2)),
                        foregroundColor: cs.secondary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else ...[
            // Top Songs header
            if (topSongs.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                  child: Text('Popular Songs',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                ),
              ),
              SongListView(
                songs: topSongs,
                showIndex: false,
                addBottomPadding: false,
                trailingBuilder: (context, song, index) => IconButton(
                  onPressed: () => showSongMoreActionsSheet(context: context, song: song),
                  icon: FaIcon(FontAwesomeIcons.ellipsisVertical, size: 16,
                    color: cs.onSurface.withValues(alpha: 0.38)),
                ),
              ),
            ],

            // Albums
            if (albums.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                  child: Text('Albums',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: albums.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final album = albums[index];
                      final thumbs = album['thumbnails'];
                      String artUrl = '';
                      if (thumbs is List && thumbs.isNotEmpty) {
                        artUrl = youtubeDatasource.transformThumbnail(thumbs.last['url']?.toString() ?? '');
                      }
                      return _AlbumCard(
                        title: album['title'] ?? '',
                        subtitle: album['year']?.toString() ?? '',
                        thumbnailUrl: artUrl,
                        onTap: () {
                          if (album['browseId'] != null) {
                            context.go('/youtube/album/${Uri.encodeComponent(album['browseId'])}',
                              extra: {'title': album['title'] ?? '', 'thumbnailUrl': artUrl});
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
                  child: Text('Singles',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: singles.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final single = singles[index];
                      final thumbs = single['thumbnails'];
                      String artUrl = '';
                      if (thumbs is List && thumbs.isNotEmpty) {
                        artUrl = youtubeDatasource.transformThumbnail(thumbs.last['url']?.toString() ?? '');
                      }
                      return _AlbumCard(
                        title: single['title'] ?? '',
                        subtitle: single['year']?.toString() ?? '',
                        thumbnailUrl: artUrl,
                        onTap: () {
                          if (single['browseId'] != null) {
                            context.go('/youtube/album/${Uri.encodeComponent(single['browseId'])}',
                              extra: {'title': single['title'] ?? '', 'thumbnailUrl': artUrl});
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
            child: Watch((context) => SizedBox(height: audioSignal.reservedHeight.value)),
          ),
        ],
      ),
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
                    ? Image.network(thumbnailUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[900],
                          child: const Icon(Icons.album, color: Colors.white24),
                        ))
                    : Container(color: Colors.grey[900]),
              ),
            ),
            const SizedBox(height: 8),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontSize: 14, fontWeight: FontWeight.w600)),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
                fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
