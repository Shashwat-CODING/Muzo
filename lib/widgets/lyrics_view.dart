import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:muzo/services/lyrics_service.dart';
import 'package:muzo/widgets/karaoke_view.dart';
import 'package:google_fonts/google_fonts.dart';

class LyricsView extends ConsumerStatefulWidget {
  final Lyrics lyrics;
  final VoidCallback onClose;
  final Stream<Duration> positionStream;
  final Duration totalDuration;
  final bool isEmbedded;
  final bool scrollable;
  final Color? accentColor;

  const LyricsView({
    super.key,
    required this.lyrics,
    required this.onClose,
    required this.positionStream,
    required this.totalDuration,
    this.isEmbedded = true,
    this.scrollable = true,
    this.accentColor,
  });

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  late LyricController _lyricController;
  StreamSubscription<Duration>? _positionSubscription;

  bool get _isKaraoke => widget.lyrics.karaokeLines != null;

  @override
  void initState() {
    super.initState();

    if (!_isKaraoke) {
      _lyricController = LyricController();
      if (widget.lyrics.syncedLyrics.isNotEmpty) {
        _lyricController.loadLyric(widget.lyrics.syncedLyrics);
      } else {
        _lyricController.loadLyric(widget.lyrics.plainLyrics);
      }
      _positionSubscription = widget.positionStream.listen((duration) {
        _lyricController.setProgress(duration);
      });
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    if (!_isKaraoke) _lyricController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customLyricStyle = LyricStyles.default1.copyWith(
      activeHighlightColor: Colors.white,
      activeStyle: GoogleFonts.outfit(
        fontSize: widget.isEmbedded ? 22 : 26,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        height: 1.3,
        shadows: [
          Shadow(
            offset: const Offset(0, 2),
            blurRadius: 10.0,
            color: Colors.black.withValues(alpha: 0.3),
          ),
        ],
      ),
      textStyle: GoogleFonts.outfit(
        fontSize: widget.isEmbedded ? 17 : 20,
        fontWeight: FontWeight.w700,
        color: Colors.white.withValues(alpha: 0.3),
        height: 1.3,
        shadows: [
          Shadow(
            offset: const Offset(0, 1),
            blurRadius: 2.0,
            color: Colors.black.withValues(alpha: 0.1),
          ),
        ],
      ),
      translationStyle: GoogleFonts.outfit(
        fontSize: widget.isEmbedded ? 14 : 16,
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
          child: _isKaraoke
              ? KaraokeView(
                  lines: widget.lyrics.karaokeLines!,
                  positionStream: widget.positionStream,
                  isEmbedded: widget.isEmbedded,
                  scrollable: widget.scrollable,
                )
              : widget.scrollable
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 14.0),
                      child: LyricView(
                        controller: _lyricController,
                        style: customLyricStyle,
                      ),
                    )
                  : AbsorbPointer(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 14.0),
                        child: LyricView(
                          controller: _lyricController,
                          style: customLyricStyle,
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}
