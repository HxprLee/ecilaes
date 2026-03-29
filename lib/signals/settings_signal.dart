import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals_flutter.dart';
import '../theme/app_theme_style.dart';

class SettingsSignal {
  static final SettingsSignal _instance = SettingsSignal._internal();
  factory SettingsSignal() => _instance;
  SettingsSignal._internal();

  final textScaleFactor = signal<double>(1.0);
  final useCustomWindowControls = signal<bool>(true);
  final useSingleInstance = signal<bool>(true);
  final useCustomFont = signal<bool>(true);
  final backgroundPlayback = signal<bool>(false);
  final swipeDownToStop = signal<bool>(false);
  final musicDirectory = signal<String?>(null);
  final themeMode = signal<ThemeMode>(ThemeMode.dark);
  final enableWindowTransparency = signal<bool>(true);
  final enableGlobalBlur = signal<bool>(true);
  final themeStyle = signal<AppThemeStyle>(AppThemeStyle.signature);
  final pinnedSidebarItems = signal<List<String>>([
    'albums',
    'songs',
    'playlists',
    'folders',
    'artists',
    'downloaded',
  ]);
  final pinnedPlaylistIds = signal<List<String>>(['favorites']);
  final actionsSheetQuickActions = listSignal<String>([
    'add_to_playlist',
    'play_next',
    'add_to_queue',
  ]);
  final actionsSheetListActions = listSignal<String>([
    'go_to_album',
    'go_to_artist',
    'sleep_timer',
    'info',
    'edit_metadata',
    'share',
  ]);
  final actionsSheetShowLabels = signal<bool>(false);
  final playerBarActions = listSignal<String>([
    'shuffle',
    'repeat',
    'lyrics',
    'queue',
    'more',
  ]);

  static const int maxButtonsPerRow = 5;

  final lyricsAlignment = signal<TextAlign>(TextAlign.center);
  final lyricsActiveFontSize = signal<double>(28.0);
  final lyricsInactiveFontSize = signal<double>(22.0);
  final plainLyricsFontSize = signal<double>(18.0);
  final showRomanizedLyrics = signal<bool>(false);
  final lyricsProviders = listSignal<String>([
    'lrclib',
    'simpmusic',
    'better_lyrics',
    'kugou',
  ]);
  final enabledLyricsProviders = listSignal<String>([
    'lrclib',
    'simpmusic',
    'better_lyrics',
    'kugou',
  ]);
  final excludedPaths = listSignal<String>([]);

  // Playback settings
  final gaplessPlayback = signal<bool>(true);
  final audioNormalization = signal<bool>(false);

  // Stream caching
  final enableStreamCaching = signal<bool>(true);
  final enablePreCaching = signal<bool>(true);
  final normalizationTargetLufs = signal<double>(-14.0);

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    textScaleFactor.value = prefs.getDouble('textScaleFactor') ?? 1.0;
    useCustomWindowControls.value =
        prefs.getBool('useCustomWindowControls') ?? true;
    useSingleInstance.value = prefs.getBool('useSingleInstance') ?? true;
    useCustomFont.value = prefs.getBool('useCustomFont') ?? true;
    backgroundPlayback.value = prefs.getBool('backgroundPlayback') ?? false;
    swipeDownToStop.value = prefs.getBool('swipeDownToStop') ?? false;
    musicDirectory.value = prefs.getString('musicDirectory');
    enableWindowTransparency.value =
        prefs.getBool('enableWindowTransparency') ?? true;
    enableGlobalBlur.value = prefs.getBool('enableGlobalBlur') ?? true;

    final themeIndex = prefs.getInt('themeMode');
    if (themeIndex != null &&
        themeIndex >= 0 &&
        themeIndex < ThemeMode.values.length) {
      themeMode.value = ThemeMode.values[themeIndex];
    }

    final styleIndex = prefs.getInt('themeStyle');
    if (styleIndex != null &&
        styleIndex >= 0 &&
        styleIndex < AppThemeStyle.values.length) {
      themeStyle.value = AppThemeStyle.values[styleIndex];
    }

    final pinned = prefs.getStringList('pinnedSidebarItems');
    if (pinned != null) {
      pinnedSidebarItems.value = pinned;
    }

