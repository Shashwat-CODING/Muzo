import 'package:flutter/material.dart';

class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine base color based on brightness, assuming dark theme mostly
    final baseColor = Colors.grey[850]!;
    final highlightColor = Colors.grey[700]!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

class HomeSkeletonSection extends StatelessWidget {
  const HomeSkeletonSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: SkeletonLoader(width: 200, height: 24, borderRadius: 4),
        ),
        SizedBox(
          height: 180,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonLoader(
                    width: 140,
                    height: 140,
                    borderRadius: 12,
                  ),
                  const SizedBox(height: 8),
                  const SkeletonLoader(width: 120, height: 14, borderRadius: 4),
                  const SizedBox(height: 4),
                  const SkeletonLoader(width: 80, height: 12, borderRadius: 4),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class HomeSkeletonList extends StatelessWidget {
  const HomeSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (index) => const HomeSkeletonSection()),
    );
  }
}
