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

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals_flutter.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/library_models.dart';
import '../services/YoutubeDatasource.dart';
import '../services/youtube_service.dart';
import '../services/local_search_service.dart';
import 'audio_signal.dart';

enum LocalSearchFilter { songs, playlists, albums, artists, folders }

class SearchSignal {
  static final SearchSignal _instance = SearchSignal._internal();
  factory SearchSignal() => _instance;
  SearchSignal._internal() {
    _initEffects();
    _loadRecentSearches();
  }

  final searchQuery = signal<String>('');
  final searchSuggestions = listSignal<String>([]);
  final recentSearches = listSignal<String>([]);

  // YouTube search state
  final youtubeSearchResults = listSignal<Song>([]);
  final ytBrowseResults = listSignal<Song>([]);
  final ytSearchResults = listSignal<Map<String, dynamic>>([]);
  final ytSearchFilter = signal<SearchFilter?>(SearchFilter.songs);
  final isSearchingYoutube = signal<bool>(false);
  final hasMoreYtResults = signal<bool>(false);
  int _ytSearchLoadedCount = 0;

  // Explore & Moods
  final exploreData = signal<Map<String, dynamic>>({});
  final moodCategories = signal<Map<String, dynamic>>({});
  final isLoadingExplore = signal<bool>(false);

  // Local search state
  final localSearchResults = listSignal<Song>([]);
  final localSearchFilter = signal<LocalSearchFilter>(LocalSearchFilter.songs);
  final localSearchPlaylists = listSignal<Playlist>([]);
  final localSearchAlbums = listSignal<Album>([]);
  final localSearchArtists = listSignal<Artist>([]);
  final localSearchFolders = listSignal<String>([]);

  Timer? _searchDebounce;
  Timer? _localSearchDebounce;
  Timer? _suggestionsDebounce;

  final _effectDisposals = <EffectCleanup>[];

  void _initEffects() {
    // Search suggestions effect
    _effectDisposals.add(
      effect(() {
        final query = searchQuery.value;
        _suggestionsDebounce?.cancel();

        if (query.isEmpty) {
          searchSuggestions.value = [];
          return;
        }

        _suggestionsDebounce = Timer(
          const Duration(milliseconds: 300),
          () async {
            try {
              final suggestions = await youtubeDatasource.getSearchSuggestions(
                query.trim(),
              );
              searchSuggestions.value = suggestions;
            } catch (e) {
              debugPrint('Search suggestions error: $e');
            }
          },
        );
      }),
    );

    // Local search effect
    _effectDisposals.add(
      effect(() {
        final query = searchQuery.value;
        final filter = localSearchFilter.value;
        _localSearchDebounce?.cancel();

        if (query.isEmpty) {
          localSearchResults.value = [];
          localSearchPlaylists.value = [];
          localSearchAlbums.value = [];
          localSearchArtists.value = [];
          localSearchFolders.value = [];
          return;
        }

        _localSearchDebounce = Timer(const Duration(milliseconds: 150), () {
          localSearchResults.value = [];
          localSearchPlaylists.value = [];
          localSearchAlbums.value = [];
          localSearchArtists.value = [];
          localSearchFolders.value = [];

          final allSongs = audioSignal.allSongs.value;

          switch (filter) {
            case LocalSearchFilter.songs:
              localSearchResults.value = LocalSearchService.searchSongs(
                query,
                allSongs,
              );
              break;
            case LocalSearchFilter.playlists:
              localSearchPlaylists.value = LocalSearchService.searchPlaylists(
                query,
                audioSignal.playlists.value,
              );
              break;
            case LocalSearchFilter.albums:
              localSearchAlbums.value = LocalSearchService.searchAlbums(
                query,
                audioSignal.albums.value,
              );
              break;
            case LocalSearchFilter.artists:
              localSearchArtists.value = LocalSearchService.searchArtists(
                query,
                audioSignal.artists.value,
              );
              break;
            case LocalSearchFilter.folders:
              localSearchFolders.value = LocalSearchService.searchFolders(
                query,
                allSongs,
              );
              break;
          }
        });
      }),
    );

    // YouTube search effect
    _effectDisposals.add(
      effect(() {
        final query = searchQuery.value;
        final filter = ytSearchFilter.value;
        _searchDebounce?.cancel();

        if (query.isEmpty) {
          youtubeSearchResults.value = [];
          ytSearchResults.value = [];
          _ytSearchLoadedCount = 0;
          hasMoreYtResults.value = false;
          return;
        }

        _searchDebounce = Timer(const Duration(milliseconds: 700), () async {
          try {
            final trimmedQuery = query.trim();
            if (trimmedQuery.isEmpty) return;

            isSearchingYoutube.value = true;
            debugPrint(
              'SearchSignal: Debounced search for "$trimmedQuery" (filter: $filter) starting...',
            );

            _ytSearchLoadedCount = 0;
            hasMoreYtResults.value = false;

            final rawResults = await youtubeService.search(
              trimmedQuery,
              filter: filter,
              limit: 20,
            );
            _ytSearchLoadedCount = rawResults.length;
            hasMoreYtResults.value = rawResults.length >= 20;
            ytSearchResults.value = rawResults;

            if (filter == SearchFilter.songs || filter == null) {
              youtubeSearchResults.value = rawResults
                  .map((s) => youtubeDatasource.mapToSong(s))
                  .toList();
            } else {
              youtubeSearchResults.value = [];
            }

            debugPrint(
              'SearchSignal: Search results updated (${rawResults.length} items)',
            );
          } catch (e) {
            debugPrint('SearchSignal: YouTube search error: $e');
          } finally {
            isSearchingYoutube.value = false;
          }
        });
      }),
    );
  }

