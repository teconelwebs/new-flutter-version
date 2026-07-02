import 'package:flutter/material.dart';

/// Thin playback progress line (Instagram-style) above the gesture nav area.
class ReelProgressBar extends StatelessWidget {
  final double progress;
  final bool visible;
  final ValueChanged<double>? onSeekStart;
  final ValueChanged<double>? onSeekUpdate;
  final VoidCallback? onSeekEnd;

  const ReelProgressBar({
    super.key,
    required this.progress,
    required this.visible,
    this.onSeekStart,
    this.onSeekUpdate,
    this.onSeekEnd,
  });

  static const trackHeight = 2.5;
  static const activeColor = Color(0xFFfb5404);
  static const trackColor = Color(0x33FFFFFF);

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final value = progress.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: onSeekStart == null
              ? null
              : (_) => onSeekStart!(value),
          onHorizontalDragUpdate: onSeekUpdate == null
              ? null
              : (details) {
                  if (width <= 0) return;
                  final next = (details.localPosition.dx / width).clamp(0.0, 1.0);
                  onSeekUpdate!(next);
                },
          onHorizontalDragEnd: onSeekEnd == null ? null : (_) => onSeekEnd!(),
          onTapDown: onSeekUpdate == null
              ? null
              : (details) {
                  if (width <= 0) return;
                  final next = (details.localPosition.dx / width).clamp(0.0, 1.0);
                  onSeekStart?.call(next);
                  onSeekUpdate!(next);
                  onSeekEnd?.call();
                },
          child: SizedBox(
            height: 12,
            width: double.infinity,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(trackHeight),
                child: SizedBox(
                  height: trackHeight,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: trackColor),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value,
                        child: const ColoredBox(color: activeColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
