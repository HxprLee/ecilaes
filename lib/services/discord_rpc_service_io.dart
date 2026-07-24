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
import 'package:dart_discord_presence/dart_discord_presence.dart';
import '../models/song.dart';
import '../signals/settings_signal.dart';

/// Snapshot of the desired Discord Rich Presence.
///
/// Used as the key for both deduplication and the latest-intent queue so
/// rapid playback changes coalesce into a single in-flight write.
class DiscordPresenceSnapshot {
  const DiscordPresenceSnapshot({
    required this.song,
    required this.artworkUrl,
    required this.isPlaying,
    required this.startTimeStamp,
    required this.endTimeStamp,
    required this.buttons,
  });

  final Song? song;
  final String? artworkUrl;
  final bool isPlaying;
  final int? startTimeStamp;
  final int? endTimeStamp;
  final List<DiscordButton> buttons;

  bool get isCleared => song == null;

  static const DiscordPresenceSnapshot cleared = DiscordPresenceSnapshot(
    song: null,
    artworkUrl: null,
    isPlaying: false,
    startTimeStamp: null,
    endTimeStamp: null,
    buttons: <DiscordButton>[],
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DiscordPresenceSnapshot) return false;
    if (song?.path != other.song?.path) return false;
    if (song?.title != other.song?.title) return false;
    if (song?.artist != other.song?.artist) return false;
    if (song?.album != other.song?.album) return false;
    if (artworkUrl != other.artworkUrl) return false;
    if (isPlaying != other.isPlaying) return false;
    if (startTimeStamp != other.startTimeStamp) return false;
    if (endTimeStamp != other.endTimeStamp) return false;
    if (buttons.length != other.buttons.length) return false;
    for (var i = 0; i < buttons.length; i++) {
      if (buttons[i].label != other.buttons[i].label) return false;
      if (buttons[i].url != other.buttons[i].url) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        song?.path,
        song?.title,
        song?.artist,
        song?.album,
        artworkUrl,
        isPlaying,
        startTimeStamp,
        endTimeStamp,
        Object.hashAll([
          for (final b in buttons) Object.hash(b.label, b.url),
        ]),
      );
}

/// Serializes access to the underlying `dart_discord_presence` client,
/// coalesces rapid presence changes into last-write-wins, and recovers
/// automatically when Discord disconnects or restarts.
class DiscordRpcService {
  static final DiscordRpcService _instance = DiscordRpcService._internal();
  factory DiscordRpcService() => _instance;
  DiscordRpcService._internal();

  DiscordRPC? _rpc;
  StreamSubscription<DiscordEvent>? _rpcEventSubscription;
  bool _initialized = false;
  bool _disposed = false;
  bool _connecting = false;
  Timer? _reconnectTimer;

  // Latest intent requested by the app.
  DiscordPresenceSnapshot _pending = DiscordPresenceSnapshot.cleared;
  // Snapshot currently considered "committed" — used for dedup so the next
  // request short-circuits only when nothing meaningful changed.
  DiscordPresenceSnapshot? _committed;

  // Serial tail of RPC write operations so concurrent flushes always observe
  // last-write-wins ordering at the Discord IPC layer.
  Future<void> _writeTail = Future<void>.value();

  // Bumped on every dispose() and reconnect; in-flight writes compare against
  // it so a write started before teardown doesn't resurrect state.
  int _writeGeneration = 0;

  // Sliding-window counter for non-fatal RPC errors. We don't disconnect on
  // the first failure — Discord rate-limits presence writes and would
  // otherwise cause reconnect storms when the user scrubs a playlist.
  int _consecutiveWriteFailures = 0;
  DateTime? _writeFailureWindowStart;
  static const Duration _writeFailureWindow = Duration(seconds: 30);
  static const int _writeFailureThreshold = 3;

