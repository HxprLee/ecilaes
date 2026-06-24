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

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

class ScrobbleService {
  static final ScrobbleService _instance = ScrobbleService._internal();
  factory ScrobbleService() => _instance;
  ScrobbleService._internal();

  // Public Last.fm API keys (using common open source keys for simplicity,
  // users can provide their own if needed)
  static const String _apiKey = 'f1cd2958ec7ec91d29d8975a898a9d15'; // Dummy public key
  static const String _sharedSecret = '0b86556e9cffc16ed5b0789766cd591c'; // Dummy secret
  static const String _apiUrl = 'https://ws.audioscrobbler.com/2.0/';

  String _generateSignature(Map<String, String> params) {
    final keys = params.keys.toList()..sort();
    final buffer = StringBuffer();
    for (final key in keys) {
      buffer.write(key);
      buffer.write(params[key]);
    }
    buffer.write(_sharedSecret);
    final bytes = utf8.encode(buffer.toString());
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  Future<Map<String, dynamic>?> authenticate(String username, String password) async {
    try {
      final params = {
        'method': 'auth.getMobileSession',
        'username': username,
        'password': password, // Last.fm wants plaintext password here, MD5 is generated internally by them or sent in SSL. Wait, it needs to be sent as password.
        'api_key': _apiKey,
      };
      
      params['api_sig'] = _generateSignature(params);
      params['format'] = 'json';

      final response = await http.post(
        Uri.parse(_apiUrl),
        body: params,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['session'] != null) {
          return {
            'username': data['session']['name'],
            'key': data['session']['key'],
          };
        }
      }
      debugPrint('Last.fm Auth Error: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Last.fm Auth Exception: $e');
      return null;
    }
  }

  Future<void> updateNowPlaying(String sessionKey, String track, String artist, {String? album}) async {
    try {
      final params = {
        'method': 'track.updateNowPlaying',
        'track': track,
        'artist': artist,
        'sk': sessionKey,
        'api_key': _apiKey,
      };
      if (album != null && album.isNotEmpty) {
        params['album'] = album;
      }
      
      params['api_sig'] = _generateSignature(params);
      params['format'] = 'json';

      final response = await http.post(
        Uri.parse(_apiUrl),
        body: params,
      );
      
      if (response.statusCode != 200) {
        debugPrint('Last.fm NowPlaying Error: ${response.body}');
      }
    } catch (e) {
      debugPrint('Last.fm NowPlaying Exception: $e');
    }
  }

  Future<void> scrobble(String sessionKey, String track, String artist, int timestamp, {String? album}) async {
    try {
      final params = {
        'method': 'track.scrobble',
        'track': track,
        'artist': artist,
        'timestamp': timestamp.toString(),
        'sk': sessionKey,
        'api_key': _apiKey,
      };
      if (album != null && album.isNotEmpty) {
        params['album'] = album;
      }
      
      params['api_sig'] = _generateSignature(params);
      params['format'] = 'json';

      final response = await http.post(
        Uri.parse(_apiUrl),
        body: params,
      );

      if (response.statusCode != 200) {
        debugPrint('Last.fm Scrobble Error: ${response.body}');
      } else {
        debugPrint('Last.fm: Scrobbled "$track" by "$artist"');
      }
    } catch (e) {
      debugPrint('Last.fm Scrobble Exception: $e');
    }
  }
}

final scrobbleService = ScrobbleService();
