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
      activeHighlightColor: Colors.white,
      activeStyle: GoogleFonts.outfit(
        fontSize: 26, // Increased slightly for better focus
        fontWeight: FontWeight.bold,
        color: Colors.white,
        shadows: [
          Shadow(
            offset: const Offset(0, 1),
            blurRadius: 10.0,
            color: Colors.black.withOpacity(0.6),
          ),
        ],
      ),
      textStyle: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: activeColor.withOpacity(0.6),
         shadows: [
          Shadow(
            offset: const Offset(0, 1),
            blurRadius: 8.0,
            color: Colors.black.withOpacity(0.4),
          ),
        ],
      ),
      translationStyle: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: activeColor.withOpacity(0.4),
         shadows: [
          Shadow(
            offset: const Offset(0, 1),
            blurRadius: 8.0,
            color: Colors.black.withOpacity(0.4),
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
          child: LyricView(
            controller: _lyricController,
            style: customLyricStyle,
          ),
        ),
      ],
    );
  }
}
