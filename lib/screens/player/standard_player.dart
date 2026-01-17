import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'components/albumart_lyrics.dart';
import 'components/player_control.dart';
import '../../widgets/song_options_menu.dart';
import 'package:muzo/models/ytify_result.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/providers/settings_provider.dart';

class StandardPlayer extends ConsumerWidget {
  const StandardPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final mediaItemAsync = ref.watch(currentMediaItemProvider);
    final isLiteMode = ref.watch(settingsProvider).isLiteMode;

    double playerArtImageSize = size.width - 100;
    final spaceAvailableForArtImage =
        size.height - (70 + MediaQuery.of(context).padding.bottom + 330);
    playerArtImageSize = playerArtImageSize > spaceAvailableForArtImage
        ? spaceAvailableForArtImage
        : playerArtImageSize;

    // Dynamic Background with Blurred Image
    final mediaItem = mediaItemAsync.value;
    final artUri = mediaItem?.artUri;

    return Stack(
      children: [
        Stack(
          children: [
            if (artUri != null)
              SizedBox.expand(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.4),
                      BlendMode.darken,
                    ),
                    child: CachedNetworkImage(
                      imageUrl: artUri.toString(),
                      fit: BoxFit.cover,
                      height: MediaQuery.of(context).size.height,
                      placeholder: (context, url) =>
                          Container(color: Colors.black),
                      errorWidget: (context, url, error) =>
                          Container(color: Colors.black),
                    ),
                  ),
                ),
              ),

            // Gradient Overlay for readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Player Content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape = size.width > size.height && size.width > 800;

              if (isLandscape) {
                // Landscape Layout (Row)
                // Recalculate art size for landscape
                // Available height is full height minus some padding
                // Available width is half width
                double landscapeArtSize = size.height - 180;
                if (landscapeArtSize > size.width / 2 - 50) {
                  landscapeArtSize = size.width / 2 - 50;
                }

                return Row(
                  children: [
                    // Left Side: Album Art & Lyrics
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: MediaQuery.of(context).padding.top + 20),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: AlbumArtNLyrics(
                              playerArtImageSize: landscapeArtSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    // Right Side: Controls
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + 60,
                          bottom: 100 + MediaQuery.of(context).padding.bottom,
                        ),
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 500),
                            child: const PlayerControlWidget(),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                // Portrait Layout (Column)
                return Column(
                  children: [
                    SizedBox(height: size.height < 750 ? 110 : 140),

                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 500),
                          child: AlbumArtNLyrics(
                            playerArtImageSize: playerArtImageSize,
                          ),
                        ),
                      ],
                    ),

                    Expanded(child: Container()),

                    Padding(
                      padding: EdgeInsets.only(
                        bottom: 120 + MediaQuery.of(context).padding.bottom,
                      ),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: const PlayerControlWidget(),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ),

        // Header (Minimize, Album info, options)
        Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 20,
            left: 10,
            right: 10,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  size: 28,
                  color: Colors.white,
                ),
                onPressed: () {
                  // Logic to close player
                  ref.read(isPlayerExpandedProvider.notifier).state = false;
                  Navigator.of(context).pop();
                },
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 5, right: 5),
                  child: Column(
                    children: [
                      const Text(
                        "PLAYING FROM",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                      mediaItemAsync.when(
                        data: (item) => Text(
                          "\"${item?.album ?? 'Unknown'}\"",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        loading: () => const Text(
                          "Loading...",
                          style: TextStyle(color: Colors.white),
                        ),
                        error: (_, __) => const Text(
                          "Error",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              IconButton(
                icon: const Icon(
                  Icons.more_vert,
                  size: 25,
                  color: Colors.white,
                ),
                onPressed: () {
                  mediaItemAsync.whenData((mediaItem) {
                    if (mediaItem == null) return;
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
                      resultType: mediaItem.extras?['resultType'] ?? 'video',
                      isExplicit: false,
                    );
                    SongOptionsMenu.show(ref, result, fromPlayer: true);
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
