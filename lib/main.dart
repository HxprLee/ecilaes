import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:romanize/romanize.dart';
import 'router.dart';

import 'package:audio_service/audio_service.dart';
import 'services/audio_handler.dart';
import 'services/platform_service.dart';
import 'package:music_app/theme/app_theme_builder.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'signals/audio_signal.dart';
import 'signals/settings_signal.dart';

late AudioHandler _audioHandler;

bool get isDesktop =>
    !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

Future<void> main() async {
  print('APP_START: Starting main()');
  // Ensure widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();
  print('APP_START: Widgets initialized');

  // Initialize JustAudioMediaKit (MPV backend)
  JustAudioMediaKit.ensureInitialized();

  // Initialize Navigation Listener
  initNavigationListener();

  // Initialize Signals (Load settings early for single instance check)
  await settingsSignal.loadSettings();

  // Preload romanization dictionaries
  TextRomanizer.ensureInitialized();

  // Single Instance Support
  if (isDesktop && settingsSignal.useSingleInstance.value) {
    final isFirstInstance = await FlutterSingleInstance().isFirstInstance();
    if (!isFirstInstance) {
      print(
        'APP_START: Another instance is running. Bringing to front and exiting.',
      );
      await FlutterSingleInstance().focus();
      exit(0);
    }
  }

  // Initialize platform-specific features (Desktop only)
  await PlatformService().init();

  print('APP_START: Initializing AudioService');
  // Initialize AudioService
  _audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.music_app.channel.audio',
      androidNotificationChannelName: 'Music Playback',
    ),
  );
  print('APP_START: AudioService initialized');

  // Request Android Permissions
  await requestAndroidPermissions();

  // Initialize Audio Signal
  await audioSignal.init(_audioHandler);

  // Configure System UI for Edge-to-Edge
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ),
  );

  print('APP_START: Running app');
  runApp(const MusicApp());

  // Bitsdojo Window Initialization
  if (isDesktop) {
    doWhenWindowReady(() {
      const initialSize = Size(1280, 720);
      appWindow.minSize = const Size(400, 600);
      appWindow.size = initialSize;
      appWindow.alignment = Alignment.center;
      appWindow.title = "Music App";
      appWindow.show();
    });
  }
}

Future<void> requestAndroidPermissions() async {
  if (Platform.isAndroid) {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.audio,
      Permission.storage,
      Permission.notification,
    ].request();

    print('Android Permissions: $statuses');
  }
}

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final textScale = settingsSignal.textScaleFactor.value;
      final useCustomFont = settingsSignal.useCustomFont.value;

      return MaterialApp.router(
        title: 'Music App',
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: AppThemeBuilder.buildLight(
          settingsSignal.themeStyle.value,
          fontFamily: useCustomFont ? 'Iosevka Nerd Font' : null,
          seedColor: audioSignal.dynamicThemeSeed.value,
          isDesktop: isDesktop,
          desktopTransparency: settingsSignal.enableWindowTransparency.value,
        ),
        darkTheme: AppThemeBuilder.buildDark(
          settingsSignal.themeStyle.value,
          fontFamily: useCustomFont ? 'Iosevka Nerd Font' : null,
          seedColor: audioSignal.dynamicThemeSeed.value,
          isDesktop: isDesktop,
          desktopTransparency: settingsSignal.enableWindowTransparency.value,
        ),
        themeMode: settingsSignal.themeMode.value,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          );
        },
      );
    });
  }
}
