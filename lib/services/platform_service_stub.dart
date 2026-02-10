import 'platform_service.dart';

PlatformService getPlatformService() => PlatformServiceStub();

class PlatformServiceStub implements PlatformService {
  @override
  Future<void> init() async {
    // No-op on mobile/web
  }

  @override
  Future<void> updatePresence(
    dynamic song, {
    String? artworkUrl,
    bool isPlaying = true,
    int? startTimeStamp,
  }) async {
    // No-op on mobile/web
  }

  @override
  Future<void> clearPresence() async {
    // No-op on mobile/web
  }

  @override
  Future<void> dispose() async {
    // No-op on mobile/web
  }
}
