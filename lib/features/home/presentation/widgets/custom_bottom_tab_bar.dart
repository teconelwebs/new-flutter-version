// ignore_for_file: prefer_const_declarations

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'custom_tab_icons.dart';
import '../../../login/presentation/widgets/login_bottom_sheet.dart';
import '../../../../core/utils/safe_insets.dart';

class TabModel {
  final String label;
  final String screen;
  final String route;

  const TabModel({
    required this.label,
    required this.screen,
    required this.route,
  });
}

const List<TabModel> tabs = [
  TabModel(label: "Home", screen: "index", route: "/"),
  TabModel(label: "Categories", screen: "Categorys", route: "/Categorys"),
  TabModel(label: "Play", screen: "Play", route: "/Play"),
  TabModel(label: "Cart", screen: "Cart", route: "/Cart"),
  TabModel(label: "Account", screen: "Account", route: "/Account"),
];

class CustomBottomTabBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isGuest;
  final int cartCount;
  final VoidCallback promptLogin;
  final Future<void> Function() clearGuestMode;
  final VoidCallback dismissLoginModal;
  final VoidCallback onPlayLoginSuccess;

  // ignore: use_super_parameters
  const CustomBottomTabBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.isGuest,
    required this.cartCount,
    required this.promptLogin,
    required this.clearGuestMode,
    required this.dismissLoginModal,
    required this.onPlayLoginSuccess,
  }) : super(key: key);

  @override
  State<CustomBottomTabBar> createState() => _CustomBottomTabBarState();
}

class _CustomBottomTabBarState extends State<CustomBottomTabBar> {


  void _tabPressHaptic() => HapticFeedback.lightImpact();
  void _tabBlockedHaptic() => HapticFeedback.heavyImpact();
  void _tabRefreshHaptic() => HapticFeedback.mediumImpact();

  Future<void> _handleTabPress(int index, TabModel tab) async {
    _tabPressHaptic();

    if (widget.isGuest &&
        (tab.route == "/Account" ||
            tab.route == "/Cart" ||
            tab.route == "/Play")) {
      _tabBlockedHaptic();
      if (tab.route == "/Play") {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => LoginBottomSheet(
            onLoginSuccess: widget.onPlayLoginSuccess,
          ),
        );
      } else {
        widget.promptLogin();
      }
      return;
    }

    if (tab.screen == "Play") {
      widget.onTap(index);
      return;
    }

    if (index == widget.currentIndex) {
      if (tab.screen != "index") {
        _tabRefreshHaptic();
      }
      return;
    }

    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    // ignore: duplicate_ignore
    // ignore: prefer_const_declarations
    final bool isPlayScreenActive = false;
    // ignore: dead_code
    if (isPlayScreenActive) return const SizedBox.shrink();

    final bottomPadding = systemBottomInset(context);

    return Stack(
      children: [
        Container(
          padding: EdgeInsets.only(
            top: 15,
            bottom: bottomPadding > 0 ? bottomPadding : 20.0,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(
              top: BorderSide(color: Color(0xFFDDDDDD), width: 1.0),
            ),
            boxShadow: [
              BoxShadow(
                // ignore: deprecated_member_use
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(tabs.length, (index) {
              final tab = tabs[index];
              final bool isFocused = index == widget.currentIndex;

              return Expanded(
                child: InkWell(
                  onTap: () => _handleTabPress(index, tab),
                  splashColor: const Color(0x1FFB5404),
                  highlightColor: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTabIcon(tab, isFocused),
                      const SizedBox(height: 4),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: isFocused
                              ? const Color(0xFFFB5404)
                              : const Color(0xFF666666),
                          fontWeight: isFocused
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildTabIcon(TabModel tab, bool isFocused) {
    final activeColor = const Color(0xFFFB5404);
    final inactiveColor = const Color(0xFF666666);
    final selectedColor = isFocused ? activeColor : inactiveColor;

    if (tab.label == "Cart") {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          CartIcon(size: 26, active: isFocused),
          if (widget.cartCount > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  '${widget.cartCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      );
    }

    switch (tab.label) {
      case "Home":
        return HomeIcon(size: 26, color: selectedColor);
      case "Categories":
        return CategoriesIcon(size: 26, color: selectedColor);
      case "Account":
        return AccountIcon(size: 26, color: selectedColor);
      case "Play":
        return PlayIcon(size: 26, active: isFocused, activeColor: activeColor);
      default:
        return Icon(Icons.help_outline, size: 26, color: selectedColor);
    }
  }
}
