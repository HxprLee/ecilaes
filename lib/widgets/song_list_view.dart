import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import '../models/song.dart';
import '../signals/audio_signal.dart';
import 'song_tile.dart';

class SongListView extends StatelessWidget {
  final List<Song> songs;
  final bool showIndex;
  final Widget Function(BuildContext, Song, int)? trailingBuilder;
  final String emptyMessage;

  final String? playlistId;

  const SongListView({
    super.key,
    required this.songs,
    this.showIndex = false,
    this.trailingBuilder,
    this.emptyMessage = 'No songs found',
    this.playlistId,
  });

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Text(
            emptyMessage,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.54),
            ),
          ),
        ),
      );
    }

    return Watch((context) {
      final reservedHeight = audioSignal.reservedHeight.value;

      return SliverMainAxisGroup(
        slivers: [
          SuperSliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final song = songs[index];
              return SongTile(
                song: song,
                index: showIndex ? index : null,
                trailing: trailingBuilder?.call(context, song, index),
                playlistId: playlistId,
              );
            }, childCount: songs.length),
          ),
          // Bottom padding for player bar
          SliverToBoxAdapter(child: SizedBox(height: reservedHeight)),
        ],
      );
    });
  }
}
