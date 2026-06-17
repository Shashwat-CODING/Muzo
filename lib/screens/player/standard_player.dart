import 'dart:ui';
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'components/albumart_lyrics.dart';
import 'components/player_control.dart';
import '../../widgets/song_options_menu.dart';
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:widget_marquee/widget_marquee.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/widgets/glass_snackbar.dart';
import 'package:muzo/services/lyrics_service.dart';
import 'package:muzo/widgets/lyrics_view.dart';

class StandardPlayer extends ConsumerStatefulWidget {
  const StandardPlayer({super.key});

  @override
  ConsumerState<StandardPlayer> createState() => _StandardPlayerState();
}

class _StandardPlayerState extends ConsumerState<StandardPlayer> {
  late PageController _pageController;
  int _currentPage = 1;
  bool _isLyricsExpanded = false;
  Timer? _lyricsInactivityTimer;
  Drag? _drag;

  // Lyrics state
  bool _isLoadingLyrics = false;
  Lyrics? _lyrics;
  String? _lastFetchedTitle;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _lyricsInactivityTimer?.cancel();
    super.dispose();
  }

  void _startLyricsInactivityTimer() {
    _lyricsInactivityTimer?.cancel();
    if (_currentPage == 0 && !_isLyricsExpanded) {
      _lyricsInactivityTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _currentPage == 0) {
          setState(() {
            _isLyricsExpanded = true;
          });
        }
      });
    }
  }

  void _resetLyricsInactivityTimer() {
    if (_currentPage != 0) return;
    if (_isLyricsExpanded) {
      setState(() {
        _isLyricsExpanded = false;
      });
    }
    _startLyricsInactivityTimer();
  }

  Future<void> _fetchLyrics(MediaItem mediaItem) async {
    if (_lastFetchedTitle == mediaItem.title) return;
    if (_isLoadingLyrics) return;
    if (!mounted) return;
    setState(() {
      _lyrics = null;
      _isLoadingLyrics = true;
    });
    try {
      final lyrics = await ref
          .read(lyricsServiceProvider)
          .fetchLyrics(
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
      if (mounted) {
        setState(() {
          _lyrics = null;
          _lastFetchedTitle = mediaItem.title;
          _isLoadingLyrics = false;
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final mediaItemAsync = ref.watch(currentMediaItemProvider);

    final mediaItem = mediaItemAsync.value;
    final artUri = mediaItem?.artUri;

    // Listen to track changes to fetch lyrics
    ref.listen<AsyncValue<MediaItem?>>(currentMediaItemProvider, (previous, next) {
      next.whenData((item) {
        if (item != null) {
          _fetchLyrics(item);
        }
      });
    });

    // Initial lyrics fetch if mediaItem is already loaded
    if (mediaItem != null && _lyrics == null && !_isLoadingLyrics) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchLyrics(mediaItem);
      });
    }

    // Responsive artwork calculation (uses percentage of width and capping at height percentage)
    double playerArtImageSize = size.width * 0.88;
    final double maxArtSize = size.height * 0.42;
    if (playerArtImageSize > maxArtSize) {
      playerArtImageSize = maxArtSize;
    }
    if (playerArtImageSize < 150) playerArtImageSize = 150; // Safeguard

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tintColor = isDark ? Colors.black : Colors.white;

    final backgroundStack = Stack(
      children: [
        if (artUri != null)
          SizedBox.expand(
            child: CachedNetworkImage(
              imageUrl: artUri.toString(),
              fit: BoxFit.cover,
              height: MediaQuery.of(context).size.height,
              placeholder: (context, url) => Container(color: isDark ? Colors.black : Colors.white),
              errorWidget: (context, url, error) => Container(color: isDark ? Colors.black : Colors.white),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                tintColor.withValues(alpha: isDark ? 0.15 : 0.3),
                tintColor.withValues(alpha: isDark ? 0.70 : 0.85),
              ],
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dynamic Blurred background
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: backgroundStack,
            ),
          ),

          // Main contents
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isLandscape = size.width > size.height;

                if (isLandscape) {
                  double landscapeArtSize = size.height - 180;
                  if (landscapeArtSize > size.width / 2 - 50) {
                    landscapeArtSize = size.width / 2 - 50;
                  }
                  return Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: MediaQuery.of(context).padding.top + 20),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 600),
                              child: AlbumArtNLyrics(playerArtImageSize: landscapeArtSize),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 40),
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
                  // Portrait page structure
                  return Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (_) {
                      _resetLyricsInactivityTimer();
                    },
                    child: Stack(
                      children: [
                        // Swipeable PageView
                        Positioned.fill(
                          child: PageView(
                            controller: _pageController,
                            physics: const NeverScrollableScrollPhysics(),
                            onPageChanged: (page) {
                              setState(() {
                                _currentPage = page;
                                if (page != 0) {
                                  _isLyricsExpanded = false;
                                  _lyricsInactivityTimer?.cancel();
                                } else {
                                  _startLyricsInactivityTimer();
                                }
                              });
                            },
                            children: [
                              _buildLyricsPage(context, ref, mediaItem),
                              _buildMainPage(context, ref, mediaItem, playerArtImageSize),
                              _buildQueuePage(context, ref, mediaItem),
                            ],
                          ),
                        ),

                        // Sticky pull-down handle at the top center of the screen
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          top: _isLyricsExpanded ? -30 : 0,
                          left: 0,
                          right: 0,
                          height: 30,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              Navigator.of(context).pop();
                            },
                            child: Center(
                              child: Container(
                                width: 36,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(2.5),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Sticky Controls overlayed at bottom
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          left: 0,
                          right: 0,
                          bottom: _isLyricsExpanded ? -300 : 0,
                          child: _buildStickyBottomControls(context, ref, mediaItem),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainPage(BuildContext context, WidgetRef ref, MediaItem? mediaItem, double playerArtSize) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Top spacing
          SizedBox(height: MediaQuery.of(context).padding.top + screenHeight * 0.09),

          // Large Album Art
          Center(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (details) {
                if (_pageController.hasClients) {
                  _drag = _pageController.position.drag(details, () {
                    _drag = null;
                  });
                }
              },
              onHorizontalDragUpdate: (details) {
                _drag?.update(details);
              },
              onHorizontalDragEnd: (details) {
                _drag?.end(details);
              },
              onHorizontalDragCancel: () {
                _drag?.cancel();
              },
              child: Container(
                width: playerArtSize,
                height: playerArtSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 32,
                      spreadRadius: -4,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: mediaItem?.artUri != null
                      ? CachedNetworkImage(
                          imageUrl: mediaItem!.artUri.toString().replaceAll(
                            RegExp(r'w\d+-h\d+'),
                            'w800-h800',
                          ),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                          errorWidget: (context, url, error) => Container(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                        )
                      : Container(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                          child: Icon(Icons.music_note, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                        ),
                ),
              ),
            ),
          ),

          const Spacer(),

          // Title, Artist, Favorite, Options
          if (mediaItem != null)
            _buildSongMetaRow(context, ref, mediaItem),

          // Space above bottom controls (percentage based)
          SizedBox(height: screenHeight * 0.015),
          
          // Bottom controls offset spacer (percentage based)
          SizedBox(height: screenHeight * 0.33),
        ],
      ),
    );
  }

  Widget _buildSongMetaRow(BuildContext context, WidgetRef ref, MediaItem mediaItem) {
    final storage = ref.watch(storageServiceProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Title and Artist
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 32,
                child: Marquee(
                  delay: const Duration(milliseconds: 300),
                  duration: const Duration(seconds: 10),
                  child: Text(
                    mediaItem.title,
                    style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          letterSpacing: -0.5,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mediaItem.artist ?? "Unknown Artist",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        
        // Favorite button (circular, translucent background)
        ValueListenableBuilder(
          valueListenable: storage.favoritesListenable,
          builder: (context, favorites, _) {
            final isFav = storage.isFavorite(mediaItem.id);
            return _buildCircularIconButton(
              context,
              icon: Icon(
                isFav ? FluentIcons.star_24_filled : FluentIcons.star_24_regular,
                color: isFav ? Colors.yellow[600] : Theme.of(context).colorScheme.onSurface,
                size: 20,
              ),
              onPressed: () {
                final result = MuzoItem(
                  videoId: mediaItem.id,
                  title: mediaItem.title,
                  thumbnails: [MuzoThumbnail(url: mediaItem.artUri.toString(), width: 0, height: 0)],
                  artists: [MuzoArtist(name: mediaItem.artist ?? '', id: '')],
                  resultType: mediaItem.extras?['resultType'] ?? 'video',
                  isExplicit: false,
                );
                storage.toggleFavorite(result);
                showGlassSnackBar(
                  context,
                  isFav ? 'Removed from favorites' : 'Added to favorites',
                );
              },
            );
          },
        ),
        
        const SizedBox(width: 12),

        // Options button (circular, translucent background)
        _buildCircularIconButton(
          context,
          icon: Icon(
            Icons.more_horiz,
            color: Theme.of(context).colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () {
            final result = MuzoItem(
              videoId: mediaItem.id,
              title: mediaItem.title,
              thumbnails: [MuzoThumbnail(url: mediaItem.artUri.toString(), width: 0, height: 0)],
              artists: [MuzoArtist(name: mediaItem.artist ?? '', id: '')],
              resultType: mediaItem.extras?['resultType'] ?? 'video',
              isExplicit: false,
            );
            SongOptionsMenu.show(ref, result, fromPlayer: true);
          },
        ),
      ],
    );
  }

  Widget _buildCircularIconButton(BuildContext context, {required Widget icon, required VoidCallback onPressed}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: onPressed,
          child: Center(child: icon),
        ),
      ),
    );
  }

  Widget _buildCompactHeader(BuildContext context, WidgetRef ref, MediaItem? mediaItem) {
    if (mediaItem == null) return const SizedBox.shrink();
    final storage = ref.watch(storageServiceProvider);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (details) {
        if (_pageController.hasClients) {
          _drag = _pageController.position.drag(details, () {
            _drag = null;
          });
        }
      },
      onHorizontalDragUpdate: (details) {
        _drag?.update(details);
      },
      onHorizontalDragEnd: (details) {
        _drag?.end(details);
      },
      onHorizontalDragCancel: () {
        _drag?.cancel();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Album Art thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: mediaItem.artUri.toString(),
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
              ),
            ),
            const SizedBox(width: 12),
            // Title / Artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mediaItem.title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mediaItem.artist ?? "Unknown Artist",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Favorite button (circular, translucent background)
            ValueListenableBuilder(
              valueListenable: storage.favoritesListenable,
              builder: (context, favorites, _) {
                final isFav = storage.isFavorite(mediaItem.id);
                return IconButton(
                  icon: Icon(
                    isFav ? FluentIcons.star_24_filled : FluentIcons.star_24_regular,
                    color: isFav ? Colors.yellow[600] : Theme.of(context).colorScheme.onSurface,
                    size: 20,
                  ),
                  onPressed: () {
                    final result = MuzoItem(
                      videoId: mediaItem.id,
                      title: mediaItem.title,
                      thumbnails: [MuzoThumbnail(url: mediaItem.artUri.toString(), width: 0, height: 0)],
                      artists: [MuzoArtist(name: mediaItem.artist ?? '', id: '')],
                      resultType: mediaItem.extras?['resultType'] ?? 'video',
                      isExplicit: false,
                    );
                    storage.toggleFavorite(result);
                  },
                );
              },
            ),
            // Options button
            IconButton(
              icon: Icon(Icons.more_horiz, color: Theme.of(context).colorScheme.onSurface, size: 20),
              onPressed: () {
                final result = MuzoItem(
                  videoId: mediaItem.id,
                  title: mediaItem.title,
                  thumbnails: [MuzoThumbnail(url: mediaItem.artUri.toString(), width: 0, height: 0)],
                  artists: [MuzoArtist(name: mediaItem.artist ?? '', id: '')],
                  resultType: mediaItem.extras?['resultType'] ?? 'video',
                  isExplicit: false,
                );
                SongOptionsMenu.show(ref, result, fromPlayer: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricsPage(BuildContext context, WidgetRef ref, MediaItem? mediaItem) {
    if (mediaItem == null) return const SizedBox.shrink();
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Column(
      children: [
        // Spacing for top handle / safe area
        SizedBox(height: MediaQuery.of(context).padding.top + 8),
        
        // Compact song header (always visible)
        _buildCompactHeader(context, ref, mediaItem),
        
        const SizedBox(height: 8),

        // Lyrics scroll container
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: _isLoadingLyrics
                ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onSurface))
                : _lyrics == null
                    ? Center(
                        child: Text(
                          "No lyrics found",
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 16),
                        ),
                      )
                    : LyricsView(
                        lyrics: _lyrics!,
                        onClose: () {},
                        positionStream: ref.watch(audioHandlerProvider).player.positionStream,
                        totalDuration: mediaItem.duration ?? Duration.zero,
                        isEmbedded: false,
                        scrollable: true,
                        accentColor: Theme.of(context).colorScheme.onSurface,
                      ),
          ),
        ),
        
        // Offset spacer for controls - proportional to screen size
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          height: _isLyricsExpanded ? screenHeight * 0.05 : screenHeight * 0.33,
        ),
      ],
    );
  }

  Widget _buildQueuePage(BuildContext context, WidgetRef ref, MediaItem? mediaItem) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final screenHeight = MediaQuery.of(context).size.height;

    return StreamBuilder<SequenceState?>(
      stream: audioHandler.player.sequenceStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final sequence = state?.sequence ?? [];
        final currentIndex = state?.currentIndex ?? 0;
        
        // Items after current index
        final nextItems = currentIndex + 1 < sequence.length 
            ? sequence.sublist(currentIndex + 1) 
            : [];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // Header spacing
              SizedBox(height: MediaQuery.of(context).padding.top + 8),
              
              // Compact header
              _buildCompactHeader(context, ref, mediaItem),

              // Queue Controls Row
              _buildQueueControlsRow(context, ref),

              // Playing Next Row
              _buildPlayingNextRow(context, ref, sequence.length),

              // Queue List
              Expanded(
                child: nextItems.isEmpty
                    ? Center(
                        child: Text(
                          "No upcoming songs",
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 14),
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: nextItems.length,
                        onReorder: (oldIndex, newIndex) {
                          audioHandler.reorderQueue(
                            currentIndex + 1 + oldIndex,
                            currentIndex + 1 + newIndex,
                          );
                        },
                        itemBuilder: (context, index) {
                          final audioSource = nextItems[index];
                          final item = audioSource.tag as MediaItem;

                          return _buildQueueItemTile(
                            context,
                            ref,
                            item,
                            currentIndex + 1 + index,
                            onTap: () {
                              audioHandler.player.seek(Duration.zero, index: currentIndex + 1 + index);
                              audioHandler.player.play();
                            },
                            onRemove: () {
                              audioHandler.removeQueueItem(currentIndex + 1 + index);
                            },
                          );
                        },
                      ),
              ),

              // Spacer to ensure queue items are only in the part above controls
              SizedBox(height: screenHeight * 0.33),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQueueControlsRow(BuildContext context, WidgetRef ref) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final player = audioHandler.player;
    final storage = ref.watch(storageServiceProvider);

    return StreamBuilder<bool>(
      stream: player.shuffleModeEnabledStream,
      builder: (context, shuffleSnapshot) {
        final shuffleEnabled = shuffleSnapshot.data ?? false;
        return StreamBuilder<LoopMode>(
          stream: player.loopModeStream,
          builder: (context, loopSnapshot) {
            final loopMode = loopSnapshot.data ?? LoopMode.off;
            final isRepeatEnabled = loopMode != LoopMode.off;

            return ValueListenableBuilder<bool>(
              valueListenable: audioHandler.isLofiModeNotifier,
              builder: (context, isLofi, _) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Shuffle
                      _buildQueuePillButton(
                        context,
                        icon: Icon(
                          FluentIcons.arrow_shuffle_24_regular,
                          color: shuffleEnabled ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.onSurface,
                          size: 20,
                        ),
                        isActive: shuffleEnabled,
                        onPressed: () => player.setShuffleModeEnabled(!shuffleEnabled),
                      ),
                      // Repeat
                      _buildQueuePillButton(
                        context,
                        icon: Icon(
                          loopMode == LoopMode.one
                              ? FluentIcons.arrow_repeat_1_24_regular
                              : FluentIcons.arrow_repeat_all_24_regular,
                          color: isRepeatEnabled ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.onSurface,
                          size: 20,
                        ),
                        isActive: isRepeatEnabled,
                        onPressed: () async {
                          if (loopMode == LoopMode.off) {
                            await player.setLoopMode(LoopMode.all);
                          } else if (loopMode == LoopMode.all) {
                            await player.setLoopMode(LoopMode.one);
                          } else {
                            await player.setLoopMode(LoopMode.off);
                          }
                        },
                      ),
                      // Auto-queue / Infinity
                      _buildQueuePillButton(
                        context,
                        icon: Icon(
                          Icons.all_inclusive,
                          color: storage.isAutoQueueEnabled ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          size: 20,
                        ),
                        isActive: storage.isAutoQueueEnabled,
                        onPressed: () async {
                          await storage.setAutoQueueEnabled(!storage.isAutoQueueEnabled);
                          setState(() {});
                        },
                      ),
                      // Lofi mode
                      _buildQueuePillButton(
                        context,
                        icon: Icon(
                          Icons.waves_rounded,
                          color: isLofi ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.onSurface,
                          size: 20,
                        ),
                        isActive: isLofi,
                        onPressed: () => audioHandler.toggleLofiMode(),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildQueuePillButton(BuildContext context, {required Widget icon, required bool isActive, required VoidCallback onPressed}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = Theme.of(context).colorScheme.onSurface;
    final inactiveBg = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15);

    return Container(
      width: 58,
      height: 36,
      decoration: BoxDecoration(
        color: isActive ? activeBg : inactiveBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Center(child: icon),
        ),
      ),
    );
  }

  Widget _buildPlayingNextRow(BuildContext context, WidgetRef ref, int queueLength) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final currentItem = ref.watch(currentMediaItemProvider).value;
    final albumName = currentItem?.album ?? "Muzo";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Playing Next",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "From $albumName",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: queueLength <= 1
                ? null
                : () {
                    audioHandler.clearQueue();
                    showGlassSnackBar(context, 'Queue cleared');
                  },
            child: Text(
              "Clear",
              style: TextStyle(
                color: queueLength <= 1 ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3) : Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueItemTile(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
    int index, {
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    return Dismissible(
      key: ValueKey('dismiss_queue_${item.id}_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      onDismissed: (_) => onRemove(),
      child: GestureDetector(
        key: ValueKey('tile_queue_${item.id}_$index'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: item.artUri.toString(),
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.artist ?? 'Unknown Artist',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Drag handle
              ReorderableDragStartListener(
                index: index,
                child: Icon(
                  Icons.drag_handle,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickyBottomControls(BuildContext context, WidgetRef ref, MediaItem? mediaItem) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final player = audioHandler.player;
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding > 0 ? bottomPadding : screenHeight * 0.025),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Progress Slider
          StreamBuilder<Duration>(
            stream: player.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = mediaItem?.duration ?? player.duration ?? Duration.zero;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProgressBar(
                    thumbRadius: 0,
                    thumbGlowRadius: 0,
                    barHeight: 8,
                    baseBarColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18),
                    bufferedBarColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.28),
                    progressBarColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                    thumbColor: Colors.transparent,
                    timeLabelLocation: TimeLabelLocation.none,
                    progress: position,
                    total: duration,
                    onSeek: (duration) {
                      player.seek(duration);
                    },
                  ),
                  SizedBox(height: screenHeight * 0.008),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Elapsed time
                      Text(
                        _formatDuration(position),
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w400),
                      ),
                      // Remaining time (negative)
                      Text(
                        mediaItem?.duration != null
                            ? "-${_formatDuration(duration - position)}"
                            : "0:00",
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          SizedBox(height: screenHeight * 0.024),

          // 2. Playback Controls Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Previous button
              IconButton(
                icon: Icon(CupertinoIcons.backward_fill, color: Theme.of(context).colorScheme.onSurface, size: 34),
                onPressed: () => audioHandler.skipToPrevious(),
              ),
              
              // Play/Pause button
              StreamBuilder<PlayerState>(
                stream: player.playerStateStream,
                builder: (context, snapshot) {
                  final playerState = snapshot.data;
                  final processingState = playerState?.processingState;
                  final playing = playerState?.playing ?? false;
                  final isLoading = processingState == ProcessingState.loading || processingState == ProcessingState.buffering;

                  if (isLoading) {
                    return SizedBox(
                      width: 46,
                      height: 46,
                      child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onSurface, strokeWidth: 3),
                    );
                  }

                  return IconButton(
                    icon: Icon(
                      playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 46,
                    ),
                    onPressed: () {
                      if (playing) {
                        player.pause();
                      } else {
                        player.play();
                      }
                    },
                  );
                },
              ),

              // Next button
              IconButton(
                icon: Icon(CupertinoIcons.forward_fill, color: Theme.of(context).colorScheme.onSurface, size: 34),
                onPressed: () => audioHandler.skipToNext(),
              ),
            ],
          ),

          SizedBox(height: screenHeight * 0.024),

          StreamBuilder<double>(
            stream: player.volumeStream,
            builder: (context, snapshot) {
              final volume = snapshot.data ?? player.volume;
              return Row(
                children: [
                  Icon(Icons.volume_down, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), size: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 8,
                          activeTrackColor: Theme.of(context).colorScheme.onSurface,
                          inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                          thumbColor: Colors.transparent,
                          thumbShape: SliderComponentShape.noThumb,
                          overlayColor: Colors.transparent,
                          overlayShape: SliderComponentShape.noOverlay,
                        ),
                        child: Slider(
                          value: volume,
                          onChanged: (val) {
                            audioHandler.setVolume(val);
                          },
                        ),
                      ),
                    ),
                  ),
                  Icon(Icons.volume_up, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), size: 16),
                ],
              );
            },
          ),

          SizedBox(height: screenHeight * 0.016),

          // 4. Bottom Navigation Icon Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Lyrics toggle button
              IconButton(
                icon: Icon(
                  FluentIcons.chat_24_regular,
                  color: _currentPage == 0 ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 20,
                ),
                onPressed: () {
                  if (_currentPage == 0) {
                    _pageController.animateToPage(1, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
                  } else {
                    _pageController.animateToPage(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
                  }
                },
              ),

              // Main Player tab (thumbnail view)
              IconButton(
                icon: Icon(
                  Icons.music_note_rounded,
                  color: _currentPage == 1 ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 20,
                ),
                onPressed: () {
                  _pageController.animateToPage(1, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
                },
              ),

              // Queue toggle button
              IconButton(
                icon: Icon(
                  FluentIcons.list_24_regular,
                  color: _currentPage == 2 ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 20,
                ),
                onPressed: () {
                  if (_currentPage == 2) {
                    _pageController.animateToPage(1, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
                  } else {
                    _pageController.animateToPage(2, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

