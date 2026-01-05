import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/screens/player_screen.dart';
import 'package:muzo/services/navigator_key.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/models/ytify_result.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItemAsync = ref.watch(currentMediaItemProvider);
    final isPlayingAsync = ref.watch(isPlayingProvider);
    final audioHandler = ref.watch(audioHandlerProvider);

    return mediaItemAsync.when(
      data: (mediaItem) {
        if (mediaItem == null) return const SizedBox.shrink();

        final resultType = mediaItem.extras?['resultType'] ?? 'video';
        final isSong = resultType == 'song';

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            HapticFeedback.lightImpact();
            if (navigatorKey.currentContext != null) {
              ref.read(isPlayerExpandedProvider.notifier).state = true;
              await Navigator.of(navigatorKey.currentContext!).push(
                MaterialPageRoute(
                  builder: (context) => const ExpandedPlayer(),
                  fullscreenDialog: true,
                ),
              );
              ref.read(isPlayerExpandedProvider.notifier).state = false;
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: mediaItem.artUri.toString(),
                        height: 48, 
                        width: 48,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[800],
                          child: const Icon(FluentIcons.music_note_2_24_regular, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            mediaItem.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            mediaItem.artist ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Favorite Button
                    Consumer(
                      builder: (context, ref, child) {
                        final storage = ref.watch(storageServiceProvider);
                        return ValueListenableBuilder<List<YtifyResult>>(
                          valueListenable: storage.favoritesListenable,
                          builder: (context, favorites, _) {
                            final isFav = storage.isFavorite(mediaItem.id);
                            return IconButton(
                              icon: Icon(
                                isFav ? FluentIcons.heart_24_filled : FluentIcons.heart_24_regular,
                                color: isFav ? Colors.red : Colors.white,
                                size: 24,
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                final result = YtifyResult(
                                  videoId: mediaItem.id,
                                  title: mediaItem.title,
                                  thumbnails: [YtifyThumbnail(url: mediaItem.artUri.toString(), width: 0, height: 0)],
                                  artists: [YtifyArtist(name: mediaItem.artist ?? '', id: '')], 
                                  resultType: isSong ? 'song' : 'video',
                                  isExplicit: false,
                                );
                                storage.toggleFavorite(result);
                              },
                            );
                          },
                        );
                      },
                    ),
                    isPlayingAsync.when(
                      data: (isPlaying) => IconButton(
                        icon: Icon(
                          isPlaying ? FluentIcons.pause_24_filled : FluentIcons.play_24_filled,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          if (isPlaying) {
                            audioHandler.pause();
                          } else {
                            audioHandler.resume();
                          }
                        },
                      ),
                      loading: () => const SizedBox(
                        width: 24, 
                        height: 24, 
                        child: CircularProgressIndicator(strokeWidth: 2)
                      ),
                      error: (_, __) => const Icon(FluentIcons.error_circle_24_regular, size: 24),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              StreamBuilder<Duration>(
                stream: audioHandler.player.positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final duration = mediaItem.duration ?? audioHandler.player.duration ?? Duration.zero;
                  double value = 0.0;
                  if (duration.inMilliseconds > 0) {
                    value = (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
                  }
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      widthFactor: 0.96,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(1.5),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 3, // Slightly thicker for visibility if shorter
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.9)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
