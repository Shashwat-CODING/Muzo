import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum AudioQuality { high, medium, low }

class SettingsState {
  final AudioQuality audioQuality;
  final bool isLiteMode;

  SettingsState({
    required this.audioQuality,
    required this.isLiteMode,
  });

  SettingsState copyWith({
    AudioQuality? audioQuality,
    bool? isLiteMode,
  }) {
    return SettingsState(
      audioQuality: audioQuality ?? this.audioQuality,
      isLiteMode: isLiteMode ?? this.isLiteMode,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState(audioQuality: AudioQuality.high, isLiteMode: false)) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final box = await Hive.openBox('settings');
    final qualityIndex = box.get('audioQuality', defaultValue: 0);
    final isLiteMode = box.get('isLiteMode', defaultValue: false);
    
    state = SettingsState(
      audioQuality: AudioQuality.values[qualityIndex],
      isLiteMode: isLiteMode,
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
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
