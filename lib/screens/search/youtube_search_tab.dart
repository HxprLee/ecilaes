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
import '../../../models/song.dart';
import '../../../signals/search_signal.dart';
import '../../../services/YoutubeDatasource.dart';
import '../../../widgets/components/standard_sliver_list.dart';
import '../../../widgets/components/song_tile.dart';
import '../../../widgets/components/search_skeleton.dart';
import 'widgets/raw_results_list.dart';

class YouTubeResultsTab extends StatefulWidget {
  final List<Map<String, dynamic>> rawResults;
  final List<Song> songResults;
  final bool isSearching;
  final String query;
  final String? artDirPath;
  final SearchFilter? currentFilter;
  final ValueChanged<SearchFilter?> onFilterChanged;

  const YouTubeResultsTab({
    super.key,
    required this.rawResults,
    required this.songResults,
    required this.isSearching,
    required this.query,
    required this.artDirPath,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  State<YouTubeResultsTab> createState() => _YouTubeResultsTabState();
}

class _YouTubeResultsTabState extends State<YouTubeResultsTab> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final hasMore = searchSignal.hasMoreYtResults.value;
    final isLoading = searchSignal.isSearchingYoutube.value;
    if (maxScroll - currentScroll < 300 && hasMore && !isLoading) {
      searchSignal.loadMoreYtResults();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        ..._buildResultsSlivers(context),
        Watch((context) {
          final isLoading = searchSignal.isSearchingYoutube.value;
          final hasMore = searchSignal.hasMoreYtResults.value;
          if (!isLoading && !hasMore) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          );
        }),
      ],
    );
  }

  List<Widget> _buildResultsSlivers(BuildContext context) {
    if (widget.currentFilter == SearchFilter.songs ||
        widget.currentFilter == null) {
      return _buildSongsSlivers(context);
    }

    return RawResultsList.buildSlivers(
      context,
      results: widget.rawResults,
      isSearching: widget.isSearching,
      filterType: widget.currentFilter ?? SearchFilter.songs,
    );
  }

  List<Widget> _buildSongsSlivers(BuildContext context) {
    final resultsWidget = Watch((context) {
      return StandardSliverList<Song>(
        items: widget.songResults,
        isLoading: searchSignal.isSearchingYoutube.value && widget.songResults.isEmpty,
        loadingWidget: const SearchSkeleton(),
        emptyMessage: widget.isSearching ? 'No YouTube songs found' : 'Start typing to search',
        itemBuilder: (context, song, index) => SongTile(
          song: song,
          artDirPath: widget.artDirPath,
          trailing: Text(
            _formatDuration(song.duration ?? Duration.zero),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
              fontSize: 12,
            ),
          ),
        ),
      );
    });

    return [resultsWidget];
  }

  String _formatDuration(Duration? duration) {
    if (duration == null || duration == Duration.zero) return '--:--';
    return '${duration.inMinutes}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }
}
