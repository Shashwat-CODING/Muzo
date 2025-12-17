import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import 'player/components/gesture_player.dart';
import 'player/standard_player.dart';
import 'player/components/up_next_queue.dart';

import '../providers/player_provider.dart';

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
        body: SlidingUpPanel(
          controller: _panelController,
          boxShadow: const [],
          minHeight: 65 + MediaQuery.of(context).padding.bottom, 
          maxHeight: size.height,
          color: Colors.transparent,
          
          onPanelOpened: () {
            setState(() {
              _isPanelClosed = false;
            });
          },
          onPanelClosed: () {
            setState(() {
              _isPanelClosed = true;
            });
          },
          
          collapsed: InkWell(
            onTap: () {
              _panelController.open();
            },
            child: Container(
              color: Colors.black, 
              child: Column(
                children: [
                  SizedBox(
                    height: 65,
                    child: Center(
                      child: Icon(
                        FluentIcons.chevron_up_24_regular,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          panelBuilder: (ScrollController sc) {
             return ClipRRect(
               borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
               child: BackdropFilter(
                 filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                 child: Container(
                   color: Colors.black.withOpacity(0.6),
                   child: Stack(
                     children: [
                       UpNextQueue(
                         scrollController: sc,
                         onReorderStart: (oldIndex, newIndex) {},
                         onReorderEnd: (index) {},
                       ),
                       Positioned(
                         top: 10,
                         right: 10,
                         child: SafeArea(
                           child: IconButton(
                             icon: const Icon(FluentIcons.chevron_down_24_regular, color: Colors.white),
                             onPressed: () => _panelController.close(),
                           ),
                         ),
                       )
                     ],
                   ),
                 ),
               ),
             );
          },
          
          body: const StandardPlayer(),
        ),
      ),
    );
  }
}

class ExpandedPlayer extends PlayerScreen {
  const ExpandedPlayer({super.key});
}
