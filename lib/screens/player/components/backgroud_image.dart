import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/providers/player_provider.dart';

class BackgroudImage extends ConsumerWidget {
  final double? cacheHeight;
  const BackgroudImage({super.key, this.cacheHeight});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItemAsync = ref.watch(currentMediaItemProvider);
    return mediaItemAsync.when(
      data: (mediaItem) {
        if (mediaItem?.artUri == null) return const SizedBox.shrink();
        return SizedBox.expand(
          child: CachedNetworkImage(
            imageUrl: mediaItem!.artUri.toString(),
            fit: BoxFit.cover,
            errorWidget: (context, url, error) =>
                Container(color: Colors.black),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
