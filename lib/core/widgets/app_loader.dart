import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class AppLoader extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;
  final bool isButtonLoader;
  final bool isPageLoader;

  // Welfog Logo Orange Color
  static const Color welfogOrange = Color(0xFFFB5404);

  const AppLoader({
    super.key,
    this.size = 24.0,
    this.strokeWidth = 2.2,
    this.color,
  })  : isButtonLoader = false,
        isPageLoader = false;

  const AppLoader.button({
    super.key,
    this.size = 16.0,
    this.strokeWidth = 1.8,
    this.color = Colors.white,
  })  : isButtonLoader = true,
        isPageLoader = false;

  const AppLoader.page({
    super.key,
    this.size = 28.0,
    this.strokeWidth = 2.5,
    this.color,
  })  : isButtonLoader = false,
        isPageLoader = true;

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? welfogOrange;
    final isIOS = !kIsWeb && Platform.isIOS;

    if (isPageLoader) {
      return Center(
        child: isIOS
            ? CupertinoActivityIndicator(
                color: themeColor,
                radius: size / 2,
              )
            : SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  strokeWidth: strokeWidth,
                  valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                ),
              ),
      );
    }

    if (isButtonLoader) {
      return SizedBox(
        width: size,
        height: size,
        child: isIOS
            ? CupertinoActivityIndicator(
                color: themeColor,
                radius: size / 2,
              )
            : CircularProgressIndicator(
                strokeWidth: strokeWidth,
                valueColor: AlwaysStoppedAnimation<Color>(themeColor),
              ),
      );
    }

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: isIOS
            ? CupertinoActivityIndicator(
                color: themeColor,
                radius: size / 2,
              )
            : CircularProgressIndicator(
                strokeWidth: strokeWidth,
                valueColor: AlwaysStoppedAnimation<Color>(themeColor),
              ),
      ),
    );
  }
}
