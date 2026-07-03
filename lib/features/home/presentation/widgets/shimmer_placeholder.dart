import 'package:flutter/material.dart';

class ShimmerPlaceholder extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final List<Color> shimmerColors;
  final Duration duration;

  const ShimmerPlaceholder({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shimmerColors = const [Color(0xFFEBEBEB), Color(0xFFD4D4D4), Color(0xFFEBEBEB)],
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
            gradient: LinearGradient(
              colors: widget.shimmerColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(slidePercent: _controller.value),
            ),
          ),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final double translation = bounds.width * (slidePercent - 0.5) * 2;
    return Matrix4.translationValues(translation, 0.0, 0.0);
  }
}
