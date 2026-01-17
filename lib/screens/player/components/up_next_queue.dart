import 'dart:ui';
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
    final playlist = audioHandler.playlist;

    return StreamBuilder<SequenceState?>(
      stream: audioHandler.player.sequenceStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final sequence = state?.sequence ?? [];
        final currentIndex = state?.currentIndex;

        return Stack(
          children: [
            // Queue List
            Padding(
              // Add padding for bottom stats bar and top status bar
              padding: EdgeInsets.only(
                bottom: 80,
                top: 20 + MediaQuery.of(context).padding.top,
              ),
              child: ReorderableListView.builder(
                scrollController: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: sequence.length,
                proxyDecorator: (child, index, animation) {
                  return Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: child,
                    ),
                  );
                },
                itemBuilder: (context, index) {
                  final audioSource = sequence[index];
                  final mediaItem = audioSource.tag as MediaItem;
                  final isPlaying = index == currentIndex;

                  return ListTile(
                    key: ValueKey(
                      mediaItem.id + index.toString(),
                    ), // Unique key
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Image.network(
                        mediaItem.artUri.toString(),
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey,
                          width: 50,
                          height: 50,
                        ),
                      ),
                    ),
                    title: Text(
                      mediaItem.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isPlaying
                            ? Theme.of(context).primaryColor
                            : Colors.white,
                        fontWeight: isPlaying
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      mediaItem.artist ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(
                        Icons.drag_handle,
                        color: Colors.white54,
                      ),
                    ),
                    onTap: () {
                      // Play this item
                      audioHandler.player.seek(Duration.zero, index: index);
                    },
                  );
                },
                onReorder: (oldIndex, newIndex) {
                  audioHandler.reorderQueue(oldIndex, newIndex);
                },
              ),
            ),

            // Bottom Controls Bar (Blur, count, clear)
            Align(
              alignment: Alignment.bottomCenter,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.only(
                      top: 15,
                      bottom: 20,
                      left: 10,
                      right: 10,
                    ),
                    decoration: BoxDecoration(
                      boxShadow: const [
                        BoxShadow(blurRadius: 5, color: Colors.black54),
                      ],
                      color: Theme.of(context).primaryColor.withOpacity(0.5),
                    ),
                    height: 100, // Adjusted height
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Song Count
                          Text(
                            "${sequence.length} songs",
                            style: Theme.of(context).textTheme.titleSmall!
                                .copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),

                          // Clear Queue Button
                          InkWell(
                            onTap: () {
                              if (sequence.isEmpty) return;
                              audioHandler.clearQueue();
                              showGlassSnackBar(context, "Queue cleared");
                            },
                            child: Container(
                              height: 35,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.delete_sweep,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
