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
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:nativeapi/nativeapi.dart' as native;
import 'package:window_manager/window_manager.dart';
import 'package:signals/signals_flutter.dart';
import 'package:dart_discord_presence/dart_discord_presence.dart';
import '../signals/audio_signal.dart';
import '../signals/settings_signal.dart';
import 'platform_service.dart';
import 'discord_rpc_service.dart';

class _AppWindowListener extends WindowListener {
  @override
  Future<void> onWindowClose() async {
    audioSignal.stop();
    await audioSignal.disposePlayer();
    try {
      await DiscordRpcService().dispose();
    } catch (_) {
      // Don't block shutdown on a misbehaving RPC client.
    }
    try {
      await PlatformService().dispose();
    } catch (_) {
      // Don't block shutdown on a misbehaving platform service.
    }
    exit(0);
  }
}

class PlatformServiceDesktopImpl implements PlatformService {
  native.TrayIcon? _trayIcon;
  native.Menu? _trayMenu;
  native.MenuItem? _playPauseItem;
  void Function()? _trayEffectCleanup;
  final _AppWindowListener _windowListener = _AppWindowListener();

  @override
  Future<void> init() async {
    if (kIsWeb) return;
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      // Explicitly register JustAudioMediaKit on Desktop
      JustAudioPlatform.instance = JustAudioMediaKit();
      JustAudioMediaKit.ensureInitialized();

      // Initialize window effect based on transparency setting
      await Window.initialize();
      final isTransparent = settingsSignal.enableWindowTransparency.value;
      if (isTransparent) {
        await Window.setEffect(
          effect: WindowEffect.transparent,
          color: const Color(0x00000000),
        );
      } else {
        await Window.setEffect(
          effect: WindowEffect.disabled,
          color: const Color.fromARGB(255, 18, 22, 26),
        );
      }

      await windowManager.ensureInitialized();
      windowManager.addListener(_windowListener);

      // Initialize Discord RPC
      await DiscordRpcService().init();

      // Initialize System Tray
      await _setupTray();
    }
  }

  Future<void> _setupTray() async {
    try {
      // Create menu items
      final prevItem = native.MenuItem("Previous");
      _playPauseItem = native.MenuItem("Play");
      final nextItem = native.MenuItem("Next");
      final showItem = native.MenuItem("Show");
      final quitItem = native.MenuItem("Quit");

      // Setup Menu
      _trayMenu = native.Menu();
      _trayMenu!.addItem(prevItem);
      _trayMenu!.addItem(_playPauseItem!);
      _trayMenu!.addItem(nextItem);
      _trayMenu!.addSeparator();
      _trayMenu!.addItem(showItem);
      _trayMenu!.addSeparator();
      _trayMenu!.addItem(quitItem);

      // Setup Tray Icon
      _trayIcon = native.TrayIcon();

      // Load Icon
      native.Image? icon;
      try {
        icon = native.Image.fromAsset('assets/icons/ic_launcher.png');
      } catch (e) {
        debugPrint("Error loading tray icon from asset: $e");
      }

      if (icon == null && Platform.isLinux) {
        // Fallback for Linux if asset loading fails
        try {
          final exePath = File(Platform.resolvedExecutable).parent.path;
          final assetPath = '$exePath/data/flutter_assets/assets/icons/ic_launcher.png';
          final file = File(assetPath);
          if (await file.exists()) {
            icon = native.Image.fromFile(assetPath);
          } else {
            debugPrint("Tray icon not found at $assetPath");
          }
        } catch (e) {
          debugPrint("Error loading tray icon from path: $e");
        }
      }

      if (icon != null) {
        _trayIcon!.icon = icon;
      } else {
        debugPrint("Failed to load tray icon");
      }

      _trayIcon!.title = "ecilaes";
      _trayIcon!.tooltip = "ecilaes";
      _trayIcon!.contextMenu = _trayMenu;
      _trayIcon!.contextMenuTrigger = native.ContextMenuTrigger.rightClicked;

      // Event Listeners (using addCallbackListener which auto-starts listening)

      // Handle Tray Clicks
      _trayIcon!.addCallbackListener<native.TrayIconClickedEvent>((e) async {
        await windowManager.show();
      });

      // Note: Right click handled by contextMenuTrigger

      // Menu Actions
      prevItem.addCallbackListener<native.MenuItemClickedEvent>(
        (e) => audioSignal.skipPrevious(),
      );
      nextItem.addCallbackListener<native.MenuItemClickedEvent>(
        (e) => audioSignal.skipNext(),
      );

      _playPauseItem!.addCallbackListener<native.MenuItemClickedEvent>((e) {
        if (audioSignal.isPlaying.value) {
          audioSignal.pause();
        } else {
          audioSignal.play();
        }
      });

      showItem.addCallbackListener<native.MenuItemClickedEvent>((e) async {
        await windowManager.show();
      });

      quitItem.addCallbackListener<native.MenuItemClickedEvent>((e) {
        windowManager.close();
      });

      // Sync Play/Pause Label
      _trayEffectCleanup = effect(() {
        final isPlaying = audioSignal.isPlaying.value;
        _playPauseItem!.label = isPlaying ? "Pause" : "Play";
      });

      _trayIcon!.isVisible = true;
    } catch (e) {
      debugPrint("Error setting up system tray: $e");
    }
  }

  @override
  Future<void> updatePresence(
    dynamic song, {
    String? artworkUrl,
    bool isPlaying = true,
    int? startTimeStamp,
    int? endTimeStamp,
    List<DiscordButton>? buttons,
  }) async {
    await DiscordRpcService().updatePresence(
      song,
      artworkUrl: artworkUrl,
      isPlaying: isPlaying,
      startTimeStamp: startTimeStamp,
      endTimeStamp: endTimeStamp,
      buttons: buttons,
    );
  }

  @override
  Future<void> clearPresence() async {
    await DiscordRpcService().clearPresence();
  }

  @override
  Future<void> dispose() async {
    await DiscordRpcService().dispose();
    _trayEffectCleanup?.call();
    _trayIcon?.removeAllListeners();
    windowManager.removeListener(_windowListener);
  }
}
