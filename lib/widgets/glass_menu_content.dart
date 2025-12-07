import 'package:flutter/material.dart';
import 'package:ytx/widgets/glass_container.dart';

class GlassMenuContent extends StatelessWidget {
  final List<Widget> children;
  final double width;

  const GlassMenuContent({
    super.key,
    required this.children,
    this.width = 220,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: GlassContainer(
        blur: 15,
        opacity: 0.1,
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
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
