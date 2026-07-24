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
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:ytmusicapi_dart/ytmusicapi_dart.dart';
import 'package:ytmusicapi_dart/enums.dart';
export 'package:ytmusicapi_dart/enums.dart' show SearchFilter;
import 'package:ytmusicapi_dart/navigation.dart';
import 'package:ytmusicapi_dart/parsers/browsing.dart';
import 'package:ytmusicapi_dart/parsers/songs.dart';
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
  String? _cacheDir;

  /// In-memory cache of radio song lists keyed by videoId.
  final Map<String, List<Song>> _radioCache = {};
  bool _initialized = false;
  bool _initializing = false;
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
    final cached = await YTCacheHelper.readStampedCache('home_sections', maxAge: const Duration(minutes: 30));
    if (cached == null) return null;
    final data = cached.data;
    if (data is! List) return null;
    final sections = <Map<String, dynamic>>[];
    for (final rawSection in data) {
      final section = Map<String, dynamic>.from(rawSection);
      final items = section['items'] as List? ?? [];
      section['items'] = items.map((item) {
        if (item is Map) {
          return _normalizeYtmItem(item);
        }
        return <String, dynamic>{};
      }).toList();
      sections.add(section);
    }
    return sections;
  }

  Future<Map<String, dynamic>?> getCachedMoodCategories() async {
    final cached = await YTCacheHelper.readStampedCache('mood_categories', maxAge: const Duration(minutes: 30));
    if (cached == null) return null;
    if (cached.data is Map) return Map<String, dynamic>.from(cached.data);
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
    final cached = await YTCacheHelper.readStampedCache('explore', maxAge: const Duration(minutes: 30));
    if (cached == null) return null;
    if (cached.data is Map) return Map<String, dynamic>.from(cached.data);
    return null;
  }
  // ---------------------

  Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;
    if (_initializing) {
      await _initCompleter?.future;
      return;
    }
    
    _initialized = false;
    _initCompleter = Completer<void>();
    _initializing = true;

    // Set up the cache directory for radio persistence.
    try {
      final dir = await getApplicationDocumentsDirectory();
      _cacheDir = '${dir.path}/ecilaes_cache';
      await _loadRadioCache();
    } catch (_) {}

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
        // Pass authType = browser by including SAPISIDHASH; the interceptor will
        // overwrite the Authorization header with the properly computed value on each
        // request so the library's initial sapisidFromCookie(authorization) doesn't matter.
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
             // Same: authType = browser; interceptor computes correct SAPISIDHASH per request.
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
      _initializing = false;
      debugPrint('YouTube Music Datasource initialized successfully.');
      _initCompleter!.complete();
    } catch (e) {
      debugPrint('YouTube Music Datasource CRITICAL initialization error: $e');
      _initialized = true;
      _initializing = false;
      _initCompleter!.complete();
    }
  }

  String transformThumbnail(String? url) {
    if (url == null || url.isEmpty) return '';

    // Fix protocol-relative URLs (e.g. //lh3.googleusercontent.com/...).
    if (url.startsWith('//')) {
      url = 'https:$url';
    }

    // For i.ytimg.com (YouTube CDN), strip only the token parameters that
    // cause connection resets. Keep the rest of the query string intact so
    // URLs with encoded sizing tokens still resolve correctly.
    if (url.contains('i.ytimg.com')) {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.hasQuery) {
        final params = uri.queryParameters;
        final safe = params.entries
            .where((e) => e.key != 'sqp' && e.key != 'rs')
            .toList();
        if (safe.isNotEmpty) {
          final qs = safe.map((e) => '${e.key}=${e.value}').join('&');
          url = '${uri.scheme}://${uri.host}${uri.path}?$qs';
        } else {
          url = '${uri.scheme}://${uri.host}${uri.path}';
        }
      }
    }

    // Upgrade Google-hosted image size parameters to high-res.
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

  /// Fetch metadata for a single YouTube/YTMusic videoId.
  ///
  /// Best-effort: uses YTM search filtered by videoId. When the lookup fails
  /// (offline, videoId not indexed, etc.) returns a Song with the raw
  /// `yt:<id>` path so callers can still attempt playback.
  Future<Song> getSongByVideoId(String videoId) async {
    if (videoId.isEmpty) {
      return Song.fromPath('yt:$videoId');
    }
    try {
      final results = await _sendRequest('search', {
        'query': videoId,
        'params': 'EgWKAQIIAWoMEA4QChADEAQQCRAF',
      });
      final sections = nav(results, [
        ...SINGLE_COLUMN_TAB,
        ...SECTION_LIST,
      ]).toList();
      for (final section in sections) {
        final contents = (section as Map)['contents'] ?? section['items'];
        if (contents is! List) continue;
        for (final raw in contents) {
          if (raw is! Map) continue;
          final item = _normalizeYtmItem(Map<String, dynamic>.from(raw));
          if (item['videoId'] == videoId) {
            return mapToSong(item);
          }
        }
      }
    } catch (e) {
      debugPrint('YTM getSongByVideoId error: $e');
    }
    return Song.fromPath('yt:$videoId');
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
    try {
      final response = await _sendRequest('browse', {'browseId': 'FEmusic_home'});
      final results = nav(response, [...SINGLE_COLUMN_TAB, ...SECTION_LIST]);
      final home = parseMixedContent(List<Map<String, dynamic>>.from(results as List));

      final mapped = home.map((section) {
        final contents = section['contents'] as List? ?? [];
        final normalizedContents = contents.map((item) {
          if (item is Map) {
            return _normalizeYtmItem(item);
          }
          return <String, dynamic>{};
        }).toList();
        return <String, dynamic>{
          'title': section['title'],
          'items': normalizedContents,
        };
      }).toList();
      YTCacheHelper.writeStampedCache('home_sections', mapped);
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
      YTCacheHelper.writeStampedCache('mood_categories', sections);
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
      'user': {
        'enableUsemsg': true,
        'usemsg': true,
      },
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

  /// Normalize a raw YTM API item (e.g. from getHome) into a flat map with
  /// videoId, title, artists, album, thumbnail(s), and playlistId at the top
  /// level — the same shape that mapToSong expects.
  Map<String, dynamic> _normalizeYtmItem(dynamic item) {
    if (item is! Map) return {};
    final Map<String, dynamic> dItem = Map<String, dynamic>.from(item);

    // Already flat (e.g. search results, album tracks)
    if (dItem.containsKey('videoId') && dItem['videoId'] is String) {
      return dItem;
    }

    // musicTwoRowItemRenderer — appears in carousels on home (e.g. "Listen again")
    final twoRow = dItem['musicTwoRowItemRenderer'];
    if (twoRow != null && twoRow is Map) {
      final normalized = <String, dynamic>{};
      final title = twoRow['title']?['runs']?[0]?['text'] ?? '';
      if (title.isNotEmpty) normalized['title'] = title;

      String browseId = twoRow['navigationEndpoint']?['browseEndpoint']?['browseId'] ?? '';
      if (browseId.startsWith('VL')) browseId = browseId.substring(2);
      if (browseId.isNotEmpty) normalized['browseId'] = browseId;

      // videoId from watchEndpoint or playlistId
      final watchVid = twoRow['navigationEndpoint']?['watchEndpoint']?['videoId'];
      if (watchVid != null && watchVid is String && watchVid.isNotEmpty) {
        normalized['videoId'] = watchVid;
      }

      // Subtitle -> artists + album
      final subtitleRuns = twoRow['subtitle']?['runs'];
      if (subtitleRuns is List && subtitleRuns.isNotEmpty) {
        final subtitleText = subtitleRuns.map((r) => r['text'] ?? '').join('');
        _parseSubtitleIntoArtistsAndAlbum(subtitleText, normalized);
      }

      // Thumbnail
      final thumbs = twoRow['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'];
      if (thumbs is List && thumbs.isNotEmpty) {
        normalized['thumbnails'] = thumbs;
      }

      return normalized;
    }

    // musicResponsiveListItemRenderer — used on home song sections
    final renderer = dItem['musicResponsiveListItemRenderer'];
    if (renderer != null && renderer is Map) {
      final normalized = <String, dynamic>{};

      // Thumbnail
      final thumbData = renderer['thumbnail'];
      if (thumbData is Map) {
        final thumbs = thumbData['musicThumbnailRenderer']?['thumbnail']?['thumbnails'];
        if (thumbs is List && thumbs.isNotEmpty) {
          normalized['thumbnails'] = thumbs;
        }
      }

      // Title — first flex column
      final flex0 = renderer['flexColumns']?[0]?['musicFlexibleMatrixColumnRenderer'];
      if (flex0 is Map) {
        final text = flex0['text']?['runs'];
        if (text is List && text.isNotEmpty) {
          normalized['title'] = text[0]['text'] ?? '';
        }
      }

      // Subtitle — second flex column (typically "Artist · Album" or just "Artist")
      String subtitleText = '';
      final flex1 = renderer['flexColumns']?[1]?['musicFlexibleMatrixColumnRenderer'];
      if (flex1 is Map) {
        final text = flex1['text']?['runs'];
        if (text is List && text.isNotEmpty) {
          subtitleText = text.map((r) => r['text'] ?? '').join('');
        }
      }
      if (subtitleText.isNotEmpty) {
        _parseSubtitleIntoArtistsAndAlbum(subtitleText, normalized);
      }

      // videoId — watch endpoint on the overlay (playlistId for radio)
      final overlay = renderer['overlay'];
      if (overlay is Map) {
        final playBtn = overlay['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer'];
        if (playBtn is Map) {
          final watch = playBtn['playNavigationEndpoint']?['watchPlaylistEndpoint'];
          if (watch is Map) {
            final playlistId = watch['playlistId']?.toString() ?? '';
            final videoId = watch['videoId']?.toString() ?? '';
            // Prefer videoId if available, otherwise the playlistId (radio queue)
            normalized['videoId'] = videoId.isNotEmpty ? videoId : playlistId;
          }
        }
      }

      // Fallback: check browse/watch endpoint in nav endpoint
      if ((normalized['videoId']?.toString() ?? '').isEmpty) {
        final nav = renderer['navigationEndpoint'];
        if (nav is Map) {
          normalized['browseId'] = nav['browseEndpoint']?['browseId'] ?? '';
          normalized['videoId'] = nav['watchEndpoint']?['videoId']?.toString() ?? '';
        }
      }

      // playlistId at top level
      normalized['playlistId'] = dItem['playlistId'] ?? '';

      return normalized;
    }

    return dItem;
  }

  /// Parse a subtitle string like "Artist · Album" or "Artist" into
  /// the 'artists' list (of maps with 'name') and 'album' string that
  /// mapToSong expects.
  void _parseSubtitleIntoArtistsAndAlbum(
      String subtitle, Map<String, dynamic> out) {
    final parts = subtitle.split('·');
    if (parts.length >= 2) {
      final artistPart = parts[0].trim();
      final albumPart = parts.sublist(1).join('·').trim();
      if (artistPart.isNotEmpty) {
        out['artists'] = [{'name': artistPart}];
      }
      if (albumPart.isNotEmpty) {
        out['album'] = albumPart;
      }
    } else if (parts.length == 1 && parts[0].trim().isNotEmpty) {
      out['artists'] = [{'name': parts[0].trim()}];
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
        thumbnailUrl = transformThumbnail(thumbnails.last['url'] ?? '');
      }

      String subtitle = '';
      final subtitles = renderer['subtitle']?['runs'];
      if (subtitles is List) {
        subtitle = subtitles.map((r) => r['text'] ?? '').join();
      }

      // Build thumbnails list to match what mapToSong expects (checks 'thumbnails')
      List<Map<String, dynamic>>? parsedThumbs;
      if (thumbnailUrl.isNotEmpty) {
        parsedThumbs = [{'url': thumbnailUrl}];
      }

      if (browseId.isNotEmpty) {
        parsed.add({
          'title': title,
          'browseId': browseId,
          'thumbnailUrl': thumbnailUrl,
          'thumbnails': parsedThumbs,
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
      YTCacheHelper.writeStampedCache('explore', explore);
      return explore;
    } catch (e) {
      debugPrint('YTM getExplore error: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getCharts({String country = 'ZZ'}) async {
    await init();
    try {
      final response = await _sendRequest('browse', {
        'browseId': 'FEmusic_charts',
        if (country.isNotEmpty)
          'formData': {'selectedValues': [country]},
      });

      final charts = <String, dynamic>{'countries': {}};
      final results = _navList(response, [
        'contents',
        'singleColumnBrowseResultsRenderer',
        'tabs',
        0,
        'tabRenderer',
        'content',
        'sectionListRenderer',
        'contents',
      ]);

      if (results.isNotEmpty) {
        final menu = _navMap(results[0], [
          'musicShelfRenderer',
          'subheaders',
          0,
          'musicSideAlignedItemRenderer',
          'startItems',
          0,
          'musicSortFilterButtonRenderer',
        ]);
        (charts['countries'] as Map)['selected'] = _navTitle(menu);

        (charts['countries'] as Map)['options'] = [
          for (final m in _navList(response, ['frameworkMutations']))
            _navOrNull(m, [
              'payload',
              'musicFormBooleanChoice',
              'opaqueToken',
            ]),
        ].where((e) => e != null).toList();
      }

      // Country determines which categories appear: 'artists' always,
      // 'videos' for non-US (or 'daily'/'weekly' if premium), and 'genres'
      // only for US. The carousel loop below probes each section against
      // both renderers and assigns the matching category.

      // For each non-menu section after results[0], parse it as either an
      // artist (MRLIR) or a playlist/video (MTRIR). Try both renderers —
      // whichever yields results wins. Avoids hard-coding the section order
      // (which differs for premium vs non-premium accounts).
      final categoryPriority = <String>['artists', 'videos', 'daily', 'weekly', 'genres'];
      final foundKeys = <String>{};
      for (var i = 1; i < results.length; i++) {
        final carouselContents = _navList(
          results[i],
          ['musicCarouselShelfRenderer', 'contents'],
        );
        if (carouselContents.isEmpty) continue;

        String? matchedKey;
        List<Map<String, dynamic>> matchedItems = const [];
        for (final key in categoryPriority) {
          if (foundKeys.contains(key)) continue;
          if (key == 'genres' && country != 'US') continue;
          final renderer = key == 'artists' ? 'MRLIR' : 'MTRIR';
          final items = <Map<String, dynamic>>[];
          for (final raw in carouselContents) {
            final node = _safeMap(raw[renderer]);
            if (node == null) continue;
            final item = _parseChartItem(node, renderer);
            if (item != null) items.add(item);
          }
          if (items.isNotEmpty) {
            matchedKey = key;
            matchedItems = items;
            break;
          }
        }

        if (matchedKey != null) {
          charts[matchedKey] = matchedItems;
          foundKeys.add(matchedKey);
        }
      }

      // Premium accounts surface both daily and weekly, but we may have
      // already stored 'videos'. Drop the 'videos' key in that case.
      if (charts.containsKey('daily') || charts.containsKey('weekly')) {
        charts.remove('videos');
      }

      YTCacheHelper.writeStampedCache('charts_$country', charts);
      return charts;
    } catch (e) {
      debugPrint('YTM getCharts error: $e');
      return {};
    }
  }

  /// Permissive parser: accepts any Map and converts to Map<String, dynamic>
  /// when possible. Returns null if [node] is null or not a Map-like value.
  Map<String, dynamic>? _safeMap(dynamic node) {
    if (node is Map<String, dynamic>) return node;
    if (node is Map) {
      try {
        return Map<String, dynamic>.from(node);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic>? _parseChartItem(Map<String, dynamic> node, String renderer) {
    try {
      if (renderer == 'MRLIR') {
        // Artist: title + browseId (UC...) + subscribers + thumbnails + rank + trend.
        final flexColumns = node['flexColumns'];
        final titleText = _flexColumnText(flexColumns, 0);
        final subsText = _flexColumnText(flexColumns, 1);
        final subscribers = subsText?.split(' ').first;
        final browseId = _navBrowseId(node);
        final thumbnails = node['thumbnails'] ?? node['thumbnail'];
        final ranking = _extractRanking(node);
        return <String, dynamic>{
          'title': titleText,
          'browseId': browseId,
          'subscribers': subscribers,
          'thumbnails': thumbnails,
          if (ranking != null) 'rank': ranking['rank'],
          if (ranking != null) 'trend': ranking['trend'],
        };
      } else {
        // Playlist/video: title + playlistId (PL...) + thumbnails.
        final titleText = _navTitle(node);
        final playlistId = _navString(node, [
          'navigationEndpoint',
          'browseEndpoint',
          'browseId',
        ]);
        final cleanedPlaylistId = playlistId == null
            ? null
            : (playlistId.startsWith('VL')
                ? playlistId.substring(2)
                : playlistId);
        final thumbnails = node['thumbnails'] ?? node['thumbnail'];
        return <String, dynamic>{
          'title': titleText,
          'playlistId': cleanedPlaylistId,
          'thumbnails': thumbnails,
        };
      }
    } catch (_) {
      return null;
    }
  }

  String? _flexColumnText(dynamic flexColumns, int index) {
    if (flexColumns is! List) return null;
    if (index < 0 || index >= flexColumns.length) return null;
    final col = flexColumns[index];
    if (col is! Map) return null;
    final runs = col['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
    if (runs is List && runs.isNotEmpty) {
      final first = runs.first;
      if (first is Map && first['text'] is String) return first['text'] as String;
    }
    return null;
  }

  Map<String, dynamic>? _extractRanking(Map<String, dynamic> node) {
    final col = node['customIndexColumn']?['musicCustomIndexColumnRenderer'];
    if (col is! Map) return null;
    final runs = col['text']?['runs'];
    final rank = runs is List && runs.isNotEmpty && runs.first is Map
        ? runs.first['text']?.toString()
        : null;
    final trend = col['icon']?['iconType']?.toString();
    return {'rank': rank, 'trend': trend};
  }

  String? _navTitle(dynamic node) {
    if (node is! Map) return null;
    final title = node['title'];
    if (title is Map) {
      final runs = title['runs'];
      if (runs is List && runs.isNotEmpty && runs.first is Map) {
        return runs.first['text']?.toString();
      }
      final simple = title['simpleText'];
      if (simple is String) return simple;
    }
    if (title is String) return title;
    return null;
  }

  String? _navBrowseId(dynamic node) {
    return _navString(node, ['navigationEndpoint', 'browseEndpoint', 'browseId']);
  }

  String? _navString(dynamic node, List<String> path) {
    dynamic current = node;
    for (final key in path) {
      if (current is! Map) return null;
      current = current[key];
    }
    return current is String ? current : null;
  }

  dynamic _navOrNull(dynamic node, List<String> path) {
    dynamic current = node;
    for (final key in path) {
      if (current is! Map) return null;
      current = current[key];
    }
    return current;
  }

  List _navList(dynamic node, List<Object> path) {
    dynamic current = node;
    for (final key in path) {
      if (current is Map) {
        current = current[key];
      } else if (current is List && key is int) {
        if (key < 0 || key >= current.length) return const [];
        current = current[key];
      } else {
        return const [];
      }
    }
    return current is List ? current : const [];
  }

  Map? _navMap(dynamic node, List<Object> path) {
    dynamic current = node;
    for (final key in path) {
      if (current is Map) {
        current = current[key];
      } else if (current is List && key is int) {
        if (key < 0 || key >= current.length) return null;
        current = current[key];
      } else {
        return null;
      }
    }
    return current is Map ? current : null;
  }

  Future<Map<String, dynamic>?> getCachedCharts({String country = 'ZZ'}) async {
    final cached = await YTCacheHelper.readStampedCache('charts_$country', maxAge: const Duration(minutes: 30));
    if (cached == null) return null;
    if (cached.data is Map) return Map<String, dynamic>.from(cached.data);
    return null;
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
  Future<List<Song>> getRadioSongs(String videoId, {int limit = 25}) async {
    await init();
    if (_ytm == null) return [];

    if (_radioCache.containsKey(videoId)) {
      return _radioCache[videoId]!;
    }

    List<Song>? result;
    for (int attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(milliseconds: 200 * (1 << attempt)));
      }
      try {
        // Bypass ytmusicapi_dart's parseWatchPlaylist (force-unwraps null
        // primaryRenderer / counterpart / tabs and throws TypeError on
        // malformed watch items). We send the same 'next' request ourselves
        // and parse the raw panel contents locally.
        final rawContents = await _fetchRadioPanelContents(videoId, limit: limit);
        if (rawContents.isNotEmpty) {
          final parsed = _parseWatchPlaylistSafe(rawContents);
          if (parsed.isNotEmpty) {
            result = parsed.skip(1).map(mapToSong).toList();
            break;
          }
        }
      } on TypeError {
        // Deterministic cast failure — retrying yields the same error.
        debugPrint(
          'YTM getRadioSongs: parse error in response, returning empty',
        );
        break;
      } catch (e) {
        debugPrint('YTM getRadioSongs error (attempt ${attempt + 1}): $e');
      }
    }

    if (result == null || result.isEmpty) {
      return [];
    }

    _cacheRadioSongs(videoId, result);
    return result;
  }

  /// Sends the same 'next' request as `getWatchPlaylist(radio: true)` and
  /// returns the raw `playlistPanelRenderer.contents` list. We avoid the
  /// upstream `parseWatchPlaylist` because it throws on malformed items.
  /// Continuations are intentionally skipped — the first page is enough
  /// to seed a radio queue.
  Future<List<dynamic>> _fetchRadioPanelContents(
    String videoId, {
    int limit = 25,
  }) async {
    final ytm = _ytm;
    if (ytm == null) return const [];

    final body = <String, dynamic>{
      'enablePersistentPlaylistPanel': true,
      'isAudioOnly': true,
      'tunerSettingValue': 'AUTOMIX_SETTING_NORMAL',
      'videoId': videoId,
      'playlistId': 'RDAMVM$videoId',
      'params': 'wAEB',
    };

    final response = await ytm.sendRequest('next', body);

    final watchNextRenderer = nav(response, [
      'contents',
      'singleColumnMusicWatchNextResultsRenderer',
      'tabbedRenderer',
      'watchNextTabbedResultsRenderer',
    ]);

    final panel = nav(
      watchNextRenderer,
      [...TAB_CONTENT, 'musicQueueRenderer', 'content', 'playlistPanelRenderer'],
      nullIfAbsent: true,
    );

    if (panel is! Map) return const [];
    final contents = panel['contents'];
    if (contents is List && contents.length >= limit) return contents;
    return contents is List ? contents : const [];
  }

  /// Null-safe replacement for `ytmusicapi_dart`'s `parseWatchPlaylist`.
  /// Each item is parsed in its own try/catch so one malformed entry can't
  /// poison the whole batch. Returns maps shaped for `mapToSong`:
  /// `videoId`, `title`, `artists`, `album`, `thumbnail`, `length`.
  ///
  /// TODO: Delete this once `ytmusicapi_dart` is fixed upstream and we
  /// bump the dependency.
  List<Map<String, dynamic>> _parseWatchPlaylistSafe(List<dynamic> rawContents) {
    const String ppvwr = 'playlistPanelVideoWrapperRenderer';
    const String ppvr = 'playlistPanelVideoRenderer';
    final tracks = <Map<String, dynamic>>[];

    for (final raw in rawContents) {
      if (raw is! Map) continue;
      Map result = raw;

      try {
        Map<String, dynamic>? data;

        if (result.containsKey(ppvwr)) {
          final wrapper = result[ppvwr];
          if (wrapper is! Map) continue;
          final primary = wrapper['primaryRenderer'];
          if (primary is! Map) continue;
          result = primary;
        }

        final ppvrData = result[ppvr];
        if (ppvrData is! Map) continue;
        data = Map<String, dynamic>.from(ppvrData);

        if (data.containsKey('unplayableText')) continue;

        final track = <String, dynamic>{
          'videoId': data['videoId'],
          'title': nav(data, TITLE_TEXT),
          'length': nav(
            data,
            ['lengthText', 'runs', 0, 'text'],
            nullIfAbsent: true,
          ),
          'thumbnail': nav(data, THUMBNAIL, nullIfAbsent: true),
        };

        final longByline = data['longBylineText'];
        if (longByline is Map) {
          final runs = longByline['runs'];
          if (runs is List) {
            try {
              track.addAll(parseSongRuns(runs));
            } catch (_) {
              // Skip artist extraction on parse failure; track is still valid.
            }
          }
        }

        tracks.add(track);
      } catch (_) {
        continue;
      }
    }

    return tracks;
  }

  void _cacheRadioSongs(String videoId, List<Song> songs) {
    _radioCache[videoId] = songs;
    _persistRadioCache();
  }

  Future<void> _persistRadioCache() async {
    if (_cacheDir == null) return;
    try {
      final file = File('$_cacheDir/radio_cache.json');
      final data = <String, List<Map<String, dynamic>>>{};
      _radioCache.forEach((key, songs) {
        data[key] = songs.map(_songToJson).toList();
      });
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _loadRadioCache() async {
    if (_cacheDir == null) return;
    try {
      final file = File('$_cacheDir/radio_cache.json');
      if (!await file.exists()) return;
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      data.forEach((key, value) {
        final songs = (value as List)
            .map((e) => _songFromJson(e as Map<String, dynamic>))
            .toList();
        _radioCache[key] = songs;
      });
    } catch (_) {}
  }

  Future<String?> getAccountName() async {
    await init();
    try {
      final data = await _sendRequest('account/account_menu', {});
      // Walk the response looking for a "simpleText" account name.
      String? found;
      _walkForSimpleText(data, 'accountName', (v) {
        if (found == null && v is String && v.isNotEmpty) found = v;
      });
      return found;
    } catch (e) {
      debugPrint('Failed to get YT account name: $e');
    }
    return null;
  }

  void _walkForSimpleText(
      dynamic node, String key, void Function(dynamic) onMatch) {
    if (node is Map) {
      if (node.containsKey(key)) {
        final val = node[key];
        if (val is Map && val.containsKey('simpleText')) {
          onMatch(val['simpleText']);
        } else if (val is String) {
          onMatch(val);
        }
      }
      for (final v in node.values) {
        _walkForSimpleText(v, key, onMatch);
      }
    } else if (node is List) {
      for (final v in node) {
        _walkForSimpleText(v, key, onMatch);
      }
    }
  }

  Song _songFromJson(Map<String, dynamic> json) {
    return Song(
      path: json['path'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown',
      artist: json['artist'] as String? ?? 'Unknown',
      album: json['album'] as String?,
      hasAlbumArt: json['hasAlbumArt'] as bool? ?? true,
      lyrics: null,
      duration: json['durationMs'] != null
          ? Duration(milliseconds: json['durationMs'] as int)
          : null,
      bitrate: json['bitrate'] as int?,
      size: json['size'] as int?,
      modifiedAt: null,
      gainDb: 0.0,
      trackPeak: 1.0,
      albumGainDb: 0.0,
      albumPeak: 1.0,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }

  Map<String, dynamic> _songToJson(Song song) {
    return {
      'path': song.path,
      'title': song.title,
      'artist': song.artist,
      'album': song.album,
      'durationMs': song.duration?.inMilliseconds,
      'thumbnailUrl': song.thumbnailUrl,
      'hasAlbumArt': song.hasAlbumArt,
    };
  }
}

final youtubeDatasource = YoutubeDatasource();

