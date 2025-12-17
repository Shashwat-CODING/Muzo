import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/services/lyrics_service.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

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
  bool showSynced = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: widget.isEmbedded 
        ? BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          )
        : null,
      child: Column(
        children: [
          // Header
          if (widget.isEmbedded)
            Padding(
              padding: const EdgeInsets.all(16.0),
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
                  Row(
                    children: [
                      if (widget.lyrics.syncedLyrics.isNotEmpty)
                        _buildToggleBtn("Synced", showSynced, () => setState(() => showSynced = true)),
                      const SizedBox(width: 8),
                      _buildToggleBtn("Plain", !showSynced, () => setState(() => showSynced = false)),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: widget.onClose,
                      ),
                    ],
                  )
                ],
              ),
            ),
          
          // Separate toggle for non-embedded view
          if (!widget.isEmbedded && widget.lyrics.syncedLyrics.isNotEmpty)
             Padding(
               padding: const EdgeInsets.symmetric(vertical: 16.0),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   _buildToggleBtn("Synced", showSynced, () => setState(() => showSynced = true)),
                   const SizedBox(width: 12),
                   _buildToggleBtn("Plain", !showSynced, () => setState(() => showSynced = false)),
                 ],
               ),
             ),
          
          Expanded(
             child: showSynced && widget.lyrics.syncedLyrics.isNotEmpty
                 ? _buildSyncedLyrics()
                 : _buildPlainLyrics(),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPlainLyrics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Text(
        widget.lyrics.plainLyrics,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          height: 1.6,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  int _currentIndex = 0;

  Widget _buildSyncedLyrics() {
    final lines = _parseSyncedLyrics(widget.lyrics.syncedLyrics);

    return StreamBuilder<Duration>(
      stream: widget.positionStream,
      builder: (context, snapshot) {
        final currentPosition = snapshot.data ?? Duration.zero;
        
        // Find current line index
        int newIndex = 0;
        for (int i = 0; i < lines.length; i++) {
          if (currentPosition >= lines[i].time) {
            newIndex = i;
          } else {
            break; 
          }
        }
        
        if (newIndex != _currentIndex) {
          _currentIndex = newIndex;
          // Scroll to center
          if (_itemScrollController.isAttached) {
             _itemScrollController.scrollTo(
               index: newIndex,
               duration: const Duration(milliseconds: 300),
               curve: Curves.easeInOut,
               alignment: 0.5, // Center
             );
          }
        }
        
        return ScrollablePositionedList.builder(
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
          itemCount: lines.length,
          itemBuilder: (context, index) {
            final isCurrent = index == _currentIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                lines[index].text,
                style: TextStyle(
                  color: isCurrent 
                    ? Colors.white 
                    : Colors.white.withValues(alpha: 0.6),
                  fontSize: isCurrent ? 24 : 18,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            );
          },
        );
      },
    );
  }

  List<LyricLine> _parseSyncedLyrics(String lrc) {
    final lines = <LyricLine>[];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2})\](.*)');
    for (final line in lrc.split('\n')) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final milliseconds = int.parse(match.group(3)!) * 10;
        final text = match.group(4)!.trim();
        if (text.isNotEmpty) {
           lines.add(LyricLine(
             time: Duration(minutes: minutes, seconds: seconds, milliseconds: milliseconds),
             text: text,
           ));
        }
      }
    }
    return lines;
  }
}

class LyricLine {
  final Duration time;
  final String text;
  LyricLine({required this.time, required this.text});
}
