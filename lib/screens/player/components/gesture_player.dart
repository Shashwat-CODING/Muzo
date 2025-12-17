import 'package:flutter/material.dart';
import '../standard_player.dart';

class GesturePlayer extends StatelessWidget {
  const GesturePlayer({super.key});

  @override
  Widget build(BuildContext context) {
    // For now, just return StandardPlayer as fallback
    return const StandardPlayer();
  }
}
