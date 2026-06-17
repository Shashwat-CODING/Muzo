import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/providers/player_provider.dart';
import 'dart:ui';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:muzo/services/lyrics_service.dart';
import 'package:muzo/widgets/lyrics_view.dart';
import 'package:muzo/providers/theme_provider.dart';
import 'package:audio_service/audio_service.dart';

class AlbumArtNLyrics extends ConsumerStatefulWidget {
  final double playerArtImageSize;
  const AlbumArtNLyrics({super.key, required this.playerArtImageSize});

  @override
  ConsumerState<AlbumArtNLyrics> createState() => _AlbumArtNLyricsState();
}

class _AlbumArtNLyricsState extends ConsumerState<AlbumArtNLyrics> {
  bool _showLyrics = false;
  bool _isLoadingLyrics = false;
  Lyrics? _lyrics;
  String? _lastFetchedTitle;

  Future<void> _fetchLyrics(MediaItem mediaItem) async {
    if (_lastFetchedTitle == mediaItem.title) return;
    if (_isLoadingLyrics) return; // Prevent concurrent fetches

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
            // mediaItem.duration may be null before stream loads; fall back to player's actual duration
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

  @override
  Widget build(BuildContext context) {
    final mediaItemAsync = ref.watch(currentMediaItemProvider);
    final audioHandler = ref.watch(audioHandlerProvider);

    // Reset lyrics if song changes (optional, but good UX to clear old lyrics)
    // Listen for media changes to auto-update lyrics
    ref.listen(currentMediaItemProvider, (previous, next) {
      next.whenData((mediaItem) {
        if (mediaItem != null &&
            mediaItem.title != _lastFetchedTitle &&
            _showLyrics) {
          _fetchLyrics(mediaItem);
        }
      });
    });

    final safeSize = widget.playerArtImageSize.clamp(10.0, double.infinity);

    return SizedBox(
      width: safeSize,
      height: safeSize,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 30,
              offset: Offset(0, 15),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              mediaItemAsync.when(
                data: (mediaItem) {
                  if (mediaItem?.artUri == null) {
                    return Container(color: Colors.grey[900]);
                  }
                  return CachedNetworkImage(
                    imageUrl: mediaItem!.artUri.toString().replaceAll(
                      RegExp(r'w\d+-h\d+'),
                      'w800-h800',
                    ),
                    fit: BoxFit.cover,
                    width: widget.playerArtImageSize,
                    height: widget.playerArtImageSize,
                    errorWidget: (context, url, error) => Icon(
                      Icons.music_note,
                      size: 50,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  );
                },
                loading: () => Container(color: Colors.grey[900]),
                error: (_, __) => Container(
                  color: Colors.grey[900],
                  child: const Icon(Icons.error),
                ),
              ),

              // Lyrics Overlay
              if (_showLyrics)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                      child: Container(
                        color:
                            (Theme.of(context).brightness == Brightness.dark
                                    ? Colors.black
                                    : Colors.white)
                                .withValues(alpha: 0.45),
                        child: _isLoadingLyrics
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              )
                            : _lyrics == null
                            ? Center(
                                child: Text(
                                  "No lyrics found",
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              )
                            : LyricsView(
                                lyrics: _lyrics!,
                                onClose: () =>
                                    setState(() => _showLyrics = false),
                                positionStream:
                                    audioHandler.player.positionStream,
                                totalDuration:
                                    audioHandler.player.duration ??
                                    Duration.zero,
                                isEmbedded: true,
                                accentColor:
                                    ref
                                        .watch(currentPaletteProvider)
                                        .asData
                                        ?.value
                                        ?.darkVibrantColor
                                        ?.color ??
                                    Colors.white,
                              ),
                      ),
                    ),
                  ),
                ),

              // Lyrics Button Overlay (Hide if lyrics are shown)
              if (!_showLyrics)
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              final mediaItem = mediaItemAsync.value;
                              if (mediaItem != null) {
                                setState(() {
                                  _showLyrics = true;
                                });
                                _fetchLyrics(mediaItem);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    FluentIcons.text_quote_20_filled,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Lyrics",
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
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
            ],
          ),
        ),
      ),
    );
  }
}
