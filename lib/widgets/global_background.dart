import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/providers/settings_provider.dart';

class GlobalBackground extends ConsumerWidget {
  final Widget child;

  const GlobalBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItemAsync = ref.watch(currentMediaItemProvider);
    final isLiteMode = ref.watch(settingsProvider).isLiteMode;

    if (isLiteMode) {
      return Stack(
        children: [
          Container(color: const Color(0xFF0F0F0F)),
          child,
        ],
      );
    }

    return Stack(
      children: [
        // Background Image
        mediaItemAsync.when(
          data: (mediaItem) {
            if (mediaItem == null) return Container(color: const Color(0xFF0F0F0F));
            final artworkUrl = mediaItem.artUri.toString();
            
            return Positioned.fill(
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: artworkUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorWidget: (context, url, error) => Container(color: const Color(0xFF0F0F0F)),
                  ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.5),
                              Colors.black.withValues(alpha: 0.9),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => Container(color: const Color(0xFF0F0F0F)),
          error: (_, __) => Container(color: const Color(0xFF0F0F0F)),
        ),

        // Content
        child,
      ],
    );
  }
}
