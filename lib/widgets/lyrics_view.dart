import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:muzo/services/lyrics_service.dart';
import 'package:muzo/widgets/karaoke_view.dart';

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
  bool get _isSynced => widget.lyrics.syncedLyrics.trim().isNotEmpty;
  bool get _hasPlainLyrics => widget.lyrics.plainLyrics.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();

    if (!_isKaraoke && _isSynced) {
      _lyricController = LyricController();
      _lyricController.loadLyric(widget.lyrics.syncedLyrics);
      _positionSubscription = widget.positionStream.listen((duration) {
        _lyricController.setProgress(duration);
      });
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    if (!_isKaraoke && _isSynced) {
      _lyricController.dispose();
    }
    super.dispose();
  }

  Widget _buildFallbackView(BuildContext context, String? fontFamily, {required bool isInstrumental}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isInstrumental ? Icons.music_note_rounded : Icons.text_snippet_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            isInstrumental ? "Instrumental" : "No lyrics available",
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: widget.isEmbedded ? 18 : 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlainLyricsView(BuildContext context, String? fontFamily) {
    final List<String> rawLines = widget.lyrics.plainLyrics.split('\n');
    final double fontSize = widget.isEmbedded ? 18.0 : 22.0;

    return ShaderMask(
      shaderCallback: (rect) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0.0, 0.08, 0.92, 1.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        physics: widget.scrollable
            ? const BouncingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: 24,
          vertical: widget.isEmbedded ? 24 : 40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: widget.isEmbedded ? 12 : 24),
            ...rawLines.map((line) {
              final trimmed = line.trim();
              if (trimmed.isEmpty) {
                return const SizedBox(height: 20);
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Text(
                  trimmed,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
              );
            }),
            SizedBox(height: widget.isEmbedded ? 24 : 48),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;

    final customLyricStyle = LyricStyles.default1.copyWith(
      disableTouchEvent: !widget.scrollable,
      activeHighlightColor: Theme.of(context).colorScheme.onSurface,
      activeStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: widget.isEmbedded ? 22 : 26,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface,
        height: 1.3,
      ),
      textStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: widget.isEmbedded ? 17 : 20,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
        height: 1.3,
      ),
      translationStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: widget.isEmbedded ? 14 : 16,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
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
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface),
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
              : (widget.lyrics.instrumental || !_hasPlainLyrics
                  ? _buildFallbackView(context, fontFamily, isInstrumental: widget.lyrics.instrumental)
                  : (!_isSynced
                      ? _buildPlainLyricsView(context, fontFamily)
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 14.0),
                          child: LyricView(
                            controller: _lyricController,
                            style: customLyricStyle,
                          ),
                        ))),
        ),
      ],
    );
  }
}
