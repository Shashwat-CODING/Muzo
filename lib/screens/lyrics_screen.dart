import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:muzo/services/lyrics_service.dart';
import 'package:muzo/widgets/lyrics_view.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/providers/settings_provider.dart';
import 'dart:ui';

class LyricsScreen extends ConsumerStatefulWidget {
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final int durationSeconds;

  const LyricsScreen({
    super.key,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    required this.durationSeconds,
  });

  @override
  ConsumerState<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends ConsumerState<LyricsScreen> {
  Lyrics? _lyrics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLyrics();
  }

  Future<void> _fetchLyrics() async {
    try {
      final lyrics = await ref.read(lyricsServiceProvider).fetchLyrics(
        widget.title, 
        widget.artist, 
        widget.durationSeconds
      );
      if (mounted) {
        setState(() {
          _lyrics = lyrics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final isLiteMode = ref.watch(settingsProvider).isLiteMode;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(FluentIcons.chevron_down_24_regular, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            const Text(
              "Lyrics",
              style: TextStyle(
                color: Colors.white, 
                fontSize: 16, 
                fontWeight: FontWeight.bold
              ),
            ),
             Text(
              "${widget.title} • ${widget.artist}",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), 
                fontSize: 12, 
                fontWeight: FontWeight.normal
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background Blur
          Positioned.fill(
             child: widget.thumbnailUrl != null
                 ? Image.network(
                     widget.thumbnailUrl!,
                     fit: BoxFit.cover,
                     errorBuilder: (_, __, ___) => Container(color: Colors.black),
                   )
                 : Container(color: Colors.black),
          ),
          Positioned.fill(
            child: isLiteMode 
              ? Container(
                  color: Colors.black.withValues(alpha: 0.85),
                ) 
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.7),
                  ),
                ),
          ),

          // Content
          SafeArea(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _lyrics == null
                ? _buildNotFound()
                : LyricsView(
                    lyrics: _lyrics!,
                    onClose: () {},
                    positionStream: audioHandler.player.positionStream,
                    totalDuration: audioHandler.player.duration ?? Duration.zero,
                    isEmbedded: false,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FluentIcons.text_quote_24_regular, size: 64, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 24),
          const Text(
            "Lyrics not found",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "We couldn't find lyrics for this song.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
