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
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:ytmusicapi_dart/ytmusicapi_dart.dart';
import 'package:ytmusicapi_dart/enums.dart';
export 'package:ytmusicapi_dart/enums.dart' show SearchFilter;
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../signals/settings_signal.dart';
import 'CurlService.dart';
import 'yt_cache_helper.dart';

class YoutubeDatasource {
  static final YoutubeDatasource _instance = YoutubeDatasource._internal();
  factory YoutubeDatasource() => _instance;
  YoutubeDatasource._internal();

  YTMusic? _ytm;
  bool _initialized = false;
  String? _cookies;
  Completer<void>? _initCompleter;

  /// Cache: videoId → high-res YouTube Music thumbnail URL (square)
  final Map<String, String> _thumbnailCache = {};

  /// Get the cached YouTube Music artwork URL for a video ID.
  /// Falls back to YouTube video thumbnail if not cached.
  String getArtworkUrl(String videoId) {
    return _thumbnailCache[videoId] ??
        'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }

  /// Get the artwork URL for a Song.
  /// Returns the thumbnailUrl stored on the Song if available (from YTM API),
  /// otherwise falls back to the thumbnail cache, then YouTube CDN.
  String getSongArtworkUrl(Song song) {
    if (!song.path.startsWith('yt:')) return '';
    return song.thumbnailUrl ?? getArtworkUrl(song.path.substring(3));
  }

  // --- Cache Getters ---
  Future<List<Map<String, dynamic>>?> getCachedHomeSections() async {
    final cached = await YTCacheHelper.readCache('home_sections');
    if (cached is List) return cached.map((e) => Map<String, dynamic>.from(e)).toList();
    return null;
  }

  Future<Map<String, dynamic>?> getCachedMoodCategories() async {
    final cached = await YTCacheHelper.readCache('mood_categories');
    if (cached is Map) return Map<String, dynamic>.from(cached);
    return null;
  }

  Future<List<Map<String, dynamic>>?> getCachedMoodPlaylists(String params) async {
    final safeParams = params.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final cached = await YTCacheHelper.readCache('mood_playlists_$safeParams');
    if (cached is List) return cached.map((e) => Map<String, dynamic>.from(e)).toList();
    return null;
  }

  Future<List<Map<String, dynamic>>?> getCachedLibraryPlaylists() async {
    final cached = await YTCacheHelper.readCache('library_playlists');
    if (cached is List) return cached.map((e) => Map<String, dynamic>.from(e)).toList();
    return null;
  }

  Future<List<Map<String, dynamic>>?> getCachedLibraryAlbums() async {
    final cached = await YTCacheHelper.readCache('library_albums');
    if (cached is List) return cached.map((e) => Map<String, dynamic>.from(e)).toList();
    return null;
  }

  Future<List<Map<String, dynamic>>?> getCachedLibraryArtists() async {
    final cached = await YTCacheHelper.readCache('library_artists');
    if (cached is List) return cached.map((e) => Map<String, dynamic>.from(e)).toList();
    return null;
  }

  Future<Map<String, dynamic>?> getCachedExplore() async {
    final cached = await YTCacheHelper.readCache('explore');
    if (cached is Map) return Map<String, dynamic>.from(cached);
    return null;
  }
  // ---------------------

  Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;
    
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      await _initCompleter!.future;
    }
    
