import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GlobalBackground extends ConsumerWidget {
  final Widget child;

  const GlobalBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        // Dynamic Gradient Background
        Consumer(
          builder: (context, ref, child) {
            final theme = Theme.of(context);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              color: theme.scaffoldBackgroundColor,
            );
          },
        ),

        // Content
        child,
      ],
    );
  }
}
