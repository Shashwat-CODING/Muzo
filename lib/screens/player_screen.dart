import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:ytx/providers/player_provider.dart';
import 'package:ytx/services/storage_service.dart';
import 'package:ytx/models/ytify_result.dart';
import 'package:ytx/services/download_service.dart';
import 'package:ytx/providers/download_provider.dart';
import 'package:ytx/widgets/app_alert_dialog.dart';
import 'package:ytx/widgets/glass_snackbar.dart';
import 'package:ytx/widgets/playlist_selection_dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:ytx/screens/artist_screen.dart';

class ExpandedPlayer extends ConsumerStatefulWidget {
  const ExpandedPlayer({super.key});

  @override
  ConsumerState<ExpandedPlayer> createState() => _ExpandedPlayerState();
}

class _ExpandedPlayerState extends ConsumerState<ExpandedPlayer> {
  bool _showQueue = false;

  @override
  Widget build(BuildContext context) {
    final mediaItemAsync = ref.watch(currentMediaItemProvider);
    final isPlayingAsync = ref.watch(isPlayingProvider);
    final audioHandler = ref.watch(audioHandlerProvider);

    // Calculate margins to keep player between header and nav bar
    final double topMargin = MediaQuery.of(context).padding.top + 16.0;
    final double bottomMargin = 100.0 + MediaQuery.of(context).padding.bottom;
    const double sideMargin = 16.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: mediaItemAsync.when(
        data: (mediaItem) {
          if (mediaItem == null) return const SizedBox.shrink();

          final resultType = mediaItem.extras?['resultType'] ?? 'video';
          final isSong = resultType == 'song';
          final artworkUrl = mediaItem.artUri.toString();

          return Stack(
            children: [
              // Transparent Background (Click to close)
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  color: Colors.transparent,
                ),
              ),

              // Floating Card
              Dismissible(
                key: const Key('player_dismiss'),
                direction: DismissDirection.down,
                onDismissed: (_) => Navigator.of(context).pop(),
                child: Container(
                  color: const Color(0xFF1E1E1E),
                  child: Stack(
                    children: [
                        // Background Image with Blur
                        Positioned.fill(
                          child: CachedNetworkImage(
                            imageUrl: artworkUrl,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(color: Colors.black),
                          ),
                        ),
                        Positioned.fill(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.5), // Slight overlay for readability
                            ),
                          ),
                        ),


                        // Content
                        Column(
                          children: [
                            // Header / Drag Handle
                            SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 32),
                                      onPressed: () => Navigator.of(context).pop(),
                                    ),
                                    const Spacer(),
                                    // Drag Handle Indicator (Optional, but good for UX)
                                    Container(
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const Spacer(),
                                    const SizedBox(width: 48), // Balance the row
                                  ],
                                ),
                              ),
                            ),

                            // Main Player Content
                            if (!_showQueue)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return SingleChildScrollView(
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              // Artwork
                                              ConstrainedBox(
                                                constraints: const BoxConstraints(
                                                  maxHeight: 220,
                                                ),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(20),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: 0.4),
                                                        blurRadius: 20,
                                                        offset: const Offset(0, 10),
                                                      ),
                                                    ],
                                                  ),
                                                  child: CachedNetworkImage(
                                                          imageUrl: artworkUrl,
                                                          fit: BoxFit.contain,
                                                          errorWidget: (context, url, error) => Container(
                                                            width: 220,
                                                            height: 220,
                                                            color: Colors.grey[900],
                                                            child: const Icon(Icons.music_note,
                                                                color: Colors.white, size: 64),
                                                          ),
                                                        ),
                                                  ),
                                                ),
                                              const SizedBox(height: 20),

                                              // Title and Artist
                                              Text(
                                                mediaItem.title,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              GestureDetector(
                                                onTap: () {
                                                  final artistId = mediaItem.extras?['artistId'];
                                                  if (artistId != null) {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) => ArtistScreen(
                                                          browseId: artistId,
                                                          artistName: mediaItem.artist,
                                                          // We don't have artist thumbnail here, but that's fine
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                                child: Text(
                                                  mediaItem.artist ?? '',
                                                  style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.7),
                                                    fontSize: 14,
                                                    decoration: mediaItem.extras?['artistId'] != null ? TextDecoration.underline : null,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(height: 16),

                                              // Action Buttons (Favorite & Download)
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
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
                                                              size: 28,
                                                            ),
                                                            onPressed: () {
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
                                                  const SizedBox(width: 24),
                                                  Consumer(
                                                    builder: (context, ref, child) {
                                                      final storage = ref.watch(storageServiceProvider);
                                                      return ValueListenableBuilder(
                                                        valueListenable: storage.downloadsListenable,
                                                        builder: (context, box, _) {
                                                          final isDownloaded = storage.isDownloaded(mediaItem.id);
                                                          return IconButton(
                                                            icon: Icon(
                                                              isDownloaded ? Icons.download_done : Icons.download_rounded,
                                                              color: Colors.white,
                                                              size: 28,
                                                            ),
                                                            onPressed: () async {
                                                              final downloadService = DownloadService();
                                                              if (isDownloaded) {
                                                                await downloadService.deleteDownload(mediaItem.id);
                                                                if (context.mounted) {
                                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                                    const SnackBar(content: Text('Removed from downloads')),
                                                                  );
                                                                }
                                                              } else {
                                                                // Show downloading alert
                                                                bool isDialogVisible = true;
                                                                showAppAlertDialog(
                                                                  context: context,
                                                                  title: 'Downloading',
                                                                  content: const Column(
                                                                    mainAxisSize: MainAxisSize.min,
                                                                    children: [
                                                                      Text('Please wait while the song is being downloaded...'),
                                                                      SizedBox(height: 16),
                                                                      CupertinoActivityIndicator(),
                                                                    ],
                                                                  ),
                                                                  actions: [
                                                                    CupertinoDialogAction(
                                                                      onPressed: () => Navigator.pop(context),
                                                                      child: const Text('Hide'),
                                                                    ),
                                                                  ],
                                                                ).then((_) => isDialogVisible = false);

                                                                final result = YtifyResult(
                                                                  videoId: mediaItem.id,
                                                                  title: mediaItem.title,
                                                                  thumbnails: [YtifyThumbnail(url: mediaItem.artUri.toString(), width: 0, height: 0)],
                                                                  artists: [YtifyArtist(name: mediaItem.artist ?? '', id: '')], 
                                                                  resultType: isSong ? 'song' : 'video',
                                                                  isExplicit: false,
                                                                );
                                                                final success = await ref.read(downloadProvider.notifier).startDownload(result);
                                                                
                                                                if (context.mounted) {
                                                                  if (isDialogVisible) {
                                                                    Navigator.of(context, rootNavigator: true).pop();
                                                                  }
                                                                  if (success) {
                                                                    showGlassSnackBar(context, 'Download complete');
                                                                  } else {
                                                                    showGlassSnackBar(context, 'Download failed - Please try again');
                                                                  }
                                                                }
                                                              }
                                                            },
                                                          );
                                                        },
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 20),

                                              // Seek Bar
                                              StreamBuilder<Duration>(
                                                stream: audioHandler.player.positionStream,
                                                builder: (context, snapshot) {
                                                  final position = snapshot.data ?? Duration.zero;
                                                  final duration = audioHandler.player.duration ?? Duration.zero;

                                                  return Column(
                                                    children: [
                                                      SliderTheme(
                                                        data: SliderTheme.of(context).copyWith(
                                                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                                          trackHeight: 4,
                                                          activeTrackColor: Theme.of(context).colorScheme.primary,
                                                          inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                                                          thumbColor: Theme.of(context).colorScheme.primary,
                                                          overlayColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                                        ),
                                                        child: Slider(
                                                          value: position.inSeconds.toDouble().clamp(0, duration.inSeconds.toDouble()),
                                                          min: 0,
                                                          max: duration.inSeconds.toDouble(),
                                                          onChanged: (value) {
                                                            audioHandler.seek(Duration(seconds: value.toInt()));
                                                          },
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                                        child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            Text(
                                                              _formatDuration(position),
                                                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                                                            ),
                                                            Text(
                                                              _formatDuration(duration),
                                                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                              const SizedBox(height: 16),

                                              // Controls
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                children: [


                                                  IconButton(
                                                    icon: const Icon(Icons.replay_5_rounded, color: Colors.white),
                                                    onPressed: () {
                                                      final position = audioHandler.player.position;
                                                      audioHandler.seek(position - const Duration(seconds: 5));
                                                    },
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 48),
                                                    onPressed: () => audioHandler.skipToPrevious(),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                  ),
                                                  isPlayingAsync.when(
                                                    data: (isPlaying) => Container(
                                                      width: 80,
                                                      height: 80,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black.withValues(alpha: 0.2),
                                                            blurRadius: 10,
                                                            offset: const Offset(0, 4),
                                                          ),
                                                        ],
                                                      ),
                                                      child: IconButton(
                                                        icon: Icon(
                                                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                                          color: Colors.black,
                                                          size: 48,
                                                        ),
                                                        onPressed: () {
                                                          if (isPlaying) {
                                                            audioHandler.pause();
                                                          } else {
                                                            audioHandler.resume();
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                    loading: () => const SizedBox(
                                                        width: 80,
                                                        height: 80,
                                                        child: CircularProgressIndicator(color: Colors.white)
                                                    ),
                                                    error: (_, __) => const Icon(Icons.error, color: Colors.red),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 48),
                                                    onPressed: () => audioHandler.skipToNext(),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.forward_5_rounded, color: Colors.white),
                                                    onPressed: () {
                                                      final position = audioHandler.player.position;
                                                      audioHandler.seek(position + const Duration(seconds: 5));
                                                    },
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: MediaQuery.of(context).padding.bottom + 32),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              )
                            else
                              // Queue View
                              Expanded(
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                                            onPressed: () => setState(() => _showQueue = false),
                                          ),
                                          const Text('Up Next', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: StreamBuilder<SequenceState?>(
                                        stream: audioHandler.player.sequenceStateStream,
                                        builder: (context, snapshot) {
                                          final state = snapshot.data;
                                          final sequence = state?.sequence ?? [];
                                          
                                          if (sequence.isEmpty) {
                                            return const Center(child: Text('Queue is empty', style: TextStyle(color: Colors.grey)));
                                          }

                                          return ListView.builder(
                                            padding: EdgeInsets.zero,
                                            itemCount: sequence.length,
                                            itemBuilder: (context, index) {
                                              final item = sequence[index];
                                              final metadata = item.tag as MediaItem;
                                              final isPlaying = index == state?.currentIndex;
                                              
                                              // Calculate aspect ratio
                                              final resultType = metadata.extras?['resultType'] ?? 'video';
                                              final isVideo = resultType == 'video';
                                              final aspectRatio = isVideo ? 16 / 9 : 1.0;
                                            
                                              return Padding(
                                                padding: index == sequence.length - 1 
                                                  ? EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16) 
                                                  : EdgeInsets.zero,
                                                child: ListTile(
                                                  dense: true,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                                  leading: ClipRRect(
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: SizedBox(
                                                      height: 48,
                                                      width: 48 * aspectRatio,
                                                      child: CachedNetworkImage(
                                                        imageUrl: metadata.artUri.toString(),
                                                        fit: BoxFit.cover,
                                                        errorWidget: (context, url, error) => Container(
                                                          color: Colors.grey[800],
                                                          child: const Icon(Icons.music_note, color: Colors.white),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                    title: Text(
                                                      metadata.title,
                                                      style: TextStyle(
                                                        color: isPlaying ? Colors.red : Colors.white,
                                                        fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                                                        fontSize: 14,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    subtitle: Text(
                                                      metadata.artist ?? '',
                                                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    trailing: isPlaying ? const Icon(Icons.equalizer, color: Colors.red) : null,
                                                    onTap: () {
                                                      audioHandler.seek(Duration.zero, index: index);
                                                    },
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),


                            // Toggle Button (Only show when queue is NOT shown, to open it)
                            if (!_showQueue)
                              GestureDetector(
                                onTap: () => setState(() => _showQueue = true),
                                child: Container(
                                  padding: EdgeInsets.only(
                                    top: 16,
                                    bottom: MediaQuery.of(context).padding.bottom + 16,
                                  ),
                                  width: double.infinity,
                                  color: Colors.transparent,
                                  child: Column(
                                    children: [
                                      const Text('UP NEXT', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                                      const Icon(Icons.keyboard_arrow_up, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                  ],
                ),
              ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error loading player', style: TextStyle(color: Colors.white))),
      ),
    );
  }



  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : ''}$twoDigitMinutes:$twoDigitSeconds";
  }
}
