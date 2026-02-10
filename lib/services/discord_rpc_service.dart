import 'dart:async';
import 'package:dart_discord_presence/dart_discord_presence.dart';
import '../models/song.dart';

class DiscordRpcService {
  static final DiscordRpcService _instance = DiscordRpcService._internal();
  factory DiscordRpcService() => _instance;
  DiscordRpcService._internal();

  DiscordRPC? _rpc;
  bool _isConnected = false;
  Completer<void>? _initCompleter;

  static const String _applicationId = '1453422309057757307';

  String _truncate(String? text, int maxLength) {
    if (text == null || text.isEmpty) return '';
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  String _sanitize(String? text) {
    if (text == null) return '';
    return text
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('…', '...')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '') // Remove control characters
        .trim();
  }

  Future<void> init() async {
    if (_isConnected && _rpc != null && _rpc!.isInitialized) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();

    try {
      print('DiscordRpcService: Initializing with ID $_applicationId');
      _rpc = DiscordRPC();
      await _rpc!.initialize(_applicationId);
      _isConnected = true;
      print('DiscordRpcService: Connected.');
    } catch (e) {
      print('DiscordRpcService: Init error: $e');
      _isConnected = false;
    } finally {
      if (!(_initCompleter?.isCompleted ?? true)) {
        _initCompleter?.complete();
      }
      _initCompleter = null;
    }
  }

  Future<void> updatePresence(
    Song song, {
    String? artworkUrl,
    bool isPlaying = true,
    int? startTimeStamp,
  }) async {
    try {
      if (!_isConnected || _rpc == null) {
        await init();
      }

      if (!_isConnected || _rpc == null) return;

      print(
        'DiscordRpcService: updatePresence called for "${song.title}" (playing: $isPlaying)',
      );

      final presence = DiscordPresence(
        type: DiscordActivityType.listening,
        details: _truncate(_sanitize(song.title), 128),
        state: _truncate(_sanitize(song.artist), 128),
        timestamps: startTimeStamp != null
            ? DiscordTimestamps(start: startTimeStamp ~/ 1000)
            : (isPlaying ? DiscordTimestamps.started(DateTime.now()) : null),
        largeAsset: artworkUrl != null && artworkUrl.startsWith('http')
            ? DiscordAsset.fromUrl(
                artworkUrl,
                text: isPlaying ? '▸ Playing' : '⏸︎ Paused',
              )
            : DiscordAsset(
                key: artworkUrl ?? 'app_icon',
                text: isPlaying ? '▸ Playing' : '⏸︎ Paused',
              ),
      );

      await _rpc!.setPresence(presence);
      print('DiscordRpcService: updatePresence sent successfully.');
    } catch (e, stack) {
      print('DiscordRpcService: updatePresence error: $e');
      print('Stack trace: $stack');
      _isConnected = false;
    }
  }

  Future<void> clearPresence() async {
    if (!_isConnected || _rpc == null) return;

    try {
      print('DiscordRpcService: Clearing presence...');
      await _rpc!.clearPresence();
    } catch (e) {
      print('DiscordRpcService: clearPresence error: $e');
      _isConnected = false;
    }
  }

  Future<void> dispose() async {
    print('DiscordRpcService: Disposing and disconnecting...');
    try {
      await _rpc!.shutdown();
    } catch (e) {
      // Ignore errors during disconnect
    }
    _rpc = null;
    _isConnected = false;
  }
}
