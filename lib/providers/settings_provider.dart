import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum AudioQuality { high, medium, low }

enum ThemeType { auto, dark, light }

class SettingsState {
  final AudioQuality audioQuality;
  final ThemeType themeType;
  final bool isGestureMode;
  final String appFontFamily;

  SettingsState({
    required this.audioQuality,
    required this.themeType,
    this.isGestureMode = false,
    this.appFontFamily = 'Archivo Black',
  });

  SettingsState copyWith({
    AudioQuality? audioQuality,
    ThemeType? themeType,
    bool? isGestureMode,
    String? appFontFamily,
  }) {
    return SettingsState(
      audioQuality: audioQuality ?? this.audioQuality,
      themeType: themeType ?? this.themeType,
      isGestureMode: isGestureMode ?? this.isGestureMode,
      appFontFamily: appFontFamily ?? this.appFontFamily,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier()
    : super(
        SettingsState(
          audioQuality: AudioQuality.high,
          themeType: ThemeType.auto,
          isGestureMode: false,
          appFontFamily: 'Archivo Black',
        ),
      ) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final box = await Hive.openBox('settings');
    final qualityIndex = box.get('audioQuality', defaultValue: 0);
    final themeTypeIndex = box.get('themeType', defaultValue: 0);
    final isGestureMode = box.get('isGestureMode', defaultValue: false) ?? false;
    final appFontFamily = box.get('appFontFamily', defaultValue: 'Archivo Black');

    // Migration logic: If saved index is out of bounds, default to auto (0)
    final validThemeIndex =
        (themeTypeIndex >= 0 && themeTypeIndex < ThemeType.values.length)
        ? themeTypeIndex
        : 0; // Default to auto

    state = SettingsState(
      audioQuality: AudioQuality.values[qualityIndex],
      themeType: ThemeType.values[validThemeIndex],
      isGestureMode: isGestureMode,
      appFontFamily: appFontFamily,
    );
  }

  Future<void> setAudioQuality(AudioQuality quality) async {
    state = state.copyWith(audioQuality: quality);
    final box = await Hive.openBox('settings');
    await box.put('audioQuality', quality.index);
  }

  Future<void> setThemeType(ThemeType themeType) async {
    state = state.copyWith(themeType: themeType);
    final box = await Hive.openBox('settings');
    await box.put('themeModeType', themeType.index);
  }

  Future<void> toggleGestureMode() async {
    final newValue = !state.isGestureMode;
    state = state.copyWith(isGestureMode: newValue);
    final box = await Hive.openBox('settings');
    await box.put('isGestureMode', newValue);
  }

  Future<void> setAppFontFamily(String font) async {
    state = state.copyWith(appFontFamily: font);
    final box = await Hive.openBox('settings');
    await box.put('appFontFamily', font);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    return SettingsNotifier();
  },
);
