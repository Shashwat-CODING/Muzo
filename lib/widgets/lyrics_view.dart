import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:muzo/services/lyrics_service.dart';

class LyricsView extends ConsumerStatefulWidget {
  final Lyrics lyrics;
  final VoidCallback onClose;
  final Stream<Duration> positionStream;
  final Duration totalDuration;
  final bool isEmbedded;

  const LyricsView({
    super.key, 
    required this.lyrics, 
    required this.onClose,
    required this.positionStream,
    required this.totalDuration,
    this.isEmbedded = true,
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
    return Container(
      child: Column(
        children: [
          if (widget.isEmbedded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const Text(
                    "Lyrics",
                    style: TextStyle(
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
               style: LyricStyles.default1, // Use preset directly
            ),
          ),
        ],
      ),
    );
  }
}
