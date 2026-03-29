import 'package:flutter/material.dart';
import '../models/song.dart';
import 'song_tile.dart';
import 'standard_sliver_list.dart';

class SongListView extends StatelessWidget {
  final List<Song> songs;
  final bool showIndex;
  final Widget Function(BuildContext, Song, int)? trailingBuilder;
  final String emptyMessage;
  final String? playlistId;
  final bool addBottomPadding;

  const SongListView({
    super.key,
    required this.songs,
    this.showIndex = false,
    this.trailingBuilder,
    this.emptyMessage = 'No songs found',
    this.playlistId,
    this.addBottomPadding = true,
  });

  @override
  Widget build(BuildContext context) {
    return StandardSliverList<Song>(
      items: songs,
      emptyMessage: emptyMessage,
      addBottomPadding: addBottomPadding,
      itemBuilder: (context, song, index) => SongTile(
        song: song,
        index: showIndex ? index : null,
        trailing: trailingBuilder?.call(context, song, index),
        playlistId: playlistId,
      ),
    );
  }
}
