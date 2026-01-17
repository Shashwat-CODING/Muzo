import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:widget_marquee/widget_marquee.dart';
import 'package:just_audio/just_audio.dart';

import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/models/ytify_result.dart';
import 'package:muzo/widgets/glass_snackbar.dart';

class PlayerControlWidget extends ConsumerWidget {
  const PlayerControlWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItemAsync = ref.watch(currentMediaItemProvider);
    final audioHandler = ref.watch(audioHandlerProvider);
    final player = audioHandler.player;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Title and Artist
        mediaItemAsync.when(
          data: (mediaItem) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Marquee(
                      delay: const Duration(milliseconds: 300),
                      duration: const Duration(seconds: 10),
                      child: Text(
                        mediaItem?.title ?? "NA",
                        textAlign: TextAlign.start,
                        style: Theme.of(context).textTheme.titleMedium!
                            .copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Marquee(
                      delay: const Duration(milliseconds: 300),
                      duration: const Duration(seconds: 10),
                      child: Text(
                        mediaItem?.artist ?? "NA",
                        textAlign: TextAlign.start,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall!.copyWith(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
              // Favorite Button
              Consumer(
                builder: (context, ref, child) {
                  final storage = ref.watch(storageServiceProvider);
                  if (mediaItem == null) return const SizedBox.shrink();
                  return ValueListenableBuilder(
                    valueListenable: storage.favoritesListenable,
                    builder: (context, favorites, _) {
                      final isFav = storage.isFavorite(mediaItem.id);
                      return IconButton(
                        icon: Icon(
                          isFav
                              ? FluentIcons.heart_24_filled
                              : FluentIcons.heart_24_regular,
                          color: isFav ? Colors.red : Colors.white,
                        ),
                        onPressed: () {
                          // Reconstruct YtifyResult
                          final result = YtifyResult(
                            videoId: mediaItem.id,
                            title: mediaItem.title,
                            thumbnails: [
                              YtifyThumbnail(
                                url: mediaItem.artUri.toString(),
                                width: 0,
                                height: 0,
                              ),
                            ],
                            artists: [
                              YtifyArtist(name: mediaItem.artist ?? '', id: ''),
                            ],
                            resultType:
                                mediaItem.extras?['resultType'] ?? 'video',
                            isExplicit: false,
                          );

                          storage.toggleFavorite(result);

                          if (context.mounted) {
                            showGlassSnackBar(
                              context,
                              isFav
                                  ? 'Removed from favorites'
                                  : 'Added to favorites',
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 20),

        // Progress Bar
        StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            final duration = player.duration ?? Duration.zero;

            return Consumer(
              builder: (context, ref, child) {
                final thumbColor = Colors.white;
                final progressBarColor = Colors.white;
                final baseBarColor = Colors.white.withOpacity(0.24);
                final bufferedBarColor = Colors.white.withOpacity(0.38);

                return ProgressBar(
                  thumbRadius: 7,
                  barHeight: 4.5,
                  baseBarColor: baseBarColor,
                  bufferedBarColor: bufferedBarColor,
                  progressBarColor: progressBarColor,
                  thumbColor: thumbColor,
                  timeLabelTextStyle: Theme.of(
                    context,
                  ).textTheme.bodySmall!.copyWith(color: Colors.white),
                  progress: position,
                  total: duration,
                  onSeek: (duration) {
                    player.seek(duration);
                  },
                );
              },
            );
          },
        ),

        // Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Shuffle
            StreamBuilder<bool>(
              stream: player.shuffleModeEnabledStream,
              builder: (context, snapshot) {
                final shuffleEnabled = snapshot.data ?? false;
                return IconButton(
                  onPressed: () async {
                    await player.setShuffleModeEnabled(!shuffleEnabled);
                  },
                  icon: Icon(
                    FluentIcons.arrow_shuffle_24_regular,
                    color: shuffleEnabled ? Colors.white : Colors.white38,
                  ),
                );
              },
            ),

            // Previous
            IconButton(
              icon: const Icon(
                FluentIcons.previous_24_filled,
                color: Colors.white,
                size: 30,
              ),
              onPressed: () => audioHandler.skipToPrevious(),
            ),

            // Play/Pause
            StreamBuilder<bool>(
              stream: player.playingStream,
              builder: (context, snapshot) {
                final playing = snapshot.data ?? false;
                return CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: Icon(
                      playing
                          ? FluentIcons.pause_24_filled
                          : FluentIcons.play_24_filled,
                      color: Colors.black,
                      size: 35,
                    ),
                    onPressed: () {
                      if (playing) {
                        player.pause();
                      } else {
                        player.play();
                      }
                    },
                  ),
                );
              },
            ),

            // Next
            IconButton(
              icon: const Icon(
                FluentIcons.next_24_filled,
                color: Colors.white,
                size: 30,
              ),
              onPressed: () => audioHandler.skipToNext(),
            ),

            // Loop
            StreamBuilder<LoopMode>(
              stream: player.loopModeStream,
              builder: (context, snapshot) {
                final loopMode = snapshot.data ?? LoopMode.off;
                return IconButton(
                  onPressed: () async {
                    if (loopMode == LoopMode.off) {
                      await player.setLoopMode(LoopMode.all);
                    } else if (loopMode == LoopMode.all) {
                      await player.setLoopMode(LoopMode.one);
                    } else {
                      await player.setLoopMode(LoopMode.off);
                    }
                  },
                  icon: Icon(
                    loopMode == LoopMode.one
                        ? FluentIcons.arrow_repeat_1_24_regular
                        : FluentIcons.arrow_repeat_all_24_regular,
                    color: loopMode != LoopMode.off
                        ? Colors.white
                        : Colors.white38,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