  // Exponential backoff for reconnect attempts.
  Duration _reconnectDelay = const Duration(seconds: 2);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);

  static const String _applicationId = '1453422309057757307';

  // ─────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────

  /// Establish the Discord IPC connection. Safe to call repeatedly; only
  /// one connection attempt is in flight at a time. Honours the master
  /// `enableDiscordRpc` toggle.
  Future<void> init() async {
    if (_disposed) return;
    if (!_isEnabled) {
      debugPrint('DiscordRpcService: Skipping init (master toggle off).');
      return;
    }
    if (!DiscordRPC.isAvailable) {
      debugPrint('DiscordRpcService: Skipping init (unsupported platform).');
      return;
    }
    if (_initialized && _rpc?.isInitialized == true) return;
    if (_connecting) return;
    _connecting = true;
    try {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;

      // Tear down any leftover client from a previous failed attempt.
      await _disposeRpc();

      _rpc = DiscordRPC();
      _subscribeRpcEvents(_rpc!);

      await _rpc!.initialize(_applicationId);
      _initialized = true;
      _reconnectDelay = const Duration(seconds: 2);
      debugPrint('DiscordRpcService: Connected.');
      // Replay the most recent intent so reconnects restore the user's state.
      await _flushPending();
    } on DiscordNotRunningException {
      _initialized = false;
      debugPrint('DiscordRpcService: Discord is not running.');
      _scheduleReconnect();
    } on DiscordRPCException catch (e) {
      _initialized = false;
      debugPrint('DiscordRpcService: Init error: $e');
      _scheduleReconnect();
    } catch (e) {
      _initialized = false;
      debugPrint('DiscordRpcService: Init error: $e');
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  /// Apply the latest presence. Subsequent calls coalesce — only the
  /// most recent snapshot is written to Discord.
  Future<void> updatePresence(
    Song song, {
    String? artworkUrl,
    bool isPlaying = true,
    int? startTimeStamp,
    int? endTimeStamp,
    List<DiscordButton>? buttons,
  }) async {
    final snapshot = DiscordPresenceSnapshot(
      song: song,
      artworkUrl: artworkUrl,
      isPlaying: isPlaying,
      startTimeStamp: startTimeStamp,
      endTimeStamp: endTimeStamp,
      buttons: buttons ?? _buildButtons(song),
    );
    _pending = snapshot;
    await _flushPending();
  }

  /// Clear the active presence. Coalesces with concurrent updates — a
  /// fresh `updatePresence` that wins the race will be written instead.
  Future<void> clearPresence() async {
    _pending = DiscordPresenceSnapshot.cleared;
    await _flushPending();
  }

  /// Shut the service down. Safe to call repeatedly.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _writeGeneration++;
    await _disposeRpc();
    _pending = DiscordPresenceSnapshot.cleared;
    _committed = null;
  }

  // ─────────────────────────────────────────────────────────────────────
  // Internals
  // ─────────────────────────────────────────────────────────────────────

  bool get _isEnabled {
    // settingsSignal is a top-level singleton; tolerate it not being ready
    // during very early startup by defaulting to enabled.
    try {
      return settingsSignal.enableDiscordRpc.value;
    } catch (_) {
      return true;
    }
  }

  void _subscribeRpcEvents(DiscordRPC rpc) {
    _rpcEventSubscription?.cancel();
    _rpcEventSubscription = rpc.events.listen(
      _onRpcEvent,
      onError: (Object e, StackTrace _) {
        debugPrint('DiscordRpcService: event error: $e');
        _handleDisconnect();
      },
      onDone: _handleDisconnect,
    );
  }

  void _onRpcEvent(DiscordEvent event) {
    switch (event) {
      case DiscordReadyEvent():
        _initialized = true;
        debugPrint('DiscordRpcService: ready.');
      case DiscordDisconnectedEvent():
        debugPrint('DiscordRpcService: disconnected (${event.message}).');
        _handleDisconnect();
      case DiscordErrorEvent():
        debugPrint('DiscordRpcService: error event (${event.message}).');
      case DiscordJoinGameEvent():
      case DiscordSpectateGameEvent():
      case DiscordJoinRequestEvent():
        break;
    }
  }

  void _handleDisconnect() {
    _initialized = false;
    _rpc = null;
    _rpcEventSubscription?.cancel();
    _rpcEventSubscription = null;
    // Invalidate any in-flight write so it doesn't resurrect state.
    _writeGeneration++;
    if (_disposed) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    if (!_isEnabled) {
      // Honour the master toggle across reconnects.
      _reconnectDelay = const Duration(seconds: 2);
      return;
    }
    _reconnectTimer?.cancel();
    final delay = _reconnectDelay;
    _reconnectTimer = Timer(delay, () {
      if (_disposed) return;
      unawaited(init());
    });
    final next = delay * 2;
    _reconnectDelay = next > _maxReconnectDelay ? _maxReconnectDelay : next;
  }

  Future<void> _disposeRpc() async {
    final rpc = _rpc;
    _rpc = null;
    _initialized = false;
    await _rpcEventSubscription?.cancel();
    _rpcEventSubscription = null;
    if (rpc == null) return;
    try {
      await rpc.shutdown();
    } catch (_) {
      // Best effort during teardown.
    }
  }

  Future<void> _flushPending() {
    if (_disposed) return Future<void>.value();
    _writeTail = _writeTail.then((_) => _writeLatestOnce());
    return _writeTail;
  }

  Future<void> _writeLatestOnce() async {
    if (_disposed) return;

    final generation = _writeGeneration;
    final pending = _pending;
    if (pending == _committed) return;

    // Master toggle: clear and forget rather than publishing.
    if (!_isEnabled) {
      if (pending.isCleared) {
        _committed = pending;
        return;
      }
      _committed = pending;
      return;
    }

    if (!_initialized || _rpc == null) {
      // Don't spin up a connection just to write a "clear" intent — leave
      // the cleared state as the new committed value so we don't repeatedly
      // attempt to connect while there's nothing to show.
      if (pending.isCleared) {
        _committed = pending;
      } else {
        await init();
      }
      return;
    }

    try {
      if (pending.isCleared) {
        await _rpc!.clearPresence();
      } else {
        await _rpc!.setPresence(_buildPackagePresence(pending));
      }
      _committed = pending;
      _consecutiveWriteFailures = 0;
      _writeFailureWindowStart = null;
    } on DiscordConnectionException catch (e) {
      // Treat as fatal: drop the connection and reconnect with backoff.
      debugPrint('DiscordRpcService: write connection error: $e');
      _handleDisconnect();
    } on DiscordRPCException catch (e) {
      // A protocol/state error is usually a bad payload rather than a broken
      // socket. Log, count toward the threshold, and only reconnect once it
      // has been hit inside the failure window — otherwise we'd cycle the
      // socket on every transient RPC error.
      debugPrint('DiscordRpcService: write error: $e');
      _recordWriteFailure();
      if (_shouldReconnectForFailures()) {
        _handleDisconnect();
      }
    } catch (e) {
      // Unknown: log and let the connection ride. Don't churn the socket.
      debugPrint('DiscordRpcService: write error: $e');
      _recordWriteFailure();
      if (_shouldReconnectForFailures()) {
        _handleDisconnect();
      }
    } finally {
      // The write itself completed; if we were invalidated mid-flight, drop
      // any stale state we might have left behind.
      if (generation != _writeGeneration && !_disposed) {
        _committed = null;
      }
    }
  }

  void _recordWriteFailure() {
    final now = DateTime.now();
    final window = _writeFailureWindowStart;
    if (window == null || now.difference(window) > _writeFailureWindow) {
      _writeFailureWindowStart = now;
      _consecutiveWriteFailures = 1;
    } else {
      _consecutiveWriteFailures++;
    }
  }

  bool _shouldReconnectForFailures() =>
      _consecutiveWriteFailures >= _writeFailureThreshold;

  DiscordPresence _buildPackagePresence(DiscordPresenceSnapshot snapshot) {
    final song = snapshot.song!;
    final artworkUrl = snapshot.artworkUrl;
    final timestamps = snapshot.isPlaying && snapshot.startTimeStamp != null
        ? DiscordTimestamps(
            start: snapshot.startTimeStamp! ~/ 1000,
            end: snapshot.endTimeStamp != null
                ? snapshot.endTimeStamp! ~/ 1000
                : null,
          )
        : null;

    return DiscordPresence(
      type: DiscordActivityType.listening,
      details: _truncate(_sanitize(song.title), 128),
      state: _truncate(_sanitize(song.artist), 128),
      timestamps: timestamps,
      largeAsset: artworkUrl != null && artworkUrl.startsWith('http')
          ? DiscordAsset.fromUrl(artworkUrl)
          : (artworkUrl != null
              ? DiscordAsset(key: artworkUrl)
              : DiscordAsset(key: 'app_icon')),
      buttons: snapshot.buttons.isEmpty ? null : snapshot.buttons,
    );
  }

  List<DiscordButton> _buildButtons(Song song) {
    final enabledButtons = <DiscordButton>[];

    final listenEnabled = settingsSignal.enableDiscordListenButton.value;
    final projectEnabled = settingsSignal.enableDiscordProjectLink.value;

    if (listenEnabled) {
      final url = song.path.startsWith('yt:')
          ? 'https://www.youtube.com/watch?v=${song.path.substring(3)}'
          : null;
      if (url != null) {
        enabledButtons.add(DiscordButton(label: 'Listen on YouTube', url: url));
      }
    }

    if (projectEnabled) {
      enabledButtons.add(DiscordButton(
        label: 'Open Project',
        url: 'https://github.com/HxprLee/ecilaes',
      ));
    }

    return enabledButtons;
  }

  String _truncate(String? text, int maxLength) {
    if (text == null || text.isEmpty) return '';
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  String _sanitize(String? text) {
    if (text == null) return '';
    return text
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"')
        .replaceAll('\u2026', '...')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
  }
}
