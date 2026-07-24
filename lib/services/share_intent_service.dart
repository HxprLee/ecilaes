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
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/song.dart';

class SharedPayload {
  final String kind;
  final String value;

  const SharedPayload({required this.kind, required this.value});

  factory SharedPayload.fromMap(Map<dynamic, dynamic> map) {
    return SharedPayload(
      kind: (map['kind'] as String?) ?? 'text',
      value: (map['value'] as String?) ?? '',
    );
  }

  bool get isUrl => kind == 'url' && value.isNotEmpty;
}

/// Bridge for Android share-in / share-out via platform channels.
/// Desktop platforms have no implementation; calls become silent no-ops.
class ShareIntentService {
  static const MethodChannel _method = MethodChannel('ecilaes/share');
  static const EventChannel _events = EventChannel('ecilaes/share/updates');

  final StreamController<SharedPayload> _controller =
      StreamController<SharedPayload>.broadcast();
  bool _subscribed = false;
  bool _coldStartConsumed = false;

  /// Live stream of share payloads arriving from the host (Android).
  /// The cold-start payload is replayed once on first listen.
  Stream<SharedPayload> get incomingShares async* {
    _ensureSubscribed();
    if (!_coldStartConsumed) {
      _coldStartConsumed = true;
      final initial = await _fetchInitial();
      if (initial != null) yield initial;
    }
    yield* _controller.stream;
  }

  Future<void> _ensureSubscribed() async {
    if (_subscribed) return;
    _subscribed = true;
    _events.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          _controller.add(SharedPayload.fromMap(event));
        }
      },
      onError: (_) {},
    );
  }

  Future<SharedPayload?> _fetchInitial() async {
    try {
      final result = await _method.invokeMethod('getInitialShared');
      if (result is Map) return SharedPayload.fromMap(result);
    } catch (_) {}
    return null;
  }

  /// Dispatch a share for [song]. YouTube-sourced songs share their
  /// music.youtube.com URL; local songs share the underlying audio file.
  ///
  /// On Android we invoke the native share sheet. On all other platforms,
  /// or when the native channel is unavailable, we fall back to copying the
  /// appropriate payload to the system clipboard so the share button always
  /// does something useful.
  Future<void> shareSong(Song song) async {
    final path = song.path;
    if (path.startsWith('yt:')) {
      final url = buildMusicUrl(path);
      final subject = '${song.title} – ${song.artist}';
      await shareText(url, subject: subject, hint: 'URL');
    } else {
      await shareFile(path, mimeType: detectMime(path));
    }
  }

  /// Build a music.youtube.com watch URL for a videoId.
  /// All `yt:` paths in Ecilaes originate from the YT Music API, so the
  /// share URL is always music.youtube.com.
  static String buildMusicUrl(String path) {
    final videoId = path.startsWith('yt:') ? path.substring(3) : path;
    return 'https://music.youtube.com/watch?v=$videoId';
  }

  static String detectMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.flac')) return 'audio/flac';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    return 'audio/*';
  }

  Future<void> shareText(String text, {String? subject, String? hint}) async {
    if (_useClipboardFallback) {
      await _copyToClipboard(text);
      return;
    }
    try {
      await _method.invokeMethod('shareText', {
        'text': text,
        if (subject != null) 'subject': subject,
      });
    } catch (_) {
      await _copyToClipboard(text);
    }
  }

  Future<void> shareFile(String path, {String? mimeType}) async {
    if (_useClipboardFallback) {
      await _copyToClipboard(path);
      return;
    }
    try {
      await _method.invokeMethod('shareFile', {
        'path': path,
        if (mimeType != null) 'mimeType': mimeType,
      });
    } catch (_) {
      await _copyToClipboard(path);
    }
  }

  /// Whether to skip the native chooser and copy the payload to the
  /// system clipboard directly. Mirrors the platform branching the rest
  /// of the app uses (no native share sheet on iOS/Android Emulator or
  /// desktop targets).
  bool get _useClipboardFallback {
    if (kIsWeb) return true;
    if (Platform.isAndroid) return false;
    return true;
  }

  Future<void> _copyToClipboard(String value) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
    } catch (_) {
      // Clipboard unavailable; nothing else to do.
    }
  }

  /// Extract a YouTube/YTMusic videoId from any of the supported URL shapes:
  /// - https://music.youtube.com/watch?v=ID
  /// - https://www.youtube.com/watch?v=ID
  /// - https://youtu.be/ID
  /// - https://youtube.com/shorts/ID
  /// Returns null when the URL is not recognized.
  static String? extractVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host == 'youtu.be') {
      final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      return seg.isEmpty ? null : seg;
    }
    if (host.endsWith('youtube.com') || host.endsWith('youtube-nocookie.com')) {
      final v = uri.queryParameters['v'];
      if (v != null && v.isNotEmpty) return v;
      final segs = uri.pathSegments;
      if (segs.length >= 2 &&
          (segs[segs.length - 2] == 'shorts' || segs[segs.length - 2] == 'embed')) {
        return segs.last;
      }
    }
    return null;
  }

  void dispose() {
    _controller.close();
  }
}

final ShareIntentService shareIntentService = ShareIntentService();