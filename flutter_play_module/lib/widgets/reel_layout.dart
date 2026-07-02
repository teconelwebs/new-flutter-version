import 'dart:math' as math;

import 'package:flutter/material.dart';

class ReelLayoutMetrics {
  final double screenHeight;
  final double screenWidth;
  final EdgeInsets padding;
  final double safeTop;
  final double safeBottom;
  final double safeLeft;
  final double safeRight;
  final double productStripHeight;
  final double actionsBottom;
  final double userInfoBottom;
  final double progressBarBottom;
  final double productStripBottom;
  final double rightGutter;

  static const progressBarZone = 12.0;

  const ReelLayoutMetrics({
    required this.screenHeight,
    required this.screenWidth,
    required this.padding,
    required this.safeTop,
    required this.safeBottom,
    required this.safeLeft,
    required this.safeRight,
    required this.productStripHeight,
    required this.actionsBottom,
    required this.userInfoBottom,
    required this.progressBarBottom,
    required this.productStripBottom,
    required this.rightGutter,
  });

  /// Combines persistent [viewPadding] with transient [padding] so gesture nav,
  /// 3-button nav, notch, and status bar are all respected per device.
  factory ReelLayoutMetrics.of(BuildContext context, {required bool productStripOpen}) {
    final media = MediaQuery.of(context);
    final h = media.size.height;
    final w = media.size.width;

    final safeTop = math.max(media.viewPadding.top, media.padding.top);
    var safeBottom = math.max(media.viewPadding.bottom, media.padding.bottom);
    final safeLeft = math.max(media.viewPadding.left, media.padding.left);
    final safeRight = math.max(media.viewPadding.right, media.padding.right);

    // Fallback when Android reports 0 (rare legacy / misconfigured window).
    if (safeBottom < 8) safeBottom = 8;

    final pad = EdgeInsets.fromLTRB(safeLeft, safeTop, safeRight, safeBottom);
    final usable = math.max(h - safeTop - safeBottom, 240.0);

    const stripH = 128.0;
    final stripVisible = productStripOpen ? stripH + 8 : 0.0;

    // Progress line sits just above gesture / 3-button nav (matches RN Play tab).
    final progressBarBottom = math.max(safeBottom + 6, 12.0);
    final productStripBottom = progressBarBottom + progressBarZone + 2;

    // Keep overlays above progress + optional product strip.
    final bottomStack = stripVisible + productStripBottom;
    final actionsBottom = (bottomStack + 36).clamp(usable * 0.16, usable * 0.44);
    final userInfoBottom = bottomStack + 6;

    return ReelLayoutMetrics(
      screenHeight: h,
      screenWidth: w,
      padding: pad,
      safeTop: safeTop,
      safeBottom: safeBottom,
      safeLeft: safeLeft,
      safeRight: safeRight,
      productStripHeight: stripH,
      actionsBottom: actionsBottom,
      userInfoBottom: userInfoBottom,
      progressBarBottom: progressBarBottom,
      productStripBottom: productStripBottom,
      rightGutter: 72 + safeRight * 0.25,
    );
  }
}

TextStyle reelOverlayText([double size = 13]) => TextStyle(
      color: Colors.white,
      fontSize: size,
      shadows: reelOverlayTextShadows,
    );

const reelOverlayTextShadows = [
  Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 1)),
];

const reelOverlayBoxShadow = [
  BoxShadow(color: Color(0x8A000000), blurRadius: 6, offset: Offset(0, 1)),
];

/// White action icons stay readable on bright video frames.
Widget reelOverlayIcon(
  IconData icon, {
  Color color = Colors.white,
  double size = 30,
}) {
  return Stack(
    alignment: Alignment.center,
    clipBehavior: Clip.none,
    children: [
      Transform.translate(
        offset: const Offset(0, 0.8),
        child: Icon(
          icon,
          color: Colors.black.withValues(alpha: 0.5),
          size: size,
        ),
      ),
      Icon(icon, color: color, size: size),
    ],
  );
}
