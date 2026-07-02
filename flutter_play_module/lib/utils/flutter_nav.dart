import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Closes the Flutter Activity and returns to the React Native app.
void closeFlutterPlay() {
  SystemNavigator.pop();
}

const _navChannel = MethodChannel('welfog/nav');
const _playChannel = MethodChannel('welfog/play');

/// Notifies React Native that a play profile was created inside Flutter.
Future<void> notifyPlayProfileCreated(String playUserId, String username) async {
  try {
    await _playChannel.invokeMethod<void>('onPlayProfileCreated', {
      'playUserId': playUserId,
      'username': username,
    });
  } catch (_) {
    // Non-fatal — RN will resolve profile on next open.
  }
}

/// Opens a product in the React Native shop.
/// Native Android receives the slug, brings RN to front, and navigates to product detail.
Future<void> openProductInShop(String slug) async {
  if (slug.isEmpty) return;
  try {
    await _navChannel.invokeMethod<void>('openProduct', {'slug': slug});
  } catch (_) {
    // Native handler missing or bridge error — do not SystemNavigator.pop here,
    // that only returns to Account without opening the product page.
  }
}

final RouteObserver<PageRoute<dynamic>> appRouteObserver = RouteObserver<PageRoute<dynamic>>();

/// Dark status-bar icons (time, battery) for white/light screens.
const SystemUiOverlayStyle systemUiLightBackground = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.dark,
);

/// White status-bar icons for black/dark video screens.
const SystemUiOverlayStyle systemUiDarkBackground = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
);

Widget systemUiWrapper({
  required SystemUiOverlayStyle style,
  required Widget child,
}) {
  return AnnotatedRegion<SystemUiOverlayStyle>(value: style, child: child);
}

/// Black video/reels screens — white clock & battery icons.
Widget videoScreenWrapper({required Widget child}) {
  return systemUiWrapper(style: systemUiDarkBackground, child: child);
}

/// Light theme for profile / form screens (app root theme is dark).
ThemeData profileLightTheme() {
  return ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFfb5404),
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF1A1A1A),
      elevation: 0,
      surfaceTintColor: Colors.white,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF1A1A1A), fontSize: 15),
      bodyMedium: TextStyle(color: Color(0xFF333333), fontSize: 14),
      titleMedium: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w700, fontSize: 18),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      hintStyle: TextStyle(color: Colors.grey.shade500),
      labelStyle: const TextStyle(color: Color(0xFF555555), fontWeight: FontWeight.w600),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFfb5404), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
    ),
  );
}

Widget profileScreenWrapper({required Widget child}) {
  return Theme(
    data: profileLightTheme(),
    child: systemUiWrapper(style: systemUiLightBackground, child: child),
  );
}

/// Light theme wrapper for bottom sheets (app theme is dark).
Widget lightSheetWrapper({required Widget child}) {
  return Theme(
    data: profileLightTheme(),
    child: systemUiWrapper(style: systemUiLightBackground, child: child),
  );
}