    final pinnedPlaylists = prefs.getStringList('pinnedPlaylistIds');
    if (pinnedPlaylists != null) {
      pinnedPlaylistIds.value = pinnedPlaylists;
    }

    final quick = prefs.getStringList('actionsSheetQuickActions');
    if (quick != null) {
      actionsSheetQuickActions.value = quick;
    }

    final list = prefs.getStringList('actionsSheetListActions');
    if (list != null) {
      actionsSheetListActions.value = list;
    }

    actionsSheetShowLabels.value =
        prefs.getBool('actionsSheetShowLabels') ?? false;
    
    final playerActions = prefs.getStringList('playerBarActions');
    if (playerActions != null) {
      playerBarActions.value = playerActions;
    }

    final alignIndex = prefs.getInt('lyricsAlignment');
    if (alignIndex != null && alignIndex >= 0 && alignIndex < TextAlign.values.length) {
      lyricsAlignment.value = TextAlign.values[alignIndex];
    }
    lyricsActiveFontSize.value = prefs.getDouble('lyricsActiveFontSize') ?? 28.0;
    lyricsInactiveFontSize.value = prefs.getDouble('lyricsInactiveFontSize') ?? 22.0;
    plainLyricsFontSize.value = prefs.getDouble('plainLyricsFontSize') ?? 18.0;

    showRomanizedLyrics.value = prefs.getBool('showRomanizedLyrics') ?? false;

    final providers = prefs.getStringList('lyricsProviders');
    if (providers != null) {
      lyricsProviders.value = providers;
    }

    final enabled = prefs.getStringList('enabledLyricsProviders');
    if (enabled != null) {
      enabledLyricsProviders.value = enabled;
    }

    final excluded = prefs.getStringList('excludedPaths');
    if (excluded != null) {
      excludedPaths.value = excluded;
    }

    gaplessPlayback.value = prefs.getBool('gaplessPlayback') ?? true;
    audioNormalization.value = prefs.getBool('audioNormalization') ?? false;
    normalizationTargetLufs.value = prefs.getDouble('normalizationTargetLufs') ?? -14.0;

