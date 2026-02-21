import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'components/albumart_lyrics.dart';
import 'components/player_control.dart';
import 'components/up_next_queue.dart';
import '../../widgets/song_options_menu.dart';
import 'package:muzo/models/ytify_result.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/providers/settings_provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:widget_marquee/widget_marquee.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/widgets/glass_snackbar.dart';
import 'package:muzo/services/lyrics_service.dart';
import 'package:muzo/widgets/lyrics_view.dart';
import 'package:muzo/providers/theme_provider.dart';

class StandardPlayer extends ConsumerWidget {
  const StandardPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final mediaItemAsync = ref.watch(currentMediaItemProvider);
    final isLiteMode = ref.watch(settingsProvider).isLiteMode;

    double playerArtImageSize = size.width - 50;
    final spaceAvailableForArtImage =
        size.height - (70 + MediaQuery.of(context).padding.bottom + 260);
    playerArtImageSize = playerArtImageSize > spaceAvailableForArtImage
        ? spaceAvailableForArtImage
        : playerArtImageSize;

    // Dynamic Background with Blurred Image
    final isGestureMode = ref.watch(settingsProvider).isGestureMode;

    if (isGestureMode) {
      return _GesturePlayer(mediaItemAsync: mediaItemAsync);
    }

    final mediaItem = mediaItemAsync.value;
    final artUri = mediaItem?.artUri;

