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
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../../signals/search_signal.dart';
import '../../signals/audio_signal.dart';
import '../../widgets/components/sliver_page_header.dart';
import '../../widgets/components/song_tile.dart';
import '../../models/song.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  @override
  void initState() {
    super.initState();
    searchSignal.loadExploreData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Watch((context) {
        final recentSearches = searchSignal.recentSearches.value;
        final exploreData = searchSignal.exploreData.value;
        final moodCategories = searchSignal.moodCategories.value;
        final isLoading = searchSignal.isLoadingExplore.value;

        return CustomScrollView(
          slivers: [
            const SliverPageHeader(
              title: 'Search',
              subtitle: 'Discover music',
            ),
            if (recentSearches.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Searches',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () => searchSignal.clearRecentSearches(),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ),
              ),
            if (recentSearches.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final query = recentSearches[index];
                      return ListTile(
                        leading: const Icon(Icons.history, size: 20),
                        title: Text(query),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            final current = List<String>.from(recentSearches);
                            current.remove(query);
                            searchSignal.recentSearches.value = current;
                          },
                        ),
                        onTap: () {
                          // TODO: Set text field value in header somehow?
                          // The header controllers are internal to the shells.
                          // Setting the signal alone might not update the TextField unless it's bound.
                          // We'll just push to results for now.
                          searchSignal.searchQuery.value = query;
                          context.go('/search-result');
                        },
                      );
                    },
                    childCount: recentSearches.length,
                  ),
                ),
              ),

            if (isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (exploreData['new_videos'] != null)
                _buildSection(context, 'New Music Videos', exploreData['new_videos']),
              
              if (exploreData['trending'] != null && exploreData['trending']['items'] != null)
                _buildSection(context, 'Trending', exploreData['trending']['items']),

              if (exploreData['new_releases'] != null)
                _buildSection(context, 'New Releases', exploreData['new_releases']),

              if (exploreData['top_songs'] != null && exploreData['top_songs']['items'] != null)
                _buildSection(context, 'Top Songs', exploreData['top_songs']['items']),

              if (exploreData['moods_and_genres'] != null)
                _buildMoods(context, 'Mood & Genres', exploreData['moods_and_genres']),
              
              if (moodCategories.isNotEmpty)
                ...moodCategories.entries.map((e) => _buildMoods(context, e.key, e.value)),
            ],

            SliverToBoxAdapter(
              child: SizedBox(height: audioSignal.reservedHeight.value),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<dynamic> items) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index] as Map<String, dynamic>;
                final titleText = item['title'] ?? item['name'] ?? 'Unknown';
                final thumbnails = item['thumbnails'];
                String thumbnailUrl = '';
                if (thumbnails is List && thumbnails.isNotEmpty) {
                  thumbnailUrl = thumbnails.last['url'] ?? '';
                  if (thumbnailUrl.startsWith('//')) {
                    thumbnailUrl = 'https:$thumbnailUrl';
                  }
                }
                
                final artists = item['artists'];
                String subtitle = '';
                if (artists is List && artists.isNotEmpty) {
                  subtitle = artists.map((a) => (a as Map)['name'] ?? '').join(', ');
                } else if (item['views'] != null) {
                  subtitle = item['views'];
                }

                return SizedBox(
                  width: 160,
                  child: InkWell(
                    onTap: () {
                      if (item['videoId'] != null) {
                        final song = Song(
                          path: 'yt:${item['videoId']}',
                          title: titleText,
                          artist: subtitle,
                          hasAlbumArt: true,
                        );
                        audioSignal.playSong(song);
                      } else if (item['browseId'] != null) {
                        if (item['type'] == 'Album') {
                          context.go(
                            '/youtube/album/${Uri.encodeComponent(item['browseId'])}',
                            extra: {'title': titleText, 'thumbnailUrl': thumbnailUrl},
                          );
                        } else {
                          context.go(
                            '/youtube/playlist/${Uri.encodeComponent(item['browseId'])}',
                            extra: {'title': titleText, 'thumbnailUrl': thumbnailUrl},
                          );
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: item['videoId'] != null ? 16 / 9 : 1.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  image: thumbnailUrl.isNotEmpty ? DecorationImage(
                                    image: NetworkImage(thumbnailUrl),
                                    fit: BoxFit.cover,
                                  ) : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            titleText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoods(BuildContext context, String title, List<dynamic> items) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) {
                final map = item as Map<String, dynamic>;
                return ActionChip(
                  label: Text(map['title'] ?? ''),
                  onPressed: () {
                    if (map['params'] != null) {
                       context.go('/mood/${Uri.encodeComponent(map['params'])}', extra: map['title']);
                    } else {
                       searchSignal.searchQuery.value = map['title'] ?? '';
                       context.go('/search-result');
                    }
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
