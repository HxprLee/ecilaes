import 'platform_service_stub.dart'
    if (dart.library.io) 'platform_service_desktop.dart';

abstract class PlatformService {
  static final PlatformService _instance = getPlatformService();
  factory PlatformService() => _instance;

  Future<void> init();
  Future<void> updatePresence(
    dynamic song, {
    String? artworkUrl,
    bool isPlaying = true,
    int? startTimeStamp,
  });
  Future<void> clearPresence();
  Future<void> dispose();
}
