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
import '../signals/audio_signal.dart';
import '../signals/search_signal.dart';
import '../models/song.dart';
import '../services/YoutubeDatasource.dart';
import '../widgets/components/sliver_page_header.dart';
import '../widgets/components/song_list_view.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      audioSignal.headerPageTitle.value = widget.title;
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
    super.dispose();
  }

  Future<void> _load() async {
    final data = await youtubeDatasource.getAlbumDetail(widget.browseId);
    if (mounted) {
      setState(() {
        _albumData = data;
        _loading = false;
      });
      audioSignal.headerPageTitle.value = data['title'] ?? widget.title;
      final thumb = data['thumbnailUrl'] ?? widget.thumbnailUrl;
      if (thumb.isNotEmpty) {
        audioSignal.headerArtCover.value = thumb;
        audioSignal.headerArtCoverIsNetwork.value = true;
      }
      final tracks = data['tracks'] as List<Song>? ?? [];
      if (tracks.isNotEmpty) {
        searchSignal.ytBrowseResults.value = [
          ...searchSignal.ytBrowseResults.value,
          ...tracks,
        ];
      }
    }
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
          SliverPageHeader(
            title: title,
            subtitle: [artist, if (year.isNotEmpty) year].join(' • '),
            leading: Container(
              width: 120,
              height: 120,
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
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: thumbUrl.isEmpty
                  ? Center(
                      child: Icon(
                        Icons.album,
                        size: 48,
                        color: cs.onSurface.withValues(alpha: 0.2),
                      ),
                    )
                  : null,
            ),
            underTextActions: !_loading && tracks.isNotEmpty
                ? [
                    ElevatedButton.icon(
                      onPressed: () =>
                          audioSignal.playSong(tracks.first, fromList: tracks),
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
                      onPressed: () => audioSignal.playShuffledFromList(tracks),
                      style: OutlinedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                        side: BorderSide(
                          color: cs.secondary.withValues(alpha: 0.3),
                        ),
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

          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (tracks.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  'No tracks found',
                  style: TextStyle(color: cs.secondary.withValues(alpha: 0.6)),
                ),
              ),
            )
          else
            SongListView(
              songs: tracks,
              showIndex: true,
              addBottomPadding: false,
              trailingBuilder: (context, song, index) => IconButton(
                onPressed: () =>
                    showSongMoreActionsSheet(context: context, song: song),
                icon: FaIcon(
                  FontAwesomeIcons.ellipsisVertical,
                  size: 16,
                  color: cs.onSurface.withValues(alpha: 0.38),
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: SignalBuilder(
              builder: (context) =>
                  SizedBox(height: audioSignal.reservedHeight.value),
            ),
          ),
        ],
      ),
    );
  }
}
