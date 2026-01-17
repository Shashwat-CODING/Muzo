import 'package:flutter/material.dart';
import 'package:muzo/widgets/glass_container.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/providers/settings_provider.dart';

class GlassMenuContent extends ConsumerWidget {
  final List<Widget> children;
  final double width;

  const GlassMenuContent({super.key, required this.children, this.width = 220});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLiteMode = ref.watch(settingsProvider).isLiteMode;

    if (isLiteMode) {
      return SizedBox(
        width: width,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E), // Solid background
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      child: GlassContainer(
        blur: 15,
        opacity: 0.1,
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}
