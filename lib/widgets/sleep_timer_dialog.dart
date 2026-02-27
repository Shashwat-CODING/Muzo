import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/providers/sleep_timer_provider.dart';
import 'package:muzo/widgets/glass_snackbar.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: (Theme.of(context).brightness == Brightness.dark
                      ? Colors.black
                      : Colors.white)
                  .withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sleep Timer',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    if (currentTimer != null)
                      Text(
                        '${currentTimer.inMinutes}:${(currentTimer.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: _presetMinutes.map((mins) {
                    return _buildTimerButton(context, '$mins min', () => _setTimer(mins));
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Custom (min)',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _customMinutes = int.tryParse(val);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _customMinutes != null && _customMinutes! > 0
                          ? () => _setTimer(_customMinutes!)
                          : null,
                      child: const Text('Set'),
                    ),
                  ],
                ),
                if (currentTimer != null) ...[
                  const SizedBox(height: 20),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    onPressed: _cancelTimer,
                    icon: const Icon(FluentIcons.dismiss_24_regular),
                    label: const Text('Cancel Timer'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerButton(BuildContext context, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
