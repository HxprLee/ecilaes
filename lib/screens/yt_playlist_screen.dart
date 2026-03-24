import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';
import '../models/song.dart';
import '../services/YoutubeDatasource.dart';
import '../widgets/page_header.dart';
import '../widgets/song_list_view.dart';
import '../widgets/song_actions_sheet.dart';

class YtPlaylistScreen extends StatefulWidget {
  final String playlistId;
  final String title;
  final String thumbnailUrl;

  const YtPlaylistScreen({
    super.key,
    required this.playlistId,
    required this.title,
    this.thumbnailUrl = '',
  });

  @override
  State<YtPlaylistScreen> createState() => _YtPlaylistScreenState();
}

class _YtPlaylistScreenState extends State<YtPlaylistScreen> {
  Map<String, dynamic> _playlistData = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await youtubeDatasource.getPlaylistDetail(widget.playlistId);
    if (mounted) setState(() { _playlistData = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = _playlistData['title'] ?? widget.title;
    final author = _playlistData['author'] ?? '';
    final thumbUrl = _playlistData['thumbnailUrl'] ?? widget.thumbnailUrl;
    final tracks = (_playlistData['tracks'] as List<Song>?) ?? [];
    final trackCount = _playlistData['trackCount'] ?? tracks.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(
              title: title,
              subtitle: [if (author.isNotEmpty) author, '$trackCount songs'].join(' • '),
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
                        child: Icon(Icons.queue_music, size: 64,
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
              showIndex: false,
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
