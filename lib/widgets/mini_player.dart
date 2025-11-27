import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytx/providers/player_provider.dart';
import 'package:ytx/screens/player_screen.dart';
import 'package:ytx/services/navigator_key.dart';
import 'package:ytx/services/storage_service.dart';
import 'package:ytx/models/ytify_result.dart';

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
          onTap: () async {
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
          child: Container(
            height: 60, // Decreased height from 70
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), // Increased blur
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF272727).withValues(alpha: 0.5), // Match Navbar opacity
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: CachedNetworkImage(
                          imageUrl: mediaItem.artUri.toString(),
                          height: 46,
                          fit: BoxFit.fitHeight,
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[800],
                            child: const Icon(Icons.music_note, color: Colors.white),
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
                                fontSize: 13, // Slightly smaller font
                              ),
                            ),
                            Text(
                              mediaItem.artist ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11, // Slightly smaller font
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
                          return ValueListenableBuilder(
                            valueListenable: storage.favoritesListenable,
                            builder: (context, box, _) {
                              final isFav = storage.isFavorite(mediaItem.id);
                              return IconButton(
                                icon: Icon(
                                  isFav ? Icons.favorite : Icons.favorite_border,
                                  color: isFav ? Colors.red : Colors.white,
                                  size: 24,
                                ),
                                onPressed: () {
                                  // We need to reconstruct YtifyResult from MediaItem
                                  // This is a bit hacky but works for now since we store minimal info
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
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28, // Slightly smaller icon
                          ),
                          onPressed: () {
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
                        error: (_, __) => const Icon(Icons.error, size: 24),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
