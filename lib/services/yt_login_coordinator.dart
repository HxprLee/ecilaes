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
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../signals/audio_signal.dart';
import '../signals/settings_signal.dart';
import 'YoutubeDatasource.dart';

class YtLoginResult {
  YtLoginResult({
    required this.success,
    this.cookieString,
    this.username,
    this.error,
  });

  final bool success;
  final String? cookieString;
  final String? username;
  final String? error;
}

/// Drives the YouTube Music sign-in flow.
///
/// On Android, iOS, macOS, Windows, and web the screen renders an embedded
/// `flutter_inappwebview` and the coordinator reads the session cookies out
/// of `CookieManager`. On Linux `flutter_inappwebview` has no native
/// implementation ([MissingPluginException] at runtime), so the screen
/// surfaces a manual-paste path and never touches `CookieManager`.
class YtLoginCoordinator {
  static final YtLoginCoordinator _instance = YtLoginCoordinator._();
  factory YtLoginCoordinator() => _instance;
  YtLoginCoordinator._();

  static final Uri signInUri = Uri.parse('https://music.youtube.com/signin');

  /// Re-checks the cookie store and finalizes if cookies are present.
  /// Returns `null` if no auth cookies are yet visible to the
  /// `flutter_inappwebview` cookie jar.
  Future<YtLoginResult?> finalizeFromCookies() async {
    final cookies = await _readCookiesForMusicYoutube();
    if (cookies == null) return null;
    return await _finalize(cookies);
  }

  /// Persists a cookie string the user pasted from another browser. Works
  /// on every platform including Linux.
  Future<YtLoginResult> acceptManualCookie(String cookieString) async {
    final stripped = cookieString.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    if (!stripped.contains('SAPISID') &&
        !stripped.contains('__Secure-1PAPISID') &&
        !stripped.contains('__Secure-3PAPISID')) {
      return YtLoginResult(
        success: false,
        error:
            'That does not look like a YouTube cookie. Missing SAPISID.',
      );
    }
    return await _finalize(stripped);
  }

  Future<YtLoginResult> _finalize(String cookieString) async {
    await settingsSignal.updateYtAuthCookie(cookieString);
    String? username;
    try {
      final src = YoutubeDatasource();
      username = await src.getAccountName();
      if (username != null && username.isNotEmpty) {
        await settingsSignal.updateYtAuthCookie(
          cookieString,
          username: username,
        );
      }
    } catch (e) {
      debugPrint('YtLoginCoordinator: getAccountName failed: $e');
    }
    unawaited(audioSignal.reindexLibrary());
    return YtLoginResult(
      success: true,
      cookieString: cookieString,
      username: username,
    );
  }

  Future<String?> _readCookiesForMusicYoutube() async {
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri('https://music.youtube.com'),
      );
      if (cookies.isEmpty) return null;
      const authCookieNames = <String>{
        'SAPISID',
        '__Secure-1PAPISID',
        '__Secure-3PAPISID',
        'SID',
        '__Secure-1PSID',
        '__Secure-3PSID',
        'HSID',
        'SSID',
        'APISID',
        'LOGIN_INFO',
        'PREF',
      };
      final kept = cookies.where((c) =>
          c.name.isNotEmpty &&
          c.value.isNotEmpty &&
          (authCookieNames.contains(c.name) ||
              c.name.startsWith('VISITOR_INFO1_LIVE') ||
              c.name == 'YSC'));
      if (kept.isEmpty) return null;
      final joined =
          kept.map((c) => '${c.name}=${c.value}').join('; ');
      final stripped = joined.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
      final hasAuth = stripped.contains('SAPISID') ||
          stripped.contains('__Secure-1PAPISID') ||
          stripped.contains('__Secure-3PAPISID');
      return hasAuth ? stripped : null;
    } catch (e) {
      debugPrint('YtLoginCoordinator._readCookiesForMusicYoutube error: $e');
      return null;
    }
  }
}

final ytLoginCoordinator = YtLoginCoordinator();
