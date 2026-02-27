import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/providers/player_provider.dart';

final sleepTimerProvider = StateNotifierProvider<SleepTimerNotifier, Duration?>((ref) {
  return SleepTimerNotifier(ref);
});

class SleepTimerNotifier extends StateNotifier<Duration?> {
  final Ref _ref;
  Timer? _timer;
  DateTime? _endTime;

  SleepTimerNotifier(this._ref) : super(null);

  void startTimer(Duration duration) {
    _timer?.cancel();
    _endTime = DateTime.now().add(duration);
    
    // Update state to the remaining duration
    state = duration;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_endTime == null) {
        timer.cancel();
        return;
      }
      
      final remaining = _endTime!.difference(DateTime.now());
      if (remaining.isNegative) {
        timer.cancel();
        _endTime = null;
        state = null;
        
        // Pause the player when timer expires
        final audioHandler = _ref.read(audioHandlerProvider);
        audioHandler.pause();
      } else {
        state = remaining;
      }
    });
  }

  void cancelTimer() {
    _timer?.cancel();
    _timer = null;
    _endTime = null;
    state = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
