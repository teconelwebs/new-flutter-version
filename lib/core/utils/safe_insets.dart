import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Persistent system bottom inset (Android 3-button / gesture nav, iOS home indicator).
///
/// Prefer this over [MediaQueryData.padding] alone: on Android edge-to-edge,
/// `padding.bottom` can be `0` while `viewPadding.bottom` still has the nav bar.
double systemBottomInset(BuildContext context) {
  final mq = MediaQuery.of(context);
  return math.max(mq.viewPadding.bottom, mq.padding.bottom);
}

/// Ensures [MediaQueryData.padding.bottom] always includes the system nav bar
/// when the keyboard is closed. Apply once at [MaterialApp.builder] so
/// SafeArea / padding.bottom / sticky CTAs track Android bottom buttons app-wide.
MediaQueryData ensureSystemBottomPadding(MediaQueryData mq) {
  if (mq.viewInsets.bottom > 0) return mq;
  if (mq.viewPadding.bottom <= mq.padding.bottom) return mq;
  return mq.copyWith(
    padding: mq.padding.copyWith(bottom: mq.viewPadding.bottom),
  );
}
