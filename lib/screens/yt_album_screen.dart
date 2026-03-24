import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';
import '../models/song.dart';
import '../services/YoutubeDatasource.dart';
import '../widgets/page_header.dart';
import '../widgets/song_list_view.dart';
import '../widgets/song_actions_sheet.dart';

class YtAlbumScreen extends StatefulWidget {
  final String browseId;
  final String title;
  final String thumbnailUrl;

  const YtAlbumScreen({
    super.key,
    required this.browseId,
    required this.title,
    this.thumbnailUrl = '',
  });

  @override
  State<YtAlbumScreen> createState() => _YtAlbumScreenState();
}

class _YtAlbumScreenState extends State<YtAlbumScreen> {
  Map<String, dynamic> _albumData = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await youtubeDatasource.getAlbumDetail(widget.browseId);
    if (mounted) setState(() { _albumData = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = _albumData['title'] ?? widget.title;
    final artist = _albumData['artistName'] ?? '';
    final year = _albumData['year'] ?? '';
    final thumbUrl = _albumData['thumbnailUrl'] ?? widget.thumbnailUrl;
    final tracks = (_albumData['tracks'] as List<Song>?) ?? [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(
              title: title,
              subtitle: [artist, if (year.isNotEmpty) year].join(' • '),
              leading: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: cs.surfaceContainerHighest,
                  image: thumbUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(thumbUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: thumbUrl.isEmpty
                    ? Center(
                        child: Icon(Icons.album, size: 64,
                          color: cs.onSurface.withValues(alpha: 0.2)),
                      )
                    : null,
              ),
            ),
          ),

          // Actions
          if (!_loading && tracks.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => audioSignal.playSong(tracks.first, fromList: tracks),
                      icon: const FaIcon(FontAwesomeIcons.play, size: 16),
                      label: const Text('Play'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.secondary,
                        foregroundColor: cs.onSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        final shuffled = List<Song>.from(tracks)..shuffle();
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

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (tracks.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text('No tracks found', style: TextStyle(color: cs.secondary.withValues(alpha: 0.6))),
              ),
            )
          else
            SongListView(
              songs: tracks,
              showIndex: true,
              trailingBuilder: (context, song, index) => IconButton(
                onPressed: () => showSongMoreActionsSheet(context: context, song: song),
                icon: FaIcon(FontAwesomeIcons.ellipsisVertical, size: 16,
                  color: cs.onSurface.withValues(alpha: 0.38)),
              ),
            ),

          SliverToBoxAdapter(
            child: Watch((context) => SizedBox(height: audioSignal.reservedHeight.value)),
          ),
        ],
      ),
    );
  }
}
