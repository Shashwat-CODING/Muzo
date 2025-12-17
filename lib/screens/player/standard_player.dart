import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'components/albumart_lyrics.dart';
import 'components/backgroud_image.dart';
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

    double playerArtImageSize = size.width - 60;
    final spaceAvailableForArtImage = size.height - (70 + MediaQuery.of(context).padding.bottom + 330);
    playerArtImageSize = playerArtImageSize > spaceAvailableForArtImage
        ? spaceAvailableForArtImage
        : playerArtImageSize;

    return Stack(
      children: [
        // Background Image
        const BackgroudImage(cacheHeight: 200),

        // Blur Effect
        if (!isLiteMode)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 65 + MediaQuery.of(context).padding.bottom + 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black,
                          Colors.black,
                          Colors.black.withValues(alpha: 0.4),
                          Colors.black.withValues(alpha: 0),
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        stops: const [0, 0.5, 0.8, 1],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.9), // Darker overlay for lite mode
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 65 + MediaQuery.of(context).padding.bottom + 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black,
                        Colors.black,
                        Colors.black.withValues(alpha: 0.4),
                        Colors.black.withValues(alpha: 0),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: const [0, 0.5, 0.8, 1],
                    ),
                  ),
                ),
              ),
            ],
          ),

        // Player Content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            children: [
              SizedBox(height: size.height < 750 ? 110 : 140),
              
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: AlbumArtNLyrics(playerArtImageSize: playerArtImageSize),
                  ),
                ],
              ),

              Expanded(child: Container()),

              Padding(
                padding: EdgeInsets.only(bottom: 80 + MediaQuery.of(context).padding.bottom),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: const PlayerControlWidget(),
                ),
              )
            ],
          ),
        ),

        // Header (Minimize, Album info, options)
        Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20, left: 10, right: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, size: 28, color: Colors.white),
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
                      const Text("PLAYING FROM",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                       mediaItemAsync.when(
                        data: (item) => Text(
                          "\"${item?.album ?? 'Unknown'}\"",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        loading: () => const Text("Loading...", style: TextStyle(color: Colors.white)),
                        error: (_,__) => const Text("Error", style: TextStyle(color: Colors.white)),
                       )
                    ],
                  ),
                ),
              ),

              IconButton(
                icon: const Icon(Icons.more_vert, size: 25, color: Colors.white),
                onPressed: () {
                   mediaItemAsync.whenData((mediaItem) {
                      if (mediaItem == null) return;
                      // Reconstruct YtifyResult
                      final result = YtifyResult(
                        videoId: mediaItem.id,
                        title: mediaItem.title,
                        thumbnails: [YtifyThumbnail(url: mediaItem.artUri.toString(), width: 0, height: 0)],
                        artists: [YtifyArtist(name: mediaItem.artist ?? '', id: '')],
                        resultType: mediaItem.extras?['resultType'] ?? 'video',
                        isExplicit: false,
                      );
                      SongOptionsMenu.show(context, result);
                   });
                },
              ),
            ],
          ),
        )
      ],
    );
  }
}
