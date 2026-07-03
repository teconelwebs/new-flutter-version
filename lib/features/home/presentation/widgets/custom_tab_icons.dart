import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Color ko hex string format me badalne ke liye helper function
String _colorToHex(Color color) {
  return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
}

// ==========================================
// 1. AccountIcon
// ==========================================
class AccountIcon extends StatelessWidget {
  final double size;
  final Color color;
  final double opacitySecondary;

  const AccountIcon({
    Key? key,
    this.size = 26,
    this.color = const Color(0xFF292D32),
    this.opacitySecondary = 0.4,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hexColor = _colorToHex(color);
    
    final svgString = '''
<svg width="$size" height="$size" viewBox="0 0 30 30" fill="none" xmlns="http://www.w3.org/2000/svg">
  <!-- Body -->
  <path d="M24,28H6c-1.1,0-2-0.9-2-2v0c0-3.9,3.1-7,7-7h8c3.9,0,7,3.1,7,7v0C26,27.1,25.1,28,24,28z" fill="$hexColor" opacity="$opacitySecondary"/>
  <!-- Head -->
  <circle cx="15" cy="9" r="6" fill="$hexColor"/>
</svg>
''';

    return SvgPicture.string(
      svgString,
      width: size,
      height: size,
    );
  }
}

// ==========================================
// 2. CartIcon
// ==========================================
class CartIcon extends StatelessWidget {
  final double size;
  final bool active;

  const CartIcon({
    Key? key,
    this.size = 26,
    this.active = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final gradFrom = active ? const Color(0xFFFFB300) : const Color(0xFF9CA3AF);
    final gradTo = active ? const Color(0xFFFF4900) : const Color(0xFF4B5563);
    final wheel = active ? const Color(0xFFFF4D00) : const Color(0xFF6B7280);

    final hexGradFrom = _colorToHex(gradFrom);
    final hexGradTo = _colorToHex(gradTo);
    final hexWheel = _colorToHex(wheel);

    final svgString = '''
<svg width="$size" height="$size" viewBox="0 -0.5 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
  <!-- Wheels -->
  <path d="M10.3147 30.9442C11.9424 30.9442 13.2618 29.6247 13.2618 27.9971C13.2618 26.3695 11.9424 25.05 10.3147 25.05C8.68712 25.05 7.36768 26.3695 7.36768 27.9971C7.36768 29.6247 8.68712 30.9442 10.3147 30.9442Z" fill="$hexWheel"/>
  <path d="M26.5232 30.9442C28.1509 30.9442 29.4703 29.6247 29.4703 27.9971C29.4703 26.3695 28.1509 25.05 26.5232 25.05C24.8956 25.05 23.5762 26.3695 23.5762 27.9971C23.5762 29.6247 24.8956 30.9442 26.5232 30.9442Z" fill="$hexWheel"/>

  <!-- Cart body with gradient -->
  <path fill-rule="evenodd" clip-rule="evenodd" d="M30.526 5.89412H7.44717L6.60911 2.28116C6.45421 1.61335 6.1084 1.0662 5.57167 0.63972C5.03494 0.21324 4.42381 0 3.73827 0H1.47353C0.659722 0 0 0.659722 0 1.47353C0 2.28733 0.659722 2.94706 1.47353 2.94706H3.73827L4.42186 5.89412H4.42059L8.21564 22.4326C8.29244 22.7673 8.46515 23.0416 8.73378 23.2556C9.0024 23.4695 9.30842 23.5765 9.65183 23.5765H26.8066C27.1441 23.5765 27.4459 23.4728 27.7121 23.2654C27.9783 23.0581 28.1527 22.7908 28.2354 22.4635L31.9547 7.72829C32.0103 7.50802 32.0147 7.28674 31.968 7.06443C31.9212 6.84212 31.828 6.64136 31.6884 6.46214C31.5488 6.28293 31.377 6.14345 31.1728 6.04372C30.9688 5.94399 30.7532 5.89412 30.526 5.89412Z" fill="url(#cartGradient)"/>

  <!-- Inner highlight -->
  <g opacity="0.6">
    <path fill-rule="evenodd" clip-rule="evenodd" d="M8.95667 10.7179C8.94284 10.661 8.93245 10.6034 8.91504 10.5453C8.91504 10.4871 8.91504 10.4287 8.91504 10.3701C8.91504 9.96323 9.0589 9.61592 9.34663 9.32819C9.63435 9.04047 9.98167 8.89661 10.3886 8.89661C10.7285 8.89661 11.0321 9.00165 11.2993 9.21174C11.5665 9.42183 11.7402 9.69203 11.8205 10.0224L13.9565 18.817L13.9567 18.8175C13.9705 18.8744 13.9809 18.932 13.9878 18.9901C13.9948 19.0483 13.9983 19.1067 13.9983 19.1653C13.9983 19.5722 13.8544 19.9195 13.5667 20.2072C13.279 20.4949 12.9317 20.6388 12.5248 20.6388C12.1848 20.6388 11.8813 20.5338 11.614 20.3237C11.3468 20.1136 11.1731 19.8434 11.0929 19.5131L8.95667 10.7179ZM17.6405 10.059C17.5603 9.72864 17.3865 9.45844 17.1193 9.24835C16.8521 9.03826 16.5485 8.93321 16.2086 8.93321C15.8017 8.93321 15.4544 9.07707 15.1666 9.3648C14.8789 9.65252 14.7351 9.99984 14.7351 10.4067C14.7351 10.4653 14.7385 10.5237 14.7455 10.5819C14.7525 10.64 14.7629 10.6976 14.7767 10.7545L16.9129 19.5497C16.9931 19.88 17.1668 20.1502 17.4341 20.3603C17.7013 20.5704 18.0049 20.6754 18.3448 20.6754C18.7517 20.6754 19.099 20.5315 19.3867 20.2438C19.6744 19.9561 19.8183 19.6088 19.8183 19.2019C19.8183 19.1433 19.8148 19.0849 19.8079 19.0267C19.8009 18.9686 19.7905 18.911 19.7767 18.8541L19.7766 18.8536L17.6405 10.059Z" fill="#ffffff" fill-opacity="0.6"/>
  </g>

  <defs>
    <linearGradient id="cartGradient" x1="0" y1="0" x2="19.7144" y2="29.6608" gradientUnits="userSpaceOnUse">
      <stop stop-color="$hexGradFrom" />
      <stop offset="1" stop-color="$hexGradTo" />
    </linearGradient>
  </defs>
</svg>
''';

    return SvgPicture.string(
      svgString,
      width: size,
      height: size,
    );
  }
}

// ==========================================
// 3. CategoriesIcon
// ==========================================
class CategoriesIcon extends StatelessWidget {
  final double size;
  final Color color;

