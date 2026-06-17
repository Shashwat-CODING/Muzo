import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum AudioQuality { high, medium, low }

enum ThemeType { auto, dark, light }

class SettingsState {
  final AudioQuality audioQuality;
  final ThemeType themeType;
  final bool isGestureMode;
  final String appFontFamily;
  final bool isAmoled;

  SettingsState({
    required this.audioQuality,
    required this.themeType,
    this.isGestureMode = false,
    this.appFontFamily = 'AR One Sans',
    this.isAmoled = false,
  });

  SettingsState copyWith({
    AudioQuality? audioQuality,
    ThemeType? themeType,
    bool? isGestureMode,
    String? appFontFamily,
    bool? isAmoled,
  }) {
    return SettingsState(
      audioQuality: audioQuality ?? this.audioQuality,
      themeType: themeType ?? this.themeType,
      isGestureMode: isGestureMode ?? this.isGestureMode,
      appFontFamily: appFontFamily ?? this.appFontFamily,
      isAmoled: isAmoled ?? this.isAmoled,
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
          appFontFamily: 'AR One Sans',
          isAmoled: false,
        ),
      ) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final box = await Hive.openBox('settings');
    final qualityIndex = box.get('audioQuality', defaultValue: 0);
    final themeTypeIndex = box.get('themeType', defaultValue: 0);
    final isGestureMode = box.get('isGestureMode', defaultValue: false) ?? false;
    final appFontFamily = box.get('appFontFamily', defaultValue: 'AR One Sans');
    final isAmoled = box.get('isAmoled', defaultValue: false) ?? false;

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
      isAmoled: isAmoled,
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
    await box.put('themeType', themeType.index);
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

  Future<void> setAmoled(bool enabled) async {
    state = state.copyWith(isAmoled: enabled);
    final box = await Hive.openBox('settings');
    await box.put('isAmoled', enabled);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    return SettingsNotifier();
  },
);