    _initialized = false;
    _initCompleter = Completer<void>();
    try {
      debugPrint('YouTube Music Datasource: Starting initialization...');
      
      final rawAuthCookie = settingsSignal.ytAuthCookie.value;
      final authCookie = rawAuthCookie?.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
      
      // Create a custom Dio interceptor to force the correct Cookie and Authorization headers
      final customDio = Dio();
      customDio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          final headers = options.headers;
          final realCookie = (authCookie != null && authCookie.isNotEmpty) 
              ? authCookie 
              : headers['cookie']?.toString().replaceAll(RegExp(r'[^\x20-\x7E]'), '');
              
          if (realCookie != null) {
            headers.remove('cookie');
            headers.remove('Cookie');
            headers['Cookie'] = realCookie;
            
            // Calculate and inject proper SAPISIDHASH
            try {
              final cookies = <String, String>{};
              for (final pair in realCookie.replaceAll('"', '').split(';')) {
                final kv = pair.split('=');
                if (kv.length == 2) cookies[kv[0].trim()] = kv[1].trim();
              }
              final sapisid = cookies['SAPISID'] ?? cookies['__Secure-3PAPISID'] ?? cookies['__Secure-1PAPISID'];
              if (sapisid != null) {
                final unixTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
                final bytes = utf8.encode('$unixTimestamp $sapisid https://music.youtube.com');
                final hash = sha1.convert(bytes).toString();
                headers['authorization'] = 'SAPISIDHASH ${unixTimestamp}_$hash';
              }
            } catch (_) {}
          }
          return handler.next(options);
        }
      ));

      if (authCookie != null && authCookie.isNotEmpty) {
        final authContent = jsonEncode({
          'cookie': authCookie,
          'authorization': 'SAPISIDHASH dummy_value',
          'origin': 'https://music.youtube.com'
        });
        _ytm = await YTMusic.create(auth: authContent, requestsSession: customDio);
        debugPrint('YouTube Music Datasource initialized with user provided cookie.');
      } else {
        _ytm = await YTMusic.create(requestsSession: customDio);
        
        try {
          final response = await CurlService.get(
            'https://music.youtube.com/',
            userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          );
          _cookies = response.headers['set-cookie'];
          if (_cookies != null) {
             final authContent = jsonEncode({
               'cookie': _cookies,
               'authorization': 'SAPISIDHASH dummy_value',
               'origin': 'https://music.youtube.com'
             });
             _ytm = await YTMusic.create(auth: authContent, requestsSession: customDio);
             debugPrint('YouTube Music Datasource established session with cookies.');
          }
        } catch (e) {
          debugPrint('YouTube Music session establishment failed (not critical): $e');
        }
      }

      _initialized = true;
      debugPrint('YouTube Music Datasource initialized successfully.');
      _initCompleter!.complete();
    } catch (e) {
      debugPrint('YouTube Music Datasource CRITICAL initialization error: $e');
      _initialized = true;
      _initCompleter!.complete();
    }
  }

  String transformThumbnail(String? url) {
    if (url == null || url.isEmpty) return '';
    
    // For standard YouTube video thumbnails, the sqp/rs tokens often expire or cause connection resets.
    // Strip query parameters to get the reliable base image.
    if (url.contains('i.ytimg.com')) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
         // Return just the origin + path (e.g., https://i.ytimg.com/vi/.../sddefault.jpg)
         url = '${uri.scheme}://${uri.host}${uri.path}';
      }
    }

    // Replace size parameters for Google-hosted images (lh3.googleusercontent, etc)
    return url
        .replaceAll(RegExp(r'w\d+-h\d+'), 'w600-h600')
        .replaceAll('=s60', '=s600')
        .replaceAll('=s120', '=s600')
        .replaceAll('=s68', '=s600');
  }

  Song mapToSong(dynamic item) {
    try {
      // ytmusicapi_dart returns maps
      final Map<String, dynamic> dItem = item is Map ? Map<String, dynamic>.from(item) : {};

      final String videoId = dItem['videoId'] ?? '';
      final String title = dItem['title'] ?? dItem['name'] ?? 'Unknown Title';

      final List<dynamic> artists = dItem['artists'] ?? [];
      final String artistName = artists.isNotEmpty
          ? artists.map((a) => (a as Map)['name'] ?? 'Unknown').join(', ')
          : 'Unknown Artist';

      final dynamic album = dItem['album'];
      String? albumName;
      if (album != null) {
        if (album is Map) {
          albumName = album['name'];
        } else if (album is String) {
          albumName = album;
        }
      }

      final int? durationMs = dItem['durationMs'];

      // Cache the YouTube Music thumbnail (square, high-res) and extract for the Song.
      // Check 'thumbnails' first (YTM thumbnail list), then 'thumbnail' (raw YouTube thumbnail from watch playlist).
      String? cachedThumbnailUrl;
      if (videoId.isNotEmpty) {
        // YTM thumbnail list (preferred) — used by search, albums, playlists, etc.
        final thumbnails = dItem['thumbnails'];
        if (thumbnails is List && thumbnails.isNotEmpty) {
          final rawUrl = thumbnails.last['url']?.toString() ?? '';
          if (rawUrl.isNotEmpty) {
            cachedThumbnailUrl = transformThumbnail(rawUrl);
            _thumbnailCache[videoId] = cachedThumbnailUrl;
          }
        }
        // Raw YouTube thumbnail — used by watch playlist (radio)
        if (cachedThumbnailUrl == null) {
          final rawThumb = dItem['thumbnail'];
          if (rawThumb is List && rawThumb.isNotEmpty) {
            final rawUrl = rawThumb.last['url']?.toString() ?? '';
            if (rawUrl.isNotEmpty) {
              cachedThumbnailUrl = transformThumbnail(rawUrl);
              _thumbnailCache[videoId] = cachedThumbnailUrl;
            }
          }
        }
      }

      return Song(
        path: 'yt:$videoId',
        title: title,
        artist: artistName,
        album: albumName,
        duration: durationMs != null && durationMs > 0 ? Duration(milliseconds: durationMs) : null,
        hasAlbumArt: true,
        thumbnailUrl: cachedThumbnailUrl,
      );
    } catch (e) {
      // Fallback for malformed track data (e.g. watch playlist items with non-standard structure)
      final Map<String, dynamic> dItem = item is Map ? Map<String, dynamic>.from(item) : {};
      final videoId = dItem['videoId']?.toString() ?? '';
      final title = dItem['title']?.toString() ?? dItem['name']?.toString() ?? 'Unknown Title';
      debugPrint('mapToSong fallback for videoId=$videoId: $e');
      return Song(
        path: 'yt:$videoId',
        title: title,
        hasAlbumArt: true,
      );
    }
  }

  /// Get search suggestions for a query string.
  Future<List<String>> getSearchSuggestions(String query) async {
    await init();
    if (_ytm == null) return [];
    try {
      final results = await _ytm!.getSearchSuggestions(query);
      if (results is List) {
        return results.map((e) => e.toString()).toList();
      }
      return [];
    } catch (e) {
      debugPrint('YTM getSearchSuggestions error: $e');
      return [];
    }
  }

  /// Generic search with optional filter. Returns raw maps.
  /// Set [limit] to request more results (uses continuation to fill up to limit).
  Future<List<Map<String, dynamic>>> search(String query, {SearchFilter? filter, int limit = 20}) async {
    await init();
    if (_ytm == null) {
      debugPrint('YTM search error: YTMusic is not initialized.');
      return [];
    }
    try {
      final results = await _ytm!.search(query, filter: filter, limit: limit);
      return results.map((r) => r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{}).toList();
    } catch (e) {
      debugPrint('YTM search error ($filter): $e');
      return [];
    }
  }

  /// Convenience: search songs only and return Song models.
  Future<List<Song>> searchSongs(String query) async {
    final results = await search(query, filter: SearchFilter.songs);
    return results.map((s) => mapToSong(s)).toList();
  }

  /// Cache thumbnails from a raw YTM item map (song, album, artist, playlist).
  /// Call this on every item to ensure the thumbnail cache is populated.
  void cacheThumbnailsFromItem(Map<String, dynamic> item) {
    final videoId = item['videoId'];
    if (videoId != null && videoId is String && videoId.isNotEmpty) {
      final thumbnails = item['thumbnails'];
      if (thumbnails is List && thumbnails.isNotEmpty) {
        final rawUrl = thumbnails.last['url']?.toString() ?? '';
        if (rawUrl.isNotEmpty) {
          _thumbnailCache[videoId] = transformThumbnail(rawUrl);
        }
      }
    }
  }

  Future<List<Map<String, dynamic>>> getHomeSections() async {
    await init();
    if (_ytm == null) {
      debugPrint('YTM getHome error: YTMusic is not initialized.');
      return [];
    }
    try {
      final results = await _ytm!.getHome();
      final mapped = results.map((section) {
        final contents = section['contents'] as List? ?? [];
        // Pre-cache thumbnails for all items with videoIds
        for (final item in contents) {
          if (item is Map) {
            cacheThumbnailsFromItem(Map<String, dynamic>.from(item));
          }
        }
        return <String, dynamic>{
          'title': section['title'],
          'items': contents,
        };
      }).toList();
      YTCacheHelper.writeCache('home_sections', mapped);
      return mapped;
    } catch (e) {
      debugPrint('YTM getHome error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getMoodCategories() async {
    await init();
    try {
      final response = await _sendRequest('browse', {'browseId': 'FEmusic_moods_and_genres'});
      
      final sections = <String, dynamic>{};
      final results = response['contents']?['singleColumnBrowseResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'];
      
      if (results is List) {
        for (final section in results) {
          final grid = section['gridRenderer'];
          if (grid == null) continue;
          
          final title = grid['header']?['gridHeaderRenderer']?['title']?['runs']?[0]?['text'];
          if (title == null) continue;
          
          final items = grid['items'];
          if (items is! List) continue;
          
          final categoryList = <Map<String, dynamic>>[];
          for (final item in items) {
            final cat = item['musicNavigationButtonRenderer'];
            if (cat == null) continue;
            categoryList.add({
              'title': cat['buttonText']?['runs']?[0]?['text'] ?? '',
              'params': cat['clickCommand']?['browseEndpoint']?['params'] ?? '',
            });
          }
          sections[title] = categoryList;
        }
      }
      YTCacheHelper.writeCache('mood_categories', sections);
      return sections;
    } catch (e) {
      debugPrint('YTM getMoodCategories error: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getMoodPlaylists(String params) async {
    await init();
    try {
      final res = await _sendRequest('browse', {
        'browseId': 'FEmusic_moods_and_genres_category',
        'params': params,
      });

      final contents = res['contents']?['singleColumnBrowseResultsRenderer']
          ?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']
          ?['contents'];

      final List<Map<String, dynamic>> sections = [];

      if (contents is List) {
        for (final section in contents) {
          if (section.containsKey('gridRenderer')) {
            final title = section['gridRenderer']['header']
                ?['gridHeaderRenderer']?['title']?['runs']?[0]?['text'];
            final items = section['gridRenderer']['items'] as List?;
            if (title != null && items != null && items.isNotEmpty) {
              final parsedItems = _parseTwoRowItems(items);
              if (parsedItems.isNotEmpty) {
                sections.add({
                  'title': title,
                  'items': parsedItems,
                });
              }
            }
          } else if (section.containsKey('musicCarouselShelfRenderer')) {
            final title = section['musicCarouselShelfRenderer']['header']
                    ?['musicCarouselShelfBasicHeaderRenderer']?['title']
                ?['runs']?[0]?['text'];
            final items =
                section['musicCarouselShelfRenderer']['contents'] as List?;
            if (title != null && items != null && items.isNotEmpty) {
              final parsedItems = _parseTwoRowItems(items);
              if (parsedItems.isNotEmpty) {
                sections.add({
                  'title': title,
                  'items': parsedItems,
                });
              }
            }
          }
        }
      }
      final safeParams = params.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      YTCacheHelper.writeCache('mood_playlists_$safeParams', sections);
      return sections;
    } catch (e) {
      debugPrint('YTM getMoodPlaylists error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _sendRequest(String endpoint, Map<String, dynamic> body) async {
    final rawUserCookie = settingsSignal.ytAuthCookie.value;
    final userCookie = rawUserCookie?.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    
    final headers = {
      'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'accept': '*/*',
      'content-type': 'application/json',
      'origin': 'https://music.youtube.com',
    };
    
    if (userCookie != null && userCookie.isNotEmpty) {
      headers['cookie'] = userCookie;
      try {
        final cookies = <String, String>{};
        for (final pair in userCookie.replaceAll('"', '').split(';')) {
          final kv = pair.split('=');
          if (kv.length == 2) cookies[kv[0].trim()] = kv[1].trim();
        }
        final sapisid = cookies['SAPISID'] ?? cookies['__Secure-3PAPISID'] ?? cookies['__Secure-1PAPISID'];
        if (sapisid != null) {
          final unixTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
          final bytes = utf8.encode('$unixTimestamp $sapisid https://music.youtube.com');
          final hash = sha1.convert(bytes).toString();
          headers['authorization'] = 'SAPISIDHASH ${unixTimestamp}_$hash';
        }
      } catch (_) {}
    }
    
    body['context'] = {
      'client': {
        'clientName': 'WEB_REMIX',
        'clientVersion': '1.20240101.01.00',
        'gl': 'US',
        'hl': 'en',
      },
      'user': {},
    };

    try {
      final response = await http.post(
        Uri.parse('https://music.youtube.com/youtubei/v1/$endpoint?alt=json'),
        headers: headers,
        body: jsonEncode(body),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('YTM HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('YTM Request Exception: $e');
    }
    return {};
  }

  Future<List<Map<String, dynamic>>> getLibraryPlaylists() async {
    await init();
    try {
      final res = await _sendRequest('browse', {'browseId': 'FEmusic_liked_playlists'});

      final contents = res['contents']?['singleColumnBrowseResultsRenderer']
          ?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']
          ?['contents'];

      if (contents is List && contents.isNotEmpty) {
        final gridItems = contents.first['gridRenderer']?['items'] ??
            contents.first['musicPlaylistShelfRenderer']?['contents'];
        if (gridItems is List) {
          final parsed = _parseTwoRowItems(gridItems);
          YTCacheHelper.writeCache('library_playlists', parsed);
          return parsed;
        }
      }
      return [];
    } catch (e) {
      debugPrint('YTM getLibraryPlaylists error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getLibraryAlbums() async {
    await init();
    try {
      final res = await _sendRequest('browse', {'browseId': 'FEmusic_liked_albums'});

      final contents = res['contents']?['singleColumnBrowseResultsRenderer']
          ?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']
          ?['contents'];

      if (contents is List && contents.isNotEmpty) {
        final gridItems = contents.first['gridRenderer']?['items'];
        if (gridItems is List) {
          final parsed = _parseTwoRowItems(gridItems);
          YTCacheHelper.writeCache('library_albums', parsed);
          return parsed;
        }
      }
      return [];
    } catch (e) {
      debugPrint('YTM getLibraryAlbums error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getLibraryArtists() async {
    await init();
    try {
      final res = await _sendRequest('browse', {'browseId': 'FEmusic_library_corpus_track_artists'});

      final contents = res['contents']?['singleColumnBrowseResultsRenderer']
          ?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']
          ?['contents'];

      if (contents is List && contents.isNotEmpty) {
        final gridItems = contents.first['musicImmersiveCarouselShelfRenderer']?['contents'] ?? 
            contents.first['gridRenderer']?['items'];
        if (gridItems is List) {
          final parsed = _parseTwoRowItems(gridItems);
          YTCacheHelper.writeCache('library_artists', parsed);
          return parsed;
        }
      }
      return [];
    } catch (e) {
      debugPrint('YTM getLibraryArtists error: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _parseTwoRowItems(List<dynamic> items) {
    final List<Map<String, dynamic>> parsed = [];
    for (final item in items) {
      final renderer = item['musicTwoRowItemRenderer'];
      if (renderer == null) continue;

      final title = renderer['title']?['runs']?[0]?['text'] ?? 'Unknown';
      
      String browseId = renderer['navigationEndpoint']?['browseEndpoint']?['browseId'] ?? '';
      if (browseId.startsWith('VL')) browseId = browseId.substring(2);

      String thumbnailUrl = '';
      final thumbnails = renderer['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'];
      if (thumbnails is List && thumbnails.isNotEmpty) {
        thumbnailUrl = thumbnails.last['url'] ?? '';
        if (thumbnailUrl.startsWith('//')) {
          thumbnailUrl = 'https:$thumbnailUrl';
        }
      }

      String subtitle = '';
      final subtitles = renderer['subtitle']?['runs'];
      if (subtitles is List) {
        subtitle = subtitles.map((r) => r['text'] ?? '').join();
      }

      if (browseId.isNotEmpty) {
        parsed.add({
          'title': title,
          'browseId': browseId,
          'thumbnailUrl': thumbnailUrl,
          'description': subtitle,
        });
      }
    }
    return parsed;
  }

  Future<Map<String, dynamic>> getExplore() async {
    await init();
    try {
      final response = await _sendRequest('browse', {'browseId': 'FEmusic_explore'});
      
      final explore = <String, dynamic>{};
      final results = response['contents']?['singleColumnBrowseResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'];
      
      if (results is List) {
        for (final result in results) {
          final carousel = result['musicCarouselShelfRenderer'];
          if (carousel == null) continue;
          
          final browseId = carousel['header']?['musicCarouselShelfBasicHeaderRenderer']?['title']?['runs']?[0]?['navigationEndpoint']?['browseEndpoint']?['browseId'];
          if (browseId == null) continue;

          final contents = carousel['contents'];
          if (contents is! List) continue;

          if (browseId == 'FEmusic_new_releases_albums') {
            explore['new_releases'] = _parseTwoRowItems(contents);
          } else if (browseId == 'FEmusic_moods_and_genres') {
            final categoryList = <Map<String, dynamic>>[];
            for (final genre in contents) {
               final cat = genre['musicNavigationButtonRenderer'];
               if (cat == null) continue;
               categoryList.add({
                 'title': cat['buttonText']?['runs']?[0]?['text'] ?? '',
                 'params': cat['clickCommand']?['browseEndpoint']?['params'] ?? '',
               });
            }
            explore['moods_and_genres'] = categoryList;
          } else if (browseId == 'FEmusic_new_releases_videos') {
            explore['new_videos'] = _parseTwoRowItems(contents);
          } else if (browseId.startsWith('VLPL')) {
            explore['top_songs'] = {
              'playlist': browseId,
              'items': _parseTwoRowItems(contents),
            };
          } else if (browseId.startsWith('VLOLA')) {
            explore['trending'] = {
              'playlist': browseId,
              'items': _parseTwoRowItems(contents),
            };
          }
        }
      }
      YTCacheHelper.writeCache('explore', explore);
      return explore;
    } catch (e) {
      debugPrint('YTM getExplore error: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getCharts({String country = 'ZZ'}) async {
    await init();
    if (_ytm == null) return {};
    try {
      return await _ytm!.getCharts(country: country);
    } catch (e) {
      debugPrint('YTM getCharts error: $e');
      return {};
    }
  }

  /// Get full album detail: metadata + tracks as Song list.
  /// Returns a map with keys: title, artists, thumbnailUrl, year, tracks (List<Song>), trackCount.
  Future<Map<String, dynamic>> getAlbumDetail(String browseId) async {
    await init();
    if (_ytm == null) return {};
    try {
      final album = await _ytm!.getAlbum(browseId);
      final tracks = (album['tracks'] as List? ?? []);
      
      // Get album thumbnail
      String thumbnailUrl = '';
      final thumbs = album['thumbnails'];
      if (thumbs is List && thumbs.isNotEmpty) {
        thumbnailUrl = transformThumbnail(thumbs.last['url']?.toString() ?? '');
      }

      // Map tracks to Song and cache thumbnails
      final songs = tracks.map((t) {
        final track = t is Map ? Map<String, dynamic>.from(t) : <String, dynamic>{};
        // Add album thumbnails to tracks that lack their own
        if ((track['thumbnails'] == null || (track['thumbnails'] is List && (track['thumbnails'] as List).isEmpty)) && thumbs is List) {
          track['thumbnails'] = thumbs;
        }
        return mapToSong(track);
      }).toList();

      // Extract artist names
      final artists = album['artists'];
      String artistName = '';
      if (artists is List && artists.isNotEmpty) {
        artistName = artists.map((a) => a is Map ? (a['name'] ?? '') : '').join(', ');
      }

      return {
        'title': album['title'] ?? 'Unknown Album',
        'artistName': artistName,
        'thumbnailUrl': thumbnailUrl,
        'year': album['year']?.toString() ?? '',
        'tracks': songs,
        'trackCount': album['trackCount'] ?? songs.length,
        'description': album['description'] ?? '',
      };
    } catch (e) {
      debugPrint('YTM getAlbumDetail error: $e');
      return {};
    }
  }

  /// Get full artist detail: metadata + top songs + albums.
  Future<Map<String, dynamic>> getArtistDetail(String channelId) async {
    await init();
    if (_ytm == null) return {};
    try {
      final artist = await _ytm!.getArtist(channelId);

      // Get artist thumbnail
      String thumbnailUrl = '';
      final thumbs = artist['thumbnails'];
      if (thumbs is List && thumbs.isNotEmpty) {
        thumbnailUrl = transformThumbnail(thumbs.last['url']?.toString() ?? '');
      }

      // Map top songs
      final songsSection = artist['songs'];
      List<Song> topSongs = [];
      if (songsSection is Map && songsSection['results'] is List) {
        topSongs = (songsSection['results'] as List).map((t) {
          final track = t is Map ? Map<String, dynamic>.from(t) : <String, dynamic>{};
          return mapToSong(track);
        }).toList();
      }

      // Get albums list (raw maps with browseId, title, thumbnails, year)
      final albumsSection = artist['albums'];
      List<Map<String, dynamic>> albums = [];
      if (albumsSection is Map && albumsSection['results'] is List) {
        albums = (albumsSection['results'] as List).map((a) {
          final m = a is Map ? Map<String, dynamic>.from(a) : <String, dynamic>{};
          return m;
        }).toList();
      }

      // Singles
      final singlesSection = artist['singles'];
      List<Map<String, dynamic>> singles = [];
      if (singlesSection is Map && singlesSection['results'] is List) {
        singles = (singlesSection['results'] as List).map((a) {
          final m = a is Map ? Map<String, dynamic>.from(a) : <String, dynamic>{};
          return m;
        }).toList();
      }

      return {
        'name': artist['name'] ?? 'Unknown Artist',
        'thumbnailUrl': thumbnailUrl,
        'description': artist['description'] ?? '',
        'subscribers': artist['subscribers'] ?? '',
        'topSongs': topSongs,
        'albums': albums,
        'singles': singles,
        'channelId': artist['channelId'] ?? channelId,
      };
    } catch (e) {
      debugPrint('YTM getArtistDetail error: $e');
      return {};
    }
  }

  /// Get full playlist detail: metadata + tracks as Song list.
  Future<Map<String, dynamic>> getPlaylistDetail(String playlistId) async {
    await init();
    if (_ytm == null) return {};
    try {
      final playlist = await _ytm!.getPlaylist(playlistId);

      String thumbnailUrl = '';
      final thumbs = playlist['thumbnails'];
      if (thumbs is List && thumbs.isNotEmpty) {
        thumbnailUrl = transformThumbnail(thumbs.last['url']?.toString() ?? '');
      }

      final tracks = (playlist['tracks'] as List? ?? []);
      final songs = tracks.map((t) {
        final track = t is Map ? Map<String, dynamic>.from(t) : <String, dynamic>{};
        return mapToSong(track);
      }).toList();

      return {
        'title': playlist['title'] ?? 'Unknown Playlist',
        'thumbnailUrl': thumbnailUrl,
        'description': playlist['description'] ?? '',
        'tracks': songs,
        'trackCount': playlist['trackCount'] ?? songs.length,
        'author': playlist['author'] is Map ? (playlist['author'] as Map)['name'] ?? '' : '',
      };
    } catch (e) {
      debugPrint('YTM getPlaylistDetail error: $e');
      return {};
    }
  }

  /// Get a radio/auto-play playlist of songs similar to the given video.
  /// Uses YouTube Music's native radio endpoint (getWatchPlaylist with radio=true).
  /// The first track is skipped since it is the seed/current song.
  /// Fetches multiple pages via continuation until [limit] tracks are collected.
  Future<List<Song>> getRadioSongs(String videoId, {int limit = 25}) async {
    await init();
    if (_ytm == null) return [];
    try {
      final result = await _ytm!.getWatchPlaylist(
        videoId: videoId,
        limit: limit,
        radio: true,
      );
      final tracks = result['tracks'] as List? ?? [];
      return tracks.skip(1).map((t) => mapToSong(t)).toList();
    } catch (e) {
      debugPrint('YTM getRadioSongs error: $e');
      return [];
    }
  }
}

final youtubeDatasource = YoutubeDatasource();

