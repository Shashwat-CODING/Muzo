import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum AudioQuality { high, medium, low }

enum ThemeType { dynamic, dark }

class SettingsState {
  final AudioQuality audioQuality;
  final bool isLiteMode;
  final ThemeType themeType;

  SettingsState({
    required this.audioQuality,
    required this.isLiteMode,
    required this.themeType,
  });

  SettingsState copyWith({
    AudioQuality? audioQuality,
    bool? isLiteMode,
    ThemeType? themeType,
  }) {
    return SettingsState(
      audioQuality: audioQuality ?? this.audioQuality,
      isLiteMode: isLiteMode ?? this.isLiteMode,
      themeType: themeType ?? this.themeType,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier()
    : super(
        SettingsState(
          audioQuality: AudioQuality.high,
          isLiteMode: false,
          themeType: ThemeType.dynamic,
        ),
      ) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final box = await Hive.openBox('settings');
    final qualityIndex = box.get('audioQuality', defaultValue: 0);
    final isLiteMode = box.get('isLiteMode', defaultValue: false);
    final themeTypeIndex = box.get('themeModeType', defaultValue: 0);

    // Migration logic: If saved index is out of bounds (legacy light/system), default to dynamic (0)
    final validThemeIndex =
        (themeTypeIndex >= 0 && themeTypeIndex < ThemeType.values.length)
        ? themeTypeIndex
        : 0;

    state = SettingsState(
      audioQuality: AudioQuality.values[qualityIndex],
      isLiteMode: isLiteMode,
      themeType: ThemeType.values[validThemeIndex],
    );
  }

  Future<void> setAudioQuality(AudioQuality quality) async {
    state = state.copyWith(audioQuality: quality);
    final box = await Hive.openBox('settings');
    await box.put('audioQuality', quality.index);
  }

  Future<void> setLiteMode(bool isLiteMode) async {
    state = state.copyWith(isLiteMode: isLiteMode);
    final box = await Hive.openBox('settings');
    await box.put('isLiteMode', isLiteMode);
  }

  Future<void> setThemeType(ThemeType themeType) async {
    state = state.copyWith(themeType: themeType);
    final box = await Hive.openBox('settings');
    await box.put('themeModeType', themeType.index);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    return SettingsNotifier();
  },
);
