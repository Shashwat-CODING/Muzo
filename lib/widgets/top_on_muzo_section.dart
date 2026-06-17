import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/providers/explore_provider.dart';
import 'package:muzo/widgets/song_options_menu.dart';
import 'package:muzo/widgets/skeleton_loader.dart';

class TopOnMuzoSection extends ConsumerWidget {
  const TopOnMuzoSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topOnMuzoAsync = ref.watch(topOnMuzoProvider);

    return topOnMuzoAsync.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        final topItems = items.take(10).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: topItems.length,
                itemBuilder: (context, index) {
                  final item = topItems[index];
                  final imageUrl = item.thumbnails.isNotEmpty
                      ? item.thumbnails.last.url
                      : null;
                  return Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: _buildMusicCard(
                      context: context,
                      title: item.title,
                      imageUrl: imageUrl,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(audioHandlerProvider).playVideo(item);
                      },
                      onLongPress: () {
                        HapticFeedback.lightImpact();
                        SongOptionsMenu.show(ref, item);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const TopMuzoSkeleton(),
        ],
      ),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
      child: Row(
        children: [
          Icon(
            FluentIcons.arrow_trending_24_regular,
            color: Theme.of(context).colorScheme.primary,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            'Top on Muzo',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  letterSpacing: -0.3,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMusicCard({
    required BuildContext context,
    required String title,
    required String? imageUrl,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    const double cardWidth = 152;
    const double borderRadius = 8.0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _placeholder(context),
                        )
                      : _placeholder(context),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        FluentIcons.music_note_2_24_filled,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 32,
      ),
    );
  }
}

class TopMuzoSkeleton extends StatelessWidget {
  const TopMuzoSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 4,
        itemBuilder: (context, index) {
          return const Padding(
            padding: EdgeInsets.only(right: 14),
            child: SizedBox(
              width: 152,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 152, height: 152, borderRadius: 8),
                  SizedBox(height: 8),
                  SkeletonLoader(width: 110, height: 14, borderRadius: 3),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
