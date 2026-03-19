import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import 'player/standard_player.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final bool _isPanelClosed = true;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: const Key('player_dismiss'),
      direction: _isPanelClosed ? DismissDirection.down : DismissDirection.none,
      onDismissed: (_) {
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: const StandardPlayer(),
      ),
    );
  }
}

class ExpandedPlayer extends PlayerScreen {
  const ExpandedPlayer({super.key});
}
