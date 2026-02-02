import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import 'player/standard_player.dart';
import 'player/components/up_next_queue.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final PanelController _panelController = PanelController();
  bool _isPanelClosed = true;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

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
