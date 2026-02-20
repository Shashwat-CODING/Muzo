import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:muzo/services/lyrics_service.dart';
import 'package:google_fonts/google_fonts.dart';

class LyricsView extends ConsumerStatefulWidget {
  final Lyrics lyrics;
  final VoidCallback onClose;
  final Stream<Duration> positionStream;
  final Duration totalDuration;
  final bool isEmbedded;
  final Color? accentColor;

  const LyricsView({
    super.key,
    required this.lyrics,
    required this.onClose,
    required this.positionStream,
    required this.totalDuration,
    this.isEmbedded = true,
    this.accentColor,
  });

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  late LyricController _lyricController;
  StreamSubscription<Duration>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _lyricController = LyricController();

    // Load lyrics
    if (widget.lyrics.syncedLyrics.isNotEmpty) {
      _lyricController.loadLyric(widget.lyrics.syncedLyrics);
    } else {
      _lyricController.loadLyric(widget.lyrics.plainLyrics);
    }

    _positionSubscription = widget.positionStream.listen((duration) {
      _lyricController.setProgress(duration);
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _lyricController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use accent color from album art, fallback to white
    final activeColor = widget.accentColor ?? Colors.white;

    final customLyricStyle = LyricStyles.default1.copyWith(
      activeHighlightColor: Colors.white, // Pure white for legibility
      activeStyle: GoogleFonts.outfit(
        fontSize: widget.isEmbedded ? 34 : 40, // Increased size for better visibility
        fontWeight: FontWeight.w800,
        color: Colors.white,
        height: 1.3,
        shadows: [
          Shadow(
            offset: const Offset(0, 2),
            blurRadius: 10.0,
            color: Colors.black.withValues(alpha: 0.3), // Stronger shadow
          ),
        ],
      ),
      textStyle: GoogleFonts.outfit(
        fontSize: widget.isEmbedded ? 24 : 28,
        fontWeight: FontWeight.w700,
        color: Colors.white.withValues(alpha: 0.3), // Liquid glass look (more translucent)
        height: 1.3,
         shadows: [
          Shadow(
            offset: const Offset(0, 1),
            blurRadius: 2.0,
            color: Colors.black.withValues(alpha: 0.1), // Very soft shadow so it blends
          ),
        ],
      ),
      translationStyle: GoogleFonts.outfit(
        fontSize: widget.isEmbedded ? 18 : 22,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.6),
         shadows: [
          Shadow(
            offset: const Offset(0, 1),
            blurRadius: 5.0,
            color: Colors.black.withValues(alpha: 0.2),
          ),
        ],
      ),
    );

    return Column(
      children: [
        if (widget.isEmbedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Lyrics",
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: LyricView(
              controller: _lyricController,
              style: customLyricStyle,
            ),
          ),
        ),
      ],
    );
  }
}