    return Stack(
      children: [
        Stack(
          children: [
            if (artUri != null)
              SizedBox.expand(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
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

            // Gradient Overlay for readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.8),
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
              final isLandscape = size.width > size.height;

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
                          bottom: 50 + MediaQuery.of(context).padding.bottom,
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
                    SizedBox(height: MediaQuery.of(context).padding.top + 76),

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

                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: 10,
                          bottom: MediaQuery.of(context).padding.bottom,
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

class _GesturePlayer extends ConsumerStatefulWidget {
  final AsyncValue<MediaItem?> mediaItemAsync;

  const _GesturePlayer({required this.mediaItemAsync});

  @override
  ConsumerState<_GesturePlayer> createState() => _GesturePlayerState();
}

class _GesturePlayerState extends ConsumerState<_GesturePlayer> {
  bool _showIcon = false;
  bool _isPlaying = false;
  Timer? _iconTimer;

  void _triggerAnimation(bool isPlaying) {
    _iconTimer?.cancel();
    setState(() {
      _showIcon = true;
      _isPlaying = isPlaying;
    });
    _iconTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _showIcon = false;
        });
      }
    });
  }

  // Volume Control Variables
  bool _showVolume = false;
  double _currentVolume = 1.0;
  bool _isRightSideDrag = false;
  Timer? _volumeTimer;

  // Lyrics Variables
  bool _showLyrics = false;
  bool _isLoadingLyrics = false;
  Lyrics? _lyrics;
  String? _lastFetchedTitle;

  Future<void> _fetchLyrics(MediaItem mediaItem) async {
    if (_lyrics != null && _lastFetchedTitle == mediaItem.title) return;
    if (_isLoadingLyrics) return;
    setState(() => _isLoadingLyrics = true);
    try {
      final lyrics = await ref.read(lyricsServiceProvider).fetchLyrics(
            mediaItem.title,
            mediaItem.artist ?? '',
            mediaItem.duration?.inSeconds ??
                ref.read(audioHandlerProvider).player.duration?.inSeconds ??
                0,
          );
      if (mounted) {
        setState(() {
          _lyrics = lyrics;
          _lastFetchedTitle = mediaItem.title;
          _isLoadingLyrics = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLyrics = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize current volume
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final vol = ref.read(audioHandlerProvider).player.volume;
        setState(() => _currentVolume = vol);
      }
    });
  }

  void _showVolumeIndicator() {
    setState(() => _showVolume = true);
    _volumeTimer?.cancel();
    _volumeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showVolume = false);
    });
  }

  @override
  void dispose() {
    _iconTimer?.cancel();
    _volumeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch settings to ensure rebuilds if needed
    final artUri = widget.mediaItemAsync.value?.artUri;

    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        // Full Screen Background (No Blur, No Tint)
        if (artUri != null)
          SizedBox.expand(
            child: CachedNetworkImage(
              imageUrl: artUri.toString().replaceAll(RegExp(r'w\d+-h\d+'), 'w800-h800'),
              fit: BoxFit.cover,
              height: MediaQuery.of(context).size.height,
              placeholder: (context, url) => Container(color: Colors.black),
              errorWidget: (context, url, error) => Container(color: Colors.black),
            ),
          ),

        // Gesture Detector covering the screen
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTap: () {
               final handler = ref.read(audioHandlerProvider);
               final player = handler.player;
               final willPlay = !player.playing;
               if (player.playing) {
                 player.pause();
               } else {
                 player.play();
               }
               _triggerAnimation(willPlay);
            },
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity == null) return;
              final handler = ref.read(audioHandlerProvider);
              
              // Sensitivity threshold
              if (details.primaryVelocity! < -100) {
                // Swipe Left -> Next
                handler.skipToNext();
              } else if (details.primaryVelocity! > 100) {
                // Swipe Right -> Previous
                handler.skipToPrevious();
              }
            },
            onVerticalDragStart: (details) {
              // Only activate volume control when drag starts on right half
              _isRightSideDrag = details.globalPosition.dx > screenWidth / 2;
            },
            onVerticalDragUpdate: (details) {
              if (!_isRightSideDrag) return;
              final player = ref.read(audioHandlerProvider).player;
              // Sensitivity: 1.0 volume over 300 pixels
              final delta = details.primaryDelta! / -300;
              double newVolume = (player.volume + delta).clamp(0.0, 1.0);
              player.setVolume(newVolume);
              setState(() => _currentVolume = newVolume);
              _showVolumeIndicator();
            },
            onVerticalDragEnd: (details) {
              // Swipe down on left half to close player
              if (!_isRightSideDrag &&
                  (details.primaryVelocity ?? 0) > 400) {
                ref.read(isPlayerExpandedProvider.notifier).state = false;
                Navigator.of(context).pop();
              }
              _isRightSideDrag = false;
            },
            child: Container(color: Colors.transparent),
          ),
        ),

        // Cloud-style Lyrics Overlay (above controls)
        if (_showLyrics)
          Positioned(
            left: 20,
            right: 20,
            bottom: 80 + MediaQuery.of(context).padding.bottom + 155,
            top: MediaQuery.of(context).padding.top + 72,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              // Double-tap on lyrics → play/pause (same as background)
              onDoubleTap: () {
                final handler = ref.read(audioHandlerProvider);
                final player = handler.player;
                final willPlay = !player.playing;
                if (player.playing) {
                  player.pause();
                } else {
                  player.play();
                }
                _triggerAnimation(willPlay);
              },
              // Right-side vertical drag → volume (same as background)
              onVerticalDragStart: (details) {
                _isRightSideDrag = details.globalPosition.dx > screenWidth / 2;
              },
              onVerticalDragUpdate: (details) {
                if (!_isRightSideDrag) return;
                final player = ref.read(audioHandlerProvider).player;
                final delta = details.primaryDelta! / -300;
                double newVolume = (player.volume + delta).clamp(0.0, 1.0);
                player.setVolume(newVolume);
                setState(() => _currentVolume = newVolume);
                _showVolumeIndicator();
              },
              onVerticalDragEnd: (details) {
                // Swipe down on left half to close player
                if (!_isRightSideDrag &&
                    (details.primaryVelocity ?? 0) > 400) {
                  ref.read(isPlayerExpandedProvider.notifier).state = false;
                  Navigator.of(context).pop();
                }
                _isRightSideDrag = false;
              },
              child: _CloudLyricsOverlay(
                isLoading: _isLoadingLyrics,
                lyrics: _lyrics,
                audioHandler: ref.watch(audioHandlerProvider),
                accentColor: ref
                        .watch(currentPaletteProvider)
                        .asData
                        ?.value
                        ?.darkVibrantColor
                        ?.color ??
                    Colors.white,
                onClose: () => setState(() => _showLyrics = false),
              ),
            ),
          ),

        // Play/Pause Animation Overlay — always on top of lyrics
        Center(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _showIcon ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(20),
                child: Icon(
                  _isPlaying ? FluentIcons.play_48_filled : FluentIcons.pause_48_filled,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
        ),

        // Vertical Volume Bar Overlay (right side) — always on top
        Positioned(
          right: 20,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _showVolume ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: 52,
                      height: 220,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            _currentVolume == 0
                                ? FluentIcons.speaker_mute_24_filled
                                : _currentVolume < 0.5
                                    ? FluentIcons.speaker_1_24_filled
                                    : FluentIcons.speaker_2_24_filled,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  Container(
                                    width: 6,
                                    height: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    heightFactor: _currentVolume,
                                    child: Container(
                                      width: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.white.withValues(alpha: 0.6),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_currentVolume * 100).round()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),


        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: 40 + MediaQuery.of(context).padding.bottom, 
              left: 20,
              right: 20,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + Fav
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Marquee(
                              delay: const Duration(milliseconds: 300),
                              duration: const Duration(seconds: 10),
                              child: Text(
                                widget.mediaItemAsync.value?.title ?? "Unknown Title",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.start,
                              ),
                            ),
                          ),
                          // Queue Button
                          IconButton(
                            icon: const Icon(
                              FluentIcons.list_24_regular,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (context) {
                                  return DraggableScrollableSheet(
                                    initialChildSize: 0.6,
                                    minChildSize: 0.3,
                                    maxChildSize: 0.9,
                                    builder: (context, scrollController) {
                                      return ClipRRect(
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(20),
                                        ),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.75),
                                              border: Border(
                                                top: BorderSide(
                                                  color: Colors.white.withValues(alpha: 0.15),
                                                  width: 1.0,
                                                ),
                                              ),
                                            ),
                                            child: UpNextQueue(
                                              scrollController: scrollController,
                                              onReorderStart: (oldIndex, newIndex) {
                                                // Reorder logic if needed
                                              },
                                              onReorderEnd: (index) {},
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                          // Lyrics Button
                          IconButton(
                            icon: Icon(
                              _showLyrics
                                  ? FluentIcons.text_quote_20_filled
                                  : FluentIcons.text_quote_20_regular,
                              color: _showLyrics
                                  ? Colors.blueAccent.shade100
                                  : Colors.white,
                            ),
                            onPressed: () {
                              final mediaItem = widget.mediaItemAsync.value;
                              if (mediaItem == null) return;
                              if (!_showLyrics) {
                                setState(() => _showLyrics = true);
                                _fetchLyrics(mediaItem);
                              } else {
                                setState(() => _showLyrics = false);
                              }
                            },
                          ),
                          // Favorite Button
                          Consumer(
                            builder: (context, ref, child) {
                              final storage = ref.watch(storageServiceProvider);
                              final mediaItem = widget.mediaItemAsync.value;
                              if (mediaItem == null) return const SizedBox.shrink();
                              return ValueListenableBuilder(
                                valueListenable: storage.favoritesListenable,
                                builder: (context, favorites, _) {
                                  final isFav = storage.isFavorite(mediaItem.id);
                                  return IconButton(
                                    icon: Icon(
                                      isFav
                                          ? FluentIcons.heart_24_filled
                                          : FluentIcons.heart_24_regular,
                                      color: isFav ? Colors.red : Colors.white,
                                    ),
                                    onPressed: () {
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
                                        resultType:
                                            mediaItem.extras?['resultType'] ?? 'video',
                                        isExplicit: false,
                                      );

                                      storage.toggleFavorite(result);

                                      if (context.mounted) {
                                        showGlassSnackBar(
                                          context,
                                          isFav
                                              ? 'Removed from favorites'
                                              : 'Added to favorites',
                                        );
                                      }
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Artist
                      Text(
                        widget.mediaItemAsync.value?.artist ?? "Unknown Artist",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.start,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 15),
                      // Progress Bar with Time
                      StreamBuilder<Duration>(
                        stream: ref.watch(audioHandlerProvider).player.positionStream,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final duration = ref.watch(audioHandlerProvider).player.duration ?? Duration.zero;
                          
                          return ProgressBar(
                            thumbRadius: 5,
                            barHeight: 4,
                            baseBarColor: Colors.white.withValues(alpha: 0.24),
                            bufferedBarColor: Colors.white.withValues(alpha: 0.38),
                            progressBarColor: Colors.white,
                            thumbColor: Colors.white,
                            timeLabelTextStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            timeLabelPadding: 5,
                            progress: position,
                            total: duration,
                            onSeek: (duration) {
                              ref.read(audioHandlerProvider).player.seek(duration);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Header (Minimize, Options)
        Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 20,
            left: 10,
            right: 10,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, size: 28, color: Colors.white),
                onPressed: () {
                  ref.read(isPlayerExpandedProvider.notifier).state = false;
                  Navigator.of(context).pop();
                },
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, size: 25, color: Colors.white),
                onPressed: () {
                   widget.mediaItemAsync.whenData((mediaItem) {
                    if (mediaItem == null) return;
                    final result = YtifyResult(
                      videoId: mediaItem.id,
                      title: mediaItem.title,
                      thumbnails: [
                        YtifyThumbnail(url: mediaItem.artUri.toString(), width: 0, height: 0),
                      ],
                      artists: [YtifyArtist(name: mediaItem.artist ?? '', id: '')],
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



// Cloud-style lyrics overlay for gesture player
class _CloudLyricsOverlay extends StatelessWidget {
  final bool isLoading;
  final Lyrics? lyrics;
  final dynamic audioHandler;
  final Color accentColor;
  final VoidCallback onClose;

  const _CloudLyricsOverlay({
    required this.isLoading,
    required this.lyrics,
    required this.audioHandler,
    required this.accentColor,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header — identical padding/style to controls popup title row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          FluentIcons.text_quote_20_filled,
                          color: Colors.white.withValues(alpha: 0.75),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Lyrics',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onClose,
                    ),
                  ],
                ),
              ),
              // Lyrics body — isEmbedded:false hides LyricsView's own header
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : lyrics == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              FluentIcons.text_quote_20_regular,
                              color: Colors.white.withValues(alpha: 0.3),
                              size: 40,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No lyrics found',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : LyricsView(
                        lyrics: lyrics!,
                        onClose: onClose,
                        positionStream: audioHandler.player.positionStream,
                        totalDuration:
                            audioHandler.player.duration ?? Duration.zero,
                        isEmbedded: false,
                        scrollable: false,
                        accentColor: accentColor,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