    enableStreamCaching.value = prefs.getBool('enableStreamCaching') ?? true;
    enablePreCaching.value = prefs.getBool('enablePreCaching') ?? true;
  }

  Future<void> updateMusicDirectory(String? value) async {
    musicDirectory.value = value;
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove('musicDirectory');
    } else {
      await prefs.setString('musicDirectory', value);
    }
  }

  Future<void> updateTextScale(double value) async {
    textScaleFactor.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('textScaleFactor', value);
  }

  Future<void> updateCustomWindowControls(bool value) async {
    useCustomWindowControls.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useCustomWindowControls', value);
  }

  Future<void> updateSingleInstance(bool value) async {
    useSingleInstance.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useSingleInstance', value);
  }

  Future<void> updateCustomFont(bool value) async {
    useCustomFont.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useCustomFont', value);
  }

  Future<void> updateBackgroundPlayback(bool value) async {
    backgroundPlayback.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('backgroundPlayback', value);
  }

  Future<void> updateSwipeDownToStop(bool value) async {
    swipeDownToStop.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('swipeDownToStop', value);
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
  }

  Future<void> updateWindowTransparency(bool value) async {
    enableWindowTransparency.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableWindowTransparency', value);
  }

  Future<void> updateGlobalBlur(bool value) async {
    enableGlobalBlur.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableGlobalBlur', value);
  }

  Future<void> updateThemeStyle(AppThemeStyle style) async {
    themeStyle.value = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeStyle', style.index);
  }

  Future<void> togglePinnedItem(String itemId) async {
    final current = List<String>.from(pinnedSidebarItems.value);
    if (current.contains(itemId)) {
      current.remove(itemId);
    } else {
      current.add(itemId);
    }
    pinnedSidebarItems.value = current;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinnedSidebarItems', current);
  }

  Future<void> reorderPinnedItems(int oldIndex, int newIndex) async {
    final current = List<String>.from(pinnedSidebarItems.value);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = current.removeAt(oldIndex);
    current.insert(newIndex, item);
    pinnedSidebarItems.value = current;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinnedSidebarItems', current);
  }

  Future<void> togglePinnedPlaylist(String playlistId) async {
    final current = List<String>.from(pinnedPlaylistIds.value);
    if (current.contains(playlistId)) {
      current.remove(playlistId);
    } else {
      current.add(playlistId);
    }
    pinnedPlaylistIds.value = current;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinnedPlaylistIds', current);
  }

  Future<void> reorderPinnedPlaylists(int oldIndex, int newIndex) async {
    final current = List<String>.from(pinnedPlaylistIds.value);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = current.removeAt(oldIndex);
    current.insert(newIndex, item);
    pinnedPlaylistIds.value = current;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinnedPlaylistIds', current);
  }

  Future<void> setPinnedPlaylists(List<String> ids) async {
    pinnedPlaylistIds.value = ids;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinnedPlaylistIds', ids);
  }

  Future<void> unpinPlaylist(String playlistId) async {
    final current = List<String>.from(pinnedPlaylistIds.value);
    if (current.contains(playlistId)) {
      current.remove(playlistId);
      pinnedPlaylistIds.value = current;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('pinnedPlaylistIds', current);
    }
  }

  Future<void> updateActionsSheetQuickActions(List<String> actions) async {
    actionsSheetQuickActions.value = actions;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('actionsSheetQuickActions', actions);
  }

  Future<void> updateActionsSheetListActions(List<String> actions) async {
    actionsSheetListActions.value = actions;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('actionsSheetListActions', actions);
  }

  Future<void> updateActionsSheetShowLabels(bool value) async {
    actionsSheetShowLabels.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('actionsSheetShowLabels', value);
  }

  Future<void> updatePlayerBarActions(List<String> actions) async {
    playerBarActions.value = actions;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('playerBarActions', actions);
  }

  Future<void> updateLyricsAlignment(TextAlign align) async {
    lyricsAlignment.value = align;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lyricsAlignment', align.index);
  }

  Future<void> updateLyricsActiveFontSize(double size) async {
    lyricsActiveFontSize.value = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('lyricsActiveFontSize', size);
  }

  Future<void> updateLyricsInactiveFontSize(double size) async {
    lyricsInactiveFontSize.value = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('lyricsInactiveFontSize', size);
  }

  Future<void> updatePlainLyricsFontSize(double size) async {
    plainLyricsFontSize.value = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('plainLyricsFontSize', size);
  }

  Future<void> updateShowRomanizedLyrics(bool value) async {
    showRomanizedLyrics.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showRomanizedLyrics', value);
  }

  Future<void> updateLyricsProviders(List<String> providers) async {
    lyricsProviders.value = providers;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('lyricsProviders', providers);
  }

  Future<void> updateEnabledLyricsProviders(List<String> enabled) async {
    enabledLyricsProviders.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('enabledLyricsProviders', enabled);
  }

  Future<void> toggleLyricsProvider(String providerId) async {
    final current = List<String>.from(enabledLyricsProviders.value);
    if (current.contains(providerId)) {
      current.remove(providerId);
    } else {
      current.add(providerId);
    }
    await updateEnabledLyricsProviders(current);
  }

  Future<void> updateExcludedPaths(List<String> paths) async {
    excludedPaths.value = paths;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('excludedPaths', paths);
  }

  Future<void> addExcludedPath(String path) async {
    final current = List<String>.from(excludedPaths.value);
    if (!current.contains(path)) {
      current.add(path);
      await updateExcludedPaths(current);
    }
  }

  Future<void> removeExcludedPath(String path) async {
    final current = List<String>.from(excludedPaths.value);
    if (current.contains(path)) {
      current.remove(path);
      await updateExcludedPaths(current);
    }
  }

  Future<void> updateGaplessPlayback(bool value) async {
    gaplessPlayback.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gaplessPlayback', value);
  }

  Future<void> updateAudioNormalization(bool value) async {
    audioNormalization.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audioNormalization', value);
  }

  Future<void> updateNormalizationTargetLufs(double value) async {
    normalizationTargetLufs.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('normalizationTargetLufs', value);
  }

  Future<void> updateStreamCaching(bool value) async {
    enableStreamCaching.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableStreamCaching', value);
  }

  Future<void> updatePreCaching(bool value) async {
    enablePreCaching.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enablePreCaching', value);
  }
}

final settingsSignal = SettingsSignal();
