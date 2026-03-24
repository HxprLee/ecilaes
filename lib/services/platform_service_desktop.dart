import 'dart:io';
import 'package:flutter/foundation.dart';
import 'platform_service.dart';
import 'platform_service_desktop_impl.dart' deferred as impl;

PlatformService getPlatformService() => PlatformServiceProxy();

class PlatformServiceProxy implements PlatformService {
  PlatformService? _delegate;

  @override
  Future<void> init() async {
    if (kIsWeb) return;
    // Only load implementation if we are on a desktop platform
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      await impl.loadLibrary();
      _delegate = impl.PlatformServiceDesktopImpl();
      await _delegate!.init();
    }
  }

  @override
  Future<void> updatePresence(
    dynamic song, {
    String? artworkUrl,
    bool isPlaying = true,
    int? startTimeStamp,
    int? endTimeStamp,
  }) async {
    if (_delegate != null) {
      await _delegate!.updatePresence(
        song,
        artworkUrl: artworkUrl,
        isPlaying: isPlaying,
        startTimeStamp: startTimeStamp,
        endTimeStamp: endTimeStamp,
      );
    }
  }

  @override
  Future<void> clearPresence() async {
    if (_delegate != null) {
      await _delegate!.clearPresence();
    }
  }

  @override
  Future<void> dispose() async {
    if (_delegate != null) {
      await _delegate!.dispose();
    }
  }
}