  const CategoriesIcon({
    Key? key,
    this.size = 26,
    this.color = const Color(0xFF292D32),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hexColor = _colorToHex(color);

    final svgString = '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M7.24 2H5.34C3.15 2 2 3.15 2 5.33V7.23C2 9.41 3.15 10.56 5.33 10.56H7.23C9.41 10.56 10.56 9.41 10.56 7.23V5.33C10.57 3.15 9.42 2 7.24 2Z" fill="$hexColor"/>
  <path opacity="0.4" d="M18.6695 2H16.7695C14.5895 2 13.4395 3.15 13.4395 5.33V7.23C13.4395 9.41 14.5895 10.56 16.7695 10.56H18.6695C20.8495 10.56 21.9995 9.41 21.9995 7.23V5.33C21.9995 3.15 20.8495 2 18.6695 2Z" fill="$hexColor"/>
  <path d="M18.6695 13.4302H16.7695C14.5895 13.4302 13.4395 14.5802 13.4395 16.7602V18.6602C13.4395 20.8402 14.5895 21.9902 16.7695 21.9902H18.6695C20.8495 21.9902 21.9995 20.8402 21.9995 18.6602V16.7602C21.9995 14.5802 20.8495 13.4302 18.6695 13.4302Z" fill="$hexColor"/>
  <path opacity="0.4" d="M7.24 13.4302H5.34C3.15 13.4302 2 14.5802 2 16.7602V18.6602C2 20.8502 3.15 22.0002 5.33 22.0002H7.23C9.41 22.0002 10.56 20.8502 10.56 18.6702V16.7702C10.57 14.5802 9.42 13.4302 7.24 13.4302Z" fill="$hexColor"/>
</svg>
''';

    return SvgPicture.string(
      svgString,
      width: size,
      height: size,
    );
  }
}

// ==========================================
// 4. HomeIcon (With Nested scale(0.18) W Logo)
// ==========================================
class HomeIcon extends StatelessWidget {
  final double size;
  final Color color;
  final Color? wColor;
  final Color? wBgColor;

  const HomeIcon({
    Key? key,
    this.size = 26,
    this.color = const Color(0xFFFB5404),
    this.wColor,
    this.wBgColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hexColor = _colorToHex(color);
    final hexWColor = _colorToHex(wColor ?? Colors.white);
    final hexWBgColor = _colorToHex(wBgColor ?? const Color(0xFFFF6A00));

    final svgString = '''
<svg width="$size" height="$size" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
  <!-- Home shape -->
  <path fill="$hexColor" d="M18.1780455,11.3733043 C18.5648068,11.3733043 18.8783387,11.6865112 18.8783387,12.0728715 L18.8779659,17.9472709 C18.9045058,18.7594781 18.8070167,19.291671 18.4437066,19.6266035 C18.105756,19.9381573 17.6163877,20.02774 16.9806726,19.9929477 L3.14358762,19.9921612 C2.50135353,19.9617139 2.00101685,19.6995595 1.76807877,19.1740143 C1.61416876,18.826769 1.54233858,18.4172981 1.54233858,17.9457519 L1.54233858,12.0728715 C1.54233858,11.6865112 1.85587053,11.3733043 2.2426318,11.3733043 C2.62939306,11.3733043 2.94292502,11.6865112 2.94292502,12.0728715 L2.94292502,17.9457519 C2.94292502,18.1775916 2.96768644,18.3651131 3.01196148,18.5083933 L3.048,18.606 L3.04520125,18.5951633 C3.04625563,18.5832362 3.07436346,18.5883277 3.17678453,18.5938132 L17.0178944,18.5948021 C17.2619058,18.6077766 17.4181773,18.5935806 17.4731456,18.5929701 L17.477,18.592 C17.4642876,18.5389055 17.4889447,18.3217509 17.4777523,17.9700942 L17.4777523,12.0728715 C17.4777523,11.6865112 17.7912843,11.3733043 18.1780455,11.3733043 Z M10.4342636,0 C10.6979883,0 10.9335521,0.103647698 11.156261,0.297113339 L19.7806041,8.43584529 C20.0617527,8.70116319 20.0743627,9.14392549 19.8087695,9.42478257 C19.5431762,9.70563964 19.0999544,9.71823663 18.8188059,9.45291873 L10.4018236,1.50898373 L1.15769646,9.47411857 C0.864827408,9.72646706 0.422628974,9.69386478 0.170018608,9.40129935 C-0.082591757,9.10873393 -0.049955647,8.66699392 0.2429134,8.41464544 L9.6885128,0.275913491 L9.77478626,0.212395396 C9.98943808,0.0783954693 10.2025363,0 10.4342636,0 Z"/>

  <!-- Scale-transformed logo group -->
  <g transform="translate(4.5 5.5) scale(0.18)">
    <circle cx="32" cy="32" r="30" fill="$hexWBgColor"/>
    <path d="M20 17.5l3.8 16.6l.8 4.6l.8-4.5l3.3-16.7h6.4l3.4 16.6l.9 4.6l.9-4.4l3.9-16.8h6.2l-8.2 29h-5.8l-3.5-17l-1-5.6l-1 5.6l-3.5 17h-5.6l-8.2-29H20" fill="$hexWColor"/>
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

// ==========================================
// 5. PlayIcon
// ==========================================
class PlayIcon extends StatelessWidget {
  final double size;
  final bool active;
  final Color activeColor;

  const PlayIcon({
    Key? key,
    this.size = 26,
    this.active = false,
    this.activeColor = const Color(0xFFFB5404),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const inactive = Color(0xFF666666);
    final ringColor = active ? activeColor : inactive;
    final fillColor = active ? activeColor : inactive;
    final arrowColor = active ? activeColor : inactive;

    final hexRing = _colorToHex(ringColor);
    final hexFill = _colorToHex(fillColor);
    final hexArrow = _colorToHex(arrowColor);

    // Dynamic opacities based on active state
    final opacityLeft = active ? "0.22" : "0.14";
    final opacityRight = active ? "0.14" : "0.08";
    final opacityRingA = active ? "0.9" : "1";
    const opacityRingB = "0.55";

    final svgString = '''
<svg width="$size" height="$size" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M16,28C9.373,28,4,22.627,4,16S9.373,4,16,4V28z" fill="$hexFill" opacity="$opacityLeft"/>
  <path d="M16,28c6.627,0,12-5.373,12-12S22.627,4,16,4V28z" fill="$hexFill" opacity="$opacityRight"/>
  <path d="M4,16C4,9.373,9.373,4,16,4V0C7.163,0,0,7.163,0,16s7.163,16,16,16v-4C9.373,28,4,22.627,4,16z" fill="$hexRing" opacity="$opacityRingA"/>
  <path d="M28,16c0-6.627-5.373-12-12-12V0c8.837,0,16,7.163,16,16s-7.163,16-16,16v-4C22.627,28,28,22.627,28,16z" fill="$hexRing" opacity="$opacityRingB"/>
  <path d="M14.232,21c-0.384,0-0.768-0.146-1.061-0.439c-0.586-0.586-0.586-1.535,0-2.121l2.476-2.476l-2.476-2.476c-0.586-0.586-0.586-1.535,0-2.121s1.535-0.586,2.121,0l4.597,4.597l-4.597,4.597C15,20.854,14.616,21,14.232,21z" fill="$hexArrow"/>
</svg>
''';

    return SvgPicture.string(
      svgString,
      width: size,
      height: size,
    );
  }
}
