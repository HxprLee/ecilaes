import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';
import '../widgets/page_header.dart';
import '../widgets/song_list_view.dart';

class SongsListContent extends StatelessWidget {
  const SongsListContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final displaySongs = audioSignal.allSongs.value;

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            // Header
            const SliverToBoxAdapter(child: PageHeader(title: 'Songs')),

            // Songs List
            SongListView(songs: displaySongs, emptyMessage: 'No songs found'),
          ],
        ),
      );
    });
  }
}
