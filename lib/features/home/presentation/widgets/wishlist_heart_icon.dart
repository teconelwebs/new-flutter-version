import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Helper method to convert Color to Hex format
String _colorToHex(Color color) {
  return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
}

class WishlistHeartIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool active;

  const WishlistHeartIcon({
    super.key,
    this.size = 16.0,
    this.color = const Color(0xFF666666),
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final String hexColor = _colorToHex(color);

    final String svgString = active
        ? '''
<svg width="$size" height="$size" viewBox="0 0 15 15" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M4.03553 1C1.80677 1 0 2.80677 0 5.03553C0 6.10582 0.42517 7.13228 1.18198 7.88909L7.14645 13.8536C7.34171 14.0488 7.65829 14.0488 7.85355 13.8536L13.818 7.88909C14.5748 7.13228 15 6.10582 15 5.03553C15 2.80677 13.1932 1 10.9645 1C9.89418 1 8.86772 1.42517 8.11091 2.18198L7.5 2.79289L6.88909 2.18198C6.13228 1.42517 5.10582 1 4.03553 1Z" fill="$hexColor"/>
</svg>
'''
        : '''
<svg width="$size" height="$size" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M14.88 4.78a3.489 3.489 0 0 0-.37-.9 3.24 3.24 0 0 0-.6-.79 3.78 3.78 0 0 0-1.21-.81 3.74 3.74 0 0 0-2.84 0 4 4 0 0 0-1.16.75l-.05.06-.65.65-.65-.65-.05-.06a4 4 0 0 0-1.16-.75 3.74 3.74 0 0 0-2.84 0 3.78 3.78 0 0 0-1.21.81 3.55 3.55 0 0 0-.97 1.69 3.75 3.75 0 0 0-.12 1c0 .317.04.633.12.94a4 4 0 0 0 .36.89 3.8 3.8 0 0 0 .61.79L8 14.31l5.91-5.91c.237-.233.44-.5.6-.79A3.578 3.578 0 0 0 15 5.78a3.747 3.747 0 0 0-.12-1zm-1 1.63a2.69 2.69 0 0 1-.69 1.21l-5.21 5.2-5.21-5.2a2.9 2.9 0 0 1-.44-.57 3 3 0 0 1-.27-.65 3.25 3.25 0 0 1-.08-.69A3.36 3.36 0 0 1 2.06 5a2.8 2.8 0 0 1 .27-.65c.12-.21.268-.4.44-.57a2.91 2.91 0 0 1 .89-.6 2.8 2.8 0 0 1 .28 0c.31.066.6.2.85.39l1.36 1.37 1.36-1.37a2.72 2.72 0 0 1 .88-.59 2.8 2.8 0 0 1 2.08 0c.331.143.633.347.89.6.174.165.32.357.43.57a2.69 2.69 0 0 1 .35 1.34 2.6 2.6 0 0 1-.06.72h-.03z" fill="$hexColor"/>
</svg>
''';

    return SvgPicture.string(
      svgString,
      width: size,
      height: size,
    );
  }
}
