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
import 'package:signals/signals_flutter.dart';
import '../models/song.dart';
import '../signals/audio_signal.dart';
import '../widgets/components/sliver_page_header.dart';
import '../widgets/components/song_list_view.dart';
import '../widgets/components/standard_sliver_grid.dart';
import '../widgets/components/song_grid_card.dart';
import '../widgets/components/song_tile.dart';
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
