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
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:signals/signals_flutter.dart';
import '../../signals/search_signal.dart';
import '../../services/navigation/back_handler.dart';
import '../../services/song_cache.dart';
import '../../services/YoutubeDatasource.dart';
import 'widgets/search_filter_chips.dart';
import 'local_search_tab.dart';
import 'youtube_search_tab.dart';

class SearchResultScreen extends StatefulWidget {
  const SearchResultScreen({super.key});

  @override
  State<SearchResultScreen> createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends State<SearchResultScreen> with SingleTickerProviderStateMixin {
  String? _artDirPath;
  late TabController _tabController;

  static const _ytFilterOptions = [
    FilterOption('Songs', SearchFilter.songs, FontAwesomeIcons.music),
    FilterOption('Videos', SearchFilter.videos, FontAwesomeIcons.video),
    FilterOption('Albums', SearchFilter.albums, FontAwesomeIcons.recordVinyl),
    FilterOption('Artists', SearchFilter.artists, FontAwesomeIcons.userGroup),
    FilterOption('Community Playlists', SearchFilter.community_playlists, FontAwesomeIcons.users),
    FilterOption('Trending Playlists', SearchFilter.featured_playlists, FontAwesomeIcons.fire),
    FilterOption('Podcasts', SearchFilter.podcasts, FontAwesomeIcons.podcast),
    FilterOption('Episodes', SearchFilter.episodes, FontAwesomeIcons.circlePlay),
  ];

  static const _localFilterOptions = [
    FilterOption('Songs', LocalSearchFilter.songs, FontAwesomeIcons.music),
    FilterOption('Playlists', LocalSearchFilter.playlists, FontAwesomeIcons.list),
    FilterOption('Albums', LocalSearchFilter.albums, FontAwesomeIcons.recordVinyl),
    FilterOption('Artists', LocalSearchFilter.artists, FontAwesomeIcons.userGroup),
    FilterOption('Folders', LocalSearchFilter.folders, FontAwesomeIcons.folder),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initArtDir();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initArtDir() async {
    final path = await SongCache.artDir;
    if (mounted) {
      setState(() {
        _artDirPath = path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            // Honour the same priority list as the system back button so
            // Escape on the search-results screen feels identical to
            // pressing back on Android.
            final result = appBackHandler.invoke(context);
            if (result.handled) {
              searchSignal.searchQuery.value = '';
            }
          },
        },
        child: ListenableBuilder(
          listenable: _tabController,
          builder: (context, _) {
            final currentTab = _tabController.index;
            return Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 80),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Container(
                      height: 36,
                      width: 360,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(67),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(67),
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        labelColor: Theme.of(context).colorScheme.onSecondary,
                        unselectedLabelColor: Theme.of(context).colorScheme.secondary,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        tabs: const [
                          Tab(text: 'Local'),
                          Tab(text: 'YouTube'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SignalBuilder(builder: (context) {
                  if (currentTab == 0) {
                    return SearchFilterChips<LocalSearchFilter>(
                      options: _localFilterOptions,
                      currentFilter: searchSignal.localSearchFilter.value,
                      onFilterChanged: (filter) => searchSignal.localSearchFilter.value = filter,
                    );
                  } else {
                    return SearchFilterChips<SearchFilter?>(
                      options: _ytFilterOptions,
                      currentFilter: searchSignal.ytSearchFilter.value,
                      onFilterChanged: (filter) => searchSignal.ytSearchFilter.value = filter,
                    );
                  }
                }),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      SignalBuilder(builder: (context) => LocalResultsTab(
                        filter: searchSignal.localSearchFilter.value,
                        songs: searchSignal.localSearchResults.value,
                        isSearching: searchSignal.searchQuery.value.isNotEmpty,
                        query: searchSignal.searchQuery.value,
                        artDirPath: _artDirPath,
                      )),
                      SignalBuilder(builder: (context) => YouTubeResultsTab(
                        rawResults: searchSignal.ytSearchResults.value,
                        songResults: searchSignal.youtubeSearchResults.value,
                        isSearching: searchSignal.searchQuery.value.isNotEmpty,
                        query: searchSignal.searchQuery.value,
                        artDirPath: _artDirPath,
                        currentFilter: searchSignal.ytSearchFilter.value,
                        onFilterChanged: (filter) => searchSignal.ytSearchFilter.value = filter,
                      )),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
