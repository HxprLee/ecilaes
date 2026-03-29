import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../models/song.dart';
import '../signals/audio_signal.dart';
import '../widgets/sliver_page_header.dart';
import '../widgets/song_list_view.dart';
import '../widgets/standard_sliver_grid.dart';
import '../widgets/song_grid_card.dart';
import '../widgets/song_tile.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SongsListContent extends StatelessWidget {
  const SongsListContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final displaySongs = audioSignal.allSongs.value;
      final isGrid = audioSignal.isSongsGridView.value;
      final artDir = audioSignal.albumArtDir.value;

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            // Header
            SliverPageHeader(
              title: 'Songs',
              actions: [
                IconButton(
                  onPressed: () => audioSignal.isSongsGridView.value = !isGrid,
                  icon: FaIcon(
                    isGrid ? FontAwesomeIcons.list : FontAwesomeIcons.borderAll,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 18,
                  ),
                ),
              ],
            ),

            // Songs List
            if (isGrid)
              StandardSliverGrid<Song>(
                items: displaySongs,
                childAspectRatio: 0.8,
                itemBuilder: (context, song, index) {
                  return SongGridCard(
                    song: song,
                    artPath: SongTile.getArtPath(song.path, artDir),
                    onTap: () => audioSignal.playSong(song),
                  );
                },
              )
            else
              SongListView(songs: displaySongs, emptyMessage: 'No songs found'),
          ],
        ),
      );
    });
  }
}
