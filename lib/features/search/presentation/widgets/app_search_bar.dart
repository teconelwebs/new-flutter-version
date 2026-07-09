import 'package:flutter/material.dart';

class AppSearchBar extends StatelessWidget {
  const AppSearchBar.readOnly({
    super.key,
    required this.onTap,
    this.prefixText = 'Search for ',
    this.highlightText,
    this.highlightColor = const Color(0xFFF47405),
    this.fadeAnimation,
  })  : controller = null,
        focusNode = null,
        onChanged = null,
        onSubmitted = null,
        onClear = null,
        autofocus = false,
        hintText = 'Search products',
        showBackButton = false,
        onBack = null;

  const AppSearchBar.editable({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
    this.hintText = 'Search products',
    this.showBackButton = true,
    this.onBack,
  })  : onTap = null,
        prefixText = null,
        highlightText = null,
        highlightColor = null,
        fadeAnimation = null;

  final VoidCallback? onTap;
  final String? prefixText;
  final String? highlightText;
  final Color? highlightColor;
  final Animation<double>? fadeAnimation;

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;
  final String? hintText;
  final bool showBackButton;
  final VoidCallback? onBack;

  static const Color _bgColor = Color(0xFFF5F5F5);
  static const Color _iconColor = Color(0xFF666666);
  static const Color _hintColor = Color(0xFF999999);
  static const Color _textColor = Color(0xFF333333);

  double _barHeight(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 360) return 44;
    return 48;
  }

  double _fontSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 360) return 14;
    return 15;
  }

  double _horizontalMargin(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 360) return 12;
    return 14;
  }

  BoxDecoration _decoration(BuildContext context) {
    final height = _barHeight(context);
    return BoxDecoration(
      color: _bgColor,
      borderRadius: BorderRadius.circular(height / 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final barHeight = _barHeight(context);
    final fontSize = _fontSize(context);
    final hasText = controller != null && controller!.text.isNotEmpty;

    final content = Container(
      height: barHeight,
      margin: EdgeInsets.symmetric(horizontal: _horizontalMargin(context)),
      decoration: _decoration(context),
      padding: EdgeInsets.only(
        left: showBackButton ? 4 : 14,
        right: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showBackButton)
            _BarIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              size: 18,
              onTap: onBack ?? () => Navigator.maybeOf(context)?.pop(),
            ),
          if (!showBackButton && onTap != null)
            // ignore: prefer_const_constructors
            Padding(
              padding: const EdgeInsets.only(right: 10),
              // ignore: prefer_const_constructors
              child: Icon(Icons.search, size: 20, color: _iconColor),
            ),
          Expanded(
            child: _buildField(context, fontSize),
          ),
          if (controller != null) ...[
            if (hasText)
              _BarIconButton(
                icon: Icons.close_rounded,
                size: 18,
                onTap: onClear,
              ),
            _BarIconButton(
              icon: Icons.search,
              size: 22,
              onTap: hasText ? () => onSubmitted?.call(controller!.text) : null,
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(barHeight / 2),
        splashColor: const Color(0x12000000),
        highlightColor: const Color(0x08000000),
        child: content,
      );
    }

    return content;
  }

  Widget _buildField(BuildContext context, double fontSize) {
    if (controller != null) {
      return TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        cursorColor: const Color(0xFFFB5404),
        cursorWidth: 1.5,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          color: _textColor,
          height: 1.2,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: fontSize,
            color: _hintColor,
            fontWeight: FontWeight.w400,
            height: 1.2,
          ),
          filled: true,
          fillColor: Colors.transparent,
          hoverColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Flexible(
            child: Text(
              prefixText ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _hintColor,
                fontSize: fontSize,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          if (highlightText != null && highlightText!.isNotEmpty)
            Flexible(
              child: fadeAnimation != null
                  ? AnimatedBuilder(
                      animation: fadeAnimation!,
                      builder: (context, child) {
                        return Opacity(
                          opacity: fadeAnimation!.value,
                          child: child,
                        );
                      },
                      child: Text(
                        highlightText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: highlightColor ?? const Color(0xFFF47405),
                          fontSize: fontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : Text(
                      highlightText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: highlightColor ?? const Color(0xFFF47405),
                        fontSize: fontSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

class _BarIconButton extends StatelessWidget {
  const _BarIconButton({
    required this.icon,
    required this.size,
    this.onTap,
  });

  final IconData icon;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        splashRadius: 20,
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          highlightColor: const Color(0x12000000),
        ),
        icon: Icon(icon, size: size, color: AppSearchBar._iconColor),
      ),
    );
  }
}
