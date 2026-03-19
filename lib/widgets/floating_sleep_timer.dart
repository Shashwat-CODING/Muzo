import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:muzo/providers/sleep_timer_provider.dart';
import 'package:muzo/widgets/sleep_timer_dialog.dart';

class FloatingSleepTimer extends ConsumerStatefulWidget {
  const FloatingSleepTimer({super.key});

  @override
  ConsumerState<FloatingSleepTimer> createState() => _FloatingSleepTimerState();
}

class _FloatingSleepTimerState extends ConsumerState<FloatingSleepTimer> {
  Offset _position = const Offset(20, 100);

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final hours = d.inHours.toString();
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = ref.watch(sleepTimerProvider);
    if (remaining == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;

    // Clamp position to screen bounds
    final clampedX = _position.dx.clamp(0.0, screenSize.width - 140);
    final clampedY = _position.dy.clamp(
      MediaQuery.of(context).padding.top + 8,
      screenSize.height - 200,
    );

    return Positioned(
      left: clampedX,
      top: clampedY,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              _position.dx + details.delta.dx,
              _position.dy + details.delta.dy,
            );
          });
        },
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => const SleepTimerDialog(),
          );
        },
        child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.12),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      FluentIcons.timer_24_filled,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(remaining),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        ref.read(sleepTimerProvider.notifier).cancelTimer();
                      },
                      child: Icon(
                        FluentIcons.dismiss_circle_24_filled,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ),
    );
  }
}
