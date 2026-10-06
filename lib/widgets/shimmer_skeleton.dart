import 'package:flutter/material.dart';

class ShimmerSkeleton extends StatefulWidget {
  final double height;
  final double width;
  final BorderRadius? borderRadius;

  const ShimmerSkeleton({
    super.key,
    required this.height,
    required this.width,
    this.borderRadius,
  });

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final double slide = (_controller.value * 3) - 1; // -1 to 2
          return Container(
            height: widget.height,
            width: widget.width,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 + slide, 0),
                end: Alignment(0 + slide, 0),
                colors: [
                  Colors.grey[800]!,
                  Colors.grey[700]!,
                  Colors.grey[800]!,
                ],
                stops: const [0.2, 0.5, 0.8],
              ),
            ),
          );
        },
      ),
    );
  }
}


