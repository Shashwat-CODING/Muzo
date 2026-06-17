import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:widget_marquee/widget_marquee.dart';
import 'package:just_audio/just_audio.dart';
import 'up_next_queue.dart';

import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/widgets/glass_snackbar.dart';

class PlayerControlWidget extends ConsumerWidget {
  const PlayerControlWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItemAsync = ref.watch(currentMediaItemProvider);
    final audioHandler = ref.watch(audioHandlerProvider);
    final player = audioHandler.player;

    return SingleChildScrollView(
      child: Column(
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
                    SizedBox(
                      height: 30, // fixed height for marquee to stay stable
                      child: Marquee(
                        delay: const Duration(milliseconds: 300),
                        duration: const Duration(seconds: 10),
                        child: Text(
                          mediaItem?.title ?? "NA",
                          textAlign: TextAlign.start,
                          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
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
                        ).textTheme.bodyMedium!.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Queue Button
              IconButton(
                icon: Icon(
                  FluentIcons.list_24_regular,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (context) {
                      return DraggableScrollableSheet(
                        initialChildSize: 0.6,
                        minChildSize: 0.3,
                        maxChildSize: 0.9,
                        builder: (context, scrollController) {
                          return ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                              child: Container(
                              decoration: BoxDecoration(
                                  color: (Theme.of(context).brightness == Brightness.dark
                                      ? Colors.black
                                      : Colors.white).withValues(alpha: 0.85),
                                  border: Border(
                                    top: BorderSide(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                                      width: 1.0,
                                    ),
                                  ),
                                ),
                                child: UpNextQueue(
                                  scrollController: scrollController,
                                  onReorderStart: (oldIndex, newIndex) {
                                    // Reorder logic if needed
                                  },
                                  onReorderEnd: (index) {},
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
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
                          color: isFav ? Colors.red : Theme.of(context).colorScheme.onSurface,
                        ),
                        onPressed: () {
                          // Reconstruct MuzoItem
                          final result = MuzoItem(
                            videoId: mediaItem.id,
                            title: mediaItem.title,
                            thumbnails: [
                              MuzoThumbnail(
                                url: mediaItem.artUri.toString(),
                                width: 0,
                                height: 0,
                              ),
                            ],
                            artists: [
                              MuzoArtist(name: mediaItem.artist ?? '', id: ''),
                            ],
                            resultType: mediaItem.extras?['resultType'] ?? 'video',
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

        const SizedBox(height: 24),

        // Progress Bar
        RepaintBoundary(
          child: StreamBuilder<Duration>(
            stream: player.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = mediaItemAsync.value?.duration ?? player.duration ?? Duration.zero;
              
              final progressBarColor = Theme.of(context).colorScheme.onSurface;
              final baseBarColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2);
              final bufferedBarColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35);

              return ProgressBar(
                thumbRadius: 0,
                thumbGlowRadius: 0,
                barHeight: 8,
                baseBarColor: baseBarColor,
                bufferedBarColor: bufferedBarColor,
                progressBarColor: progressBarColor,
                thumbColor: Colors.transparent,
                timeLabelPadding: 10,
                timeLabelTextStyle: Theme.of(context)
                    .textTheme
                    .labelMedium!
                    .copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                progress: position,
                total: duration,
                onSeek: (duration) {
                  player.seek(duration);
                },
              );
            },
          ),
        ),

        const SizedBox(height: 24),

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
                    color: shuffleEnabled
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                );
              },
            ),

            // Previous
            IconButton(
              icon: Icon(
                CupertinoIcons.backward_fill,
                color: Theme.of(context).colorScheme.onSurface,
                size: 28,
              ),
              onPressed: () => audioHandler.skipToPrevious(),
            ),

            // Play/Pause
            StreamBuilder<PlayerState>(
              stream: player.playerStateStream,
              builder: (context, snapshot) {
                final playerState = snapshot.data;
                final processingState = playerState?.processingState;
                final playing = playerState?.playing ?? false;
                final isLoading = processingState == ProcessingState.loading || processingState == ProcessingState.buffering;

                return CircleAvatar(
                  radius: 35,
                  backgroundColor: Theme.of(context).colorScheme.onSurface,
                  child: isLoading 
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Theme.of(context).colorScheme.surface,
                          ),
                        )
                      : IconButton(
                    icon: Icon(
                      playing
                          ? FluentIcons.pause_24_filled
                          : FluentIcons.play_24_filled,
                      color: Theme.of(context).colorScheme.surface,
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
              icon: Icon(
                CupertinoIcons.forward_fill,
                color: Theme.of(context).colorScheme.onSurface,
                size: 28,
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
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                );
              },
            ),
              ],
            ), // end Row
          ], // end Column children
        ), // end Column
      ); // end SingleChildScrollView
  }
}
