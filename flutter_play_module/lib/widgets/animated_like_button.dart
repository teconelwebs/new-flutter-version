import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'reel_layout.dart';

/// Unique animated like button for Play reels.
/// Features a tactile spring-pop scale, radial particle burst ring, and gradient glow.
class AnimatedLikeButton extends StatefulWidget {
  final bool isLiked;
  final int count;
  final VoidCallback onTap;

  const AnimatedLikeButton({
    super.key,
    required this.isLiked,
    required this.count,
    required this.onTap,
  });

  @override
  State<AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<AnimatedLikeButton>
    with TickerProviderStateMixin {
  late final AnimationController _popController;
  late final AnimationController _burstController;

  late final Animation<double> _scaleAnimation;
  late final Animation<double> _burstAnimation;

  @override
  void initState() {
    super.initState();

    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.45)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.45, end: 0.9)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.9, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_popController);

    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _burstAnimation = CurvedAnimation(
      parent: _burstController,
      curve: Curves.decelerate,
    );
  }

  @override
  void didUpdateWidget(AnimatedLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked && !oldWidget.isLiked) {
      _popController.forward(from: 0.0);
      _burstController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _popController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.isLiked) {
      _popController.forward(from: 0.0);
      _burstController.forward(from: 0.0);
    }
    widget.onTap();
  }

  String _formatCount(int n) {
    if (n <= 0) return '0';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Radial particle burst ring
                  AnimatedBuilder(
                    animation: _burstAnimation,
                    builder: (context, _) {
                      if (_burstAnimation.value <= 0.0 ||
                          _burstAnimation.value >= 1.0) {
                        return const SizedBox.shrink();
                      }
                      return CustomPaint(
                        size: const Size(50, 50),
                        painter: _ParticleBurstPainter(
                          progress: _burstAnimation.value,
                        ),
                      );
                    },
                  ),
                  // Heart icon with spring scale
                  AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      final scale = _popController.isAnimating
                          ? _scaleAnimation.value
                          : 1.0;
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        if (widget.isLiked) {
                          return const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFFF2D55),
                              Color(0xFFFF0055),
                            ],
                          ).createShader(bounds);
                        }
                        return const LinearGradient(
                          colors: [Colors.white, Colors.white],
                        ).createShader(bounds);
                      },
                      child: Icon(
                        widget.isLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            // Like count label
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: Text(
                _formatCount(widget.count),
                key: ValueKey<int>(widget.count),
                style: reelOverlayText(11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for the radial particle burst effect around the heart
class _ParticleBurstPainter extends CustomPainter {
  final double progress;

  _ParticleBurstPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const count = 7;
    final maxRadius = size.width * 0.75;
    final radius = maxRadius * progress;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    const colors = [
      Color(0xFFFF2D55),
      Color(0xFFFF9500),
      Color(0xFFFF0055),
      Color(0xFFFF3B30),
      Color(0xFFFFD60A),
    ];

    for (int i = 0; i < count; i++) {
      final angle = (i * 2 * math.pi / count) - (math.pi / 2);
      final offset = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      final particleSize = (3.5 * (1.0 - progress * 0.5)).clamp(1.0, 4.0);
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(offset, particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleBurstPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
