import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/widgets/glass_snackbar.dart';

class UpNextQueue extends ConsumerWidget {
  final Function(int, int) onReorderStart;
  final Function(int) onReorderEnd;
  final ScrollController? scrollController;

  const UpNextQueue({
    super.key,
    required this.onReorderStart,
    required this.onReorderEnd,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<SequenceState?>(
      stream: audioHandler.player.sequenceStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final sequence = state?.sequence ?? [];
        final currentIndex = state?.currentIndex ?? 0;

        return Stack(
          children: [
            // ── Queue list ──────────────────────────────────────────
            Padding(
              padding: EdgeInsets.only(
                bottom: 88,
                top: 12 + MediaQuery.of(context).padding.top,
              ),
              child: sequence.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.queue_music_rounded,
                              size: 56,
                              color: cs.onSurface.withValues(alpha: 0.18)),
                          const SizedBox(height: 12),
                          Text('Queue is empty',
                              style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.38),
                                  fontSize: 15)),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      scrollController: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: sequence.length,
                      proxyDecorator: (child, index, animation) {
                        return ScaleTransition(
                          scale: animation.drive(
                            Tween(begin: 1.0, end: 1.03)
                                .chain(CurveTween(curve: Curves.easeOut)),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: Container(
                              decoration: BoxDecoration(
                                color: cs.onSurface.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: cs.onSurface.withValues(alpha: 0.15)),
                              ),
                              child: child,
                            ),
                          ),
                        );
                      },
                      itemBuilder: (context, index) {
                        final audioSource = sequence[index];
                        final mediaItem = audioSource.tag as MediaItem;
                        final isPlaying = index == currentIndex;
                        final isLazy = audioSource is UriAudioSource &&
                            audioSource.uri.scheme == 'lazy';

                        return _QueueTile(
                          key: ValueKey(mediaItem.id + index.toString()),
                          mediaItem: mediaItem,
                          index: index,
                          isPlaying: isPlaying,
                          isLazy: isLazy,
                          isDark: isDark,
                          onTap: () {
                            audioHandler.player.seek(Duration.zero, index: index);
                            audioHandler.player.play();
                          },
                          onRemove: () =>
                              audioHandler.removeQueueItem(index),
                        );
                      },
                      onReorder: (oldIndex, newIndex) {
                        audioHandler.reorderQueue(oldIndex, newIndex);
                      },
                    ),
            ),

            // ── Bottom bar ─────────────────────────────────────────
            Align(
              alignment: Alignment.bottomCenter,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    height: 88,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: isDark ? 0.85 : 0.95),
                      border: Border(
                          top: BorderSide(
                              color: cs.onSurface.withValues(alpha: 0.08))),
                    ),
                    child: Row(
                      children: [
                        // Song count pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: cs.onSurface.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.queue_music_rounded,
                                  size: 16,
                                  color: cs.onSurface.withValues(alpha: 0.6)),
                              const SizedBox(width: 6),
                              Text(
                                '${sequence.length} song${sequence.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Clear button
                        TextButton.icon(
                          onPressed: sequence.isEmpty
                              ? null
                              : () {
                                  audioHandler.clearQueue();
                                  showGlassSnackBar(
                                      context, 'Queue cleared');
                                },
                          style: TextButton.styleFrom(
                            foregroundColor: cs.onSurface,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            backgroundColor:
                                cs.onSurface.withValues(alpha: 0.07),
                          ),
                          icon: const Icon(Icons.delete_sweep_rounded,
                              size: 18),
                          label: const Text('Clear',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Individual queue tile with swipe-to-dismiss
// ─────────────────────────────────────────────────────────────
class _QueueTile extends StatelessWidget {
  final MediaItem mediaItem;
  final int index;
  final bool isPlaying;
  final bool isLazy;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _QueueTile({
    super.key,
    required this.mediaItem,
    required this.index,
    required this.isPlaying,
    required this.isLazy,
    required this.isDark,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey('dismiss_${mediaItem.id}_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.redAccent, size: 22),
      ),
      onDismissed: (_) => onRemove(),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isPlaying
                ? cs.onSurface.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPlaying
                  ? cs.onSurface.withValues(alpha: 0.2)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              // Thumbnail
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: mediaItem.artUri.toString(),
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.music_note_rounded,
                            color: cs.onSurface.withValues(alpha: 0.3),
                            size: 24),
                      ),
                    ),
                  ),
                  // Playing indicator overlay
                  if (isPlaying)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 52,
                        height: 52,
                        color: Colors.black.withValues(alpha: 0.35),
                        child: const Icon(Icons.equalizer_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // Labels
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mediaItem.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w500,
                        color: isPlaying
                            ? cs.onSurface
                            : cs.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            mediaItem.artist ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                        if (isLazy) ...[
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: cs.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (mediaItem.duration != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        _formatDuration(mediaItem.duration!),
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Drag handle
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.drag_handle_rounded,
                    color: cs.onSurface.withValues(alpha: 0.3),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
