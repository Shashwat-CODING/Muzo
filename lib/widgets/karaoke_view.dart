import 'dart:async';
import 'package:flutter/material.dart';
import 'package:muzo/services/lyrics_service.dart';

/// Karaoke-style lyrics view.
/// Shows the full line; only the *current* word is bright white.
/// Past and future words render as liquid-glass (translucent).
class KaraokeView extends StatefulWidget {
  final List<KaraokeLine> lines;
  final Stream<Duration> positionStream;
  final bool isEmbedded;
  final bool scrollable;

  const KaraokeView({
    super.key,
    required this.lines,
    required this.positionStream,
    this.isEmbedded = true,
    this.scrollable = true,
  });

  @override
  State<KaraokeView> createState() => _KaraokeViewState();
}

class _KaraokeViewState extends State<KaraokeView> {
  StreamSubscription<Duration>? _sub;
  Duration _position = Duration.zero;
  int _activeLineIndex = -1;

  final ScrollController _scrollController = ScrollController();
  late final List<GlobalKey> _lineKeys;

  @override
  void initState() {
    super.initState();
    _lineKeys = List.generate(widget.lines.length, (_) => GlobalKey());
    _sub = widget.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() {
        _position = pos;
        _updateActiveLine();
      });
    });
  }

  void _updateActiveLine() {
    int newIndex = -1;
    for (int i = widget.lines.length - 1; i >= 0; i--) {
      if (_position >= widget.lines[i].lineStart) {
        newIndex = i;
        break;
      }
    }
    if (newIndex != _activeLineIndex) {
      _activeLineIndex = newIndex;
      _scrollToActiveLine();
    }
  }

  void _scrollToActiveLine() {
    if (_activeLineIndex < 0) return;
    final key = _lineKeys[_activeLineIndex];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.3,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double fontSize = widget.isEmbedded ? 22.0 : 26.0;

    return SingleChildScrollView(
      controller: _scrollController,
      physics: widget.scrollable
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(widget.lines.length, (index) {
          final line = widget.lines[index];
          final bool isActive = index == _activeLineIndex;
          final bool isPast = index < _activeLineIndex;

          return Padding(
            key: _lineKeys[index],
            padding: const EdgeInsets.only(bottom: 20),
            child: isActive
                ? _buildActiveLine(line, fontSize)
                : _buildInactiveLine(line, fontSize, isPast),
          );
        }),
      ),
    );
  }

  /// Active line: only the current syllable is bright white; all others liquid-glass.
  Widget _buildActiveLine(KaraokeLine line, double fontSize) {
    // Find which syllable is currently being sung
    int activeIdx = -1;
    for (int i = line.syllables.length - 1; i >= 0; i--) {
      final syl = line.syllables[i];
      if (_position >= syl.time) {
        // Check it hasn't ended yet (use next syllable start as end boundary)
        final Duration end = i < line.syllables.length - 1
            ? line.syllables[i + 1].time
            : syl.time + syl.duration;
        if (_position < end) {
          activeIdx = i;
        }
        break;
      }
    }

    final spans = <TextSpan>[];
    for (int i = 0; i < line.syllables.length; i++) {
      final syl = line.syllables[i];
      final bool isCurrent = i == activeIdx;

      spans.add(TextSpan(
        // API text already includes trailing space — do NOT trim it
        text: syl.text,
        style: TextStyle(
          fontSize: fontSize,
          // Keep weight FIXED at w700 for all words to prevent layout reflow
          fontWeight: FontWeight.w700,
          color: isCurrent
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          height: 1.35,
          shadows: isCurrent
              ? [Shadow(offset: const Offset(0, 2), blurRadius: 8, color: Colors.black.withValues(alpha: 0.3))]
              : null,
        ),
      ));
    }
    return Text.rich(TextSpan(children: spans));
  }

  /// Inactive lines: uniformly liquid-glass
  Widget _buildInactiveLine(KaraokeLine line, double fontSize, bool isPast) {
    return Text(
      line.fullText,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: isPast ? 0.18 : 0.28),
        height: 1.35,
      ),
    );
  }
}
