import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/providers/sleep_timer_provider.dart';
import 'package:muzo/widgets/glass_snackbar.dart';

class SleepTimerDialog extends ConsumerStatefulWidget {
  const SleepTimerDialog({super.key});

  @override
  ConsumerState<SleepTimerDialog> createState() => _SleepTimerDialogState();
}

class _SleepTimerDialogState extends ConsumerState<SleepTimerDialog> {
  final List<int> _presetMinutes = [5, 10, 20, 30, 40, 50, 60];
  int? _customMinutes;
  final TextEditingController _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _setTimer(int minutes) {
    ref.read(sleepTimerProvider.notifier).startTimer(Duration(minutes: minutes));
    if (context.mounted) {
      Navigator.of(context).pop();
      showGlassSnackBar(context, 'Sleep timer set for $minutes minutes');
    }
  }

  void _cancelTimer() {
    ref.read(sleepTimerProvider.notifier).cancelTimer();
    if (context.mounted) {
      Navigator.of(context).pop();
      showGlassSnackBar(context, 'Sleep timer cancelled');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTimer = ref.watch(sleepTimerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dividerCol = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 44, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E).withValues(alpha: 0.65) : const Color(0xFFE5E5EA).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sleep Timer',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.4,
                        ),
                      ),
                      if (currentTimer != null)
                        Text(
                          '${currentTimer.inMinutes}:${(currentTimer.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.start,
                    children: _presetMinutes.map((mins) {
                      return _buildTimerButton(context, '$mins min', () => _setTimer(mins));
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          controller: _customController,
                          keyboardType: TextInputType.number,
                          placeholder: 'Custom (minutes)',
                          placeholderStyle: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                            fontSize: 14,
                          ),
                          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                              width: 0.8,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          onChanged: (val) {
                            setState(() {
                              _customMinutes = int.tryParse(val);
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _customMinutes != null && _customMinutes! > 0
                            ? () => _setTimer(_customMinutes!)
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: _customMinutes != null && _customMinutes! > 0
                                ? theme.primaryColor
                                : theme.primaryColor.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Set',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 0.5, color: dividerCol),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          ),
                          child: Text(
                            'Dismiss',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 17,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (currentTimer != null) ...[
                      Container(width: 0.5, height: 44, color: dividerCol),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: TextButton(
                            onPressed: _cancelTimer,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                            ),
                            child: const Text(
                              'Cancel Timer',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerButton(BuildContext context, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}
