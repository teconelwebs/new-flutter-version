import 'package:flutter/material.dart';

/// Shared profile / edit-profile styling (light surfaces on dark app root).
class ProfileColors {
  static const primary = Color(0xFFfb5204);
  static const primaryLight = Color(0xFFFF8C00);
  static const textPrimary = Color(0xFF111111);
  static const textSecondary = Color(0xFF444444);
  static const textMuted = Color(0xFF666666);
  static const textHint = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const surface = Color(0xFFF9FAFB);
  static const divider = Color(0xFFE5E5E5);
}

InputDecoration profileInputDecoration({
  String? hint,
  String? errorText,
}) {
  const radius = BorderRadius.all(Radius.circular(10));
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: ProfileColors.textHint, fontSize: 15),
    filled: true,
    fillColor: ProfileColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    counterText: '',
    errorText: errorText,
    border: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: ProfileColors.border)),
    enabledBorder: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: ProfileColors.border)),
    focusedBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: ProfileColors.primary, width: 1.5),
    ),
    errorBorder: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: Colors.red)),
    focusedErrorBorder: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: Colors.red)),
  );
}

const profileFieldTextStyle = TextStyle(
  color: ProfileColors.textPrimary,
  fontSize: 15,
  fontWeight: FontWeight.w500,
);

const profileLabelStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: ProfileColors.textSecondary,
);
