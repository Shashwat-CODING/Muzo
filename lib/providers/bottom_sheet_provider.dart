import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/models/muzo_item.dart';

class BottomSheetState {
  final bool isVisible;
  final MuzoItem? result;
  final bool fromHistory;
  final bool fromPlayer;

  const BottomSheetState({
    this.isVisible = false,
    this.result,
    this.fromHistory = false,
    this.fromPlayer = false,
  });

  BottomSheetState copyWith({
    bool? isVisible,
    MuzoItem? result,
    bool? fromHistory,
    bool? fromPlayer,
  }) {
    return BottomSheetState(
      isVisible: isVisible ?? this.isVisible,
      result: result ?? this.result,
      fromHistory: fromHistory ?? this.fromHistory,
      fromPlayer: fromPlayer ?? this.fromPlayer,
    );
  }
}

class BottomSheetNotifier extends StateNotifier<BottomSheetState> {
  BottomSheetNotifier() : super(const BottomSheetState());

  void show(
    MuzoItem result, {
    bool fromHistory = false,
    bool fromPlayer = false,
  }) {
    state = BottomSheetState(
      isVisible: true,
      result: result,
      fromHistory: fromHistory,
      fromPlayer: fromPlayer,
    );
  }

  void hide() {
    state = const BottomSheetState(isVisible: false);
  }
}

final bottomSheetProvider =
    StateNotifierProvider<BottomSheetNotifier, BottomSheetState>((ref) {
      return BottomSheetNotifier();
    });