  Future<void> loadMoreYtResults() async {
    if (isSearchingYoutube.value) return;
    final query = searchQuery.value.trim();
    if (query.isEmpty) return;

    final filter = ytSearchFilter.value;
    final offset = _ytSearchLoadedCount;

    isSearchingYoutube.value = true;
    try {
      final rawResults = await youtubeService.search(
        query,
        filter: filter,
        limit: offset + 20,
      );

      if (rawResults.length <= offset) {
        hasMoreYtResults.value = false;
        return;
      }

      final newItems = rawResults.skip(offset).toList();
      final currentYt = List<Map<String, dynamic>>.from(ytSearchResults.value);
      currentYt.addAll(newItems);
      ytSearchResults.value = currentYt;

      final currentSongs = List<Song>.from(youtubeSearchResults.value);
      if (filter == SearchFilter.songs || filter == null) {
        currentSongs.addAll(
          newItems.map((s) => youtubeDatasource.mapToSong(s)),
        );
        youtubeSearchResults.value = currentSongs;
      }

      _ytSearchLoadedCount = currentYt.length;
      hasMoreYtResults.value = newItems.isNotEmpty;
    } catch (e) {
      debugPrint('Error loading more YouTube search results: $e');
    } finally {
      isSearchingYoutube.value = false;
    }
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    recentSearches.value = prefs.getStringList('recentSearches') ?? [];
  }

  Future<void> addRecentSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final current = List<String>.from(recentSearches.value);
    current.remove(q);
    current.insert(0, q);
    if (current.length > 10) {
      current.removeLast();
    }
    recentSearches.value = current;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recentSearches', current);
  }

  Future<void> clearRecentSearches() async {
    recentSearches.value = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recentSearches');
  }

  Future<void> loadExploreData({bool force = false}) async {
    if (!force && (exploreData.value.isNotEmpty || isLoadingExplore.value))
      return;
    if (force && isLoadingExplore.value) return;

    if (!force) {
      // 1. Try cache first
      try {
        final cachedExplore = await youtubeDatasource.getCachedExplore();
        final cachedMoods = await youtubeDatasource.getCachedMoodCategories();

        if (cachedExplore != null && cachedMoods != null) {
          exploreData.value = cachedExplore;
          moodCategories.value = cachedMoods;
        } else {
          isLoadingExplore.value = true;
        }
      } catch (_) {
        isLoadingExplore.value = true;
      }
    } else {
      isLoadingExplore.value = true;
    }

    // 2. Fetch fresh data
    try {
      final results = await Future.wait([
        youtubeDatasource.getExplore(),
        youtubeDatasource.getMoodCategories(),
      ]);
      exploreData.value = results[0];
      moodCategories.value = results[1];
    } catch (e) {
      debugPrint('Error loading explore data: $e');
    } finally {
      isLoadingExplore.value = false;
    }
  }

  void cancelSearches() {
    _searchDebounce?.cancel();
    _searchDebounce = null;
    _localSearchDebounce?.cancel();
    _localSearchDebounce = null;
    _suggestionsDebounce?.cancel();
    _suggestionsDebounce = null;
  }
}

final searchSignal = SearchSignal();
