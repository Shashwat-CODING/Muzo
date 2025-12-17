import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:muzo/services/audio_handler.dart';

import 'package:muzo/services/storage_service.dart';

final audioHandlerProvider = Provider<AudioHandler>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return AudioHandler(storage);
});

final currentMediaItemProvider = StreamProvider<MediaItem?>((ref) {
  final audioHandler = ref.watch(audioHandlerProvider);
  return audioHandler.player.sequenceStateStream.map(
    (state) => state?.currentSource?.tag as MediaItem?,
  );
});

final isPlayingProvider = StreamProvider<bool>((ref) {
  final audioHandler = ref.watch(audioHandlerProvider);
  return audioHandler.player.playingStream;
});

final processingStateProvider = StreamProvider<ProcessingState>((ref) {
  final audioHandler = ref.watch(audioHandlerProvider);
  return audioHandler.player.processingStateStream;
});

final positionProvider = StreamProvider<Duration>((ref) {
  final audioHandler = ref.watch(audioHandlerProvider);
  return audioHandler.player.positionStream;
});

final durationProvider = StreamProvider<Duration?>((ref) {
  final audioHandler = ref.watch(audioHandlerProvider);
  return audioHandler.player.durationStream;
});

final isPlayerExpandedProvider = StateProvider<bool>((ref) => false);

final lofiModeNotifierProvider = Provider<ValueNotifier<bool>>((ref) {
  return ref.watch(audioHandlerProvider).isLofiModeNotifier;
});
