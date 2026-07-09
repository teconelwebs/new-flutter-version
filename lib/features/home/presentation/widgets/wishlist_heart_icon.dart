import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Helper method to convert Color to Hex format
String _colorToHex(Color color) {
  // ignore: deprecated_member_use
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
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <g transform="translate(0, -1028.4)">
    <path d="m7 1031.4c-1.5355 0-3.0784 0.5-4.25 1.7-2.3431 2.4-2.2788 6.1 0 8.5l9.25 9.8 9.25-9.8c2.279-2.4 2.343-6.1 0-8.5-2.343-2.3-6.157-2.3-8.5 0l-0.75 0.8-0.75-0.8c-1.172-1.2-2.7145-1.7-4.25-1.7z" fill="$hexColor"/>
  </g>
</svg>
'''
        : '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <g transform="translate(0, -1028.4)">
    <path d="m7 1031.4c-1.5355 0-3.0784 0.5-4.25 1.7-2.3431 2.4-2.2788 6.1 0 8.5l9.25 9.8 9.25-9.8c2.279-2.4 2.343-6.1 0-8.5-2.343-2.3-6.157-2.3-8.5 0l-0.75 0.8-0.75-0.8c-1.172-1.2-2.7145-1.7-4.25-1.7z" fill="$hexColor"/>
  </g>
</svg>
''';

    return SvgPicture.string(
      svgString,
      width: size,
      height: size,
    );
  }
}
