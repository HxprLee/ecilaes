import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals_flutter.dart';

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
}

final settingsSignal = SettingsSignal();
