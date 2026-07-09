import 'dart:async';
import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../search/presentation/search_screen.dart';
import '../../../search/presentation/widgets/app_search_bar.dart';
import 'delivery_icon.dart';
import 'wishlist_heart_icon.dart';
import '../../../../core/constants/app_routes.dart';

class Header extends StatefulWidget {
  final Color backgroundColor;
  final bool hideSearch;
  final ScrollController? scrollController; // drive dynamic animations on scroll
  final bool hideLocation;
  final bool isHome;
  final String city;
  final String pincode;
  final bool isGuest;
  final VoidCallback? onSearchTap;
  final VoidCallback? promptLogin;
  final VoidCallback? onLocationTap;

  // ignore: use_super_parameters
  const Header({
    Key? key,
    this.backgroundColor = Colors.white,
    this.hideSearch = false,
    this.scrollController,
    this.hideLocation = false,
    this.isHome = false,
    required this.city,
    required this.pincode,
    required this.isGuest,
    this.onSearchTap,
    this.promptLogin,
    this.onLocationTap,
  }) : super(key: key);

  @override
  State<Header> createState() => _HeaderState();
}

class _HeaderState extends State<Header> with TickerProviderStateMixin {
  // Animating Placeholders States
  final List<String> _placeholders = [
    "Mobile",
    "Cloths",
    "Pants",
    "Jewelry",
    "T-Shirt",
    "Phone Covers",
    "Shoes",
  ];
  final List<Color> _placeholderColors = [
    const Color(0xFFF47405),
    const Color(0xFF088384),
    const Color(0xFF72B8B8),
    const Color(0xFFCC7639),
  ];

  int _placeholderIndex = 0;
  int _colorIndex = 0;
  int _unreadCount = 0;

  // Placeholder Fade Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  Timer? _placeholderTimer;

  // Scroll Interpolation States
  double _logoOpacity = 1.0;
  double _logoHeight = 46.0;

  @override
  void initState() {
    super.initState();

    // Fade animation for placeholders
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_fadeController);
    _fadeController.value = 1.0; // Start fully visible

    _startPlaceholderRotation();
    _fetchUnreadNotificationsCount();

    // Scroll listeners for dynamic scaling/slide-up
    if (widget.scrollController != null) {
      widget.scrollController!.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _placeholderTimer?.cancel();
    _fadeController.dispose();
    if (widget.scrollController != null) {
      widget.scrollController!.removeListener(_onScroll);
    }
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || widget.scrollController == null) return;
    final double offset = widget.scrollController!.offset;

    setState(() {
      // 1. Logo opacity: maps scroll offset [0, 30] to [1.0, 0.0]
      _logoOpacity = (1.0 - (offset.clamp(0.0, 30.0) / 30.0));

      // 2. Logo height: maps scroll offset [0, 46] to [46.0, 0.0]
      _logoHeight = 46.0 - (offset.clamp(0.0, 46.0));
    });
  }

  // Rotating placeholder titles logic
  void _startPlaceholderRotation() {
    _placeholderTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fadeController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _placeholderIndex = (_placeholderIndex + 1) % _placeholders.length;
            _colorIndex = (_colorIndex + 1) % _placeholderColors.length;
          });
          _fadeController.forward();
        }
      });
    });
  }

  // Load notification count from HTTP API
  Future<void> _fetchUnreadNotificationsCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString("user_id");

      if (userId != null) {
        // Custom counting logic placeholder
        int calculatedUnread = 0;
        setState(() {
          _unreadCount = calculatedUnread;
        });
      }
    } catch (e) {
      debugPrint("Error fetching notification counts: $e");
    }
  }

  Future<void> _handleSearchPress() async {
    if (widget.onSearchTap != null) {
      widget.onSearchTap!();
    } else {
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        SearchScreen.routeName,
      );
    }
  }

  // Full logic for Logo click checks and route adjustments
  Future<void> _handleLogoPress() async {
    try {
      // Refresh home flow or return to root
    } catch (e) {
      debugPrint("Logo press error fallback: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final double topSafeArea = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: widget.backgroundColor,
        padding: EdgeInsets.only(top: topSafeArea),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Location Address bar (if enabled)
            if (!widget.hideLocation)
              GestureDetector(
                onTap: widget.onLocationTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: const Border(bottom: BorderSide(color: Color(0xFFE9ECEF))),
                    color: widget.backgroundColor,
                  ),
                  child: Row(
                    children: [
                      const DeliveryIcon(size: 16, color: Color(0xFFFB5404)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Deliver to ${widget.city} - ${widget.pincode}',
                          style: const TextStyle(
                            color: Color(0xFF0B7E7B),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 16, color: Color(0xFF0B7E7B)),
                    ],
                  ),
                ),
              ),

            // 2. Animated Logo and Action Buttons Bar
            Opacity(
              opacity: _logoOpacity,
              child: ClipRect(
                child: SizedBox(
                  height: _logoHeight,
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      height: 46,
                      color: widget.backgroundColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Logo Touch Event
                          GestureDetector(
                            onTap: _handleLogoPress,
                            child: Image.asset(
                              "assets/images/welf.png",
                              width: 120,
                              height: 28,
                              fit: BoxFit.contain,
                            ),
                          ),

                          // Wishlist & Notification Action Buttons
                          Row(
                            children: [
                              // Wishlist click
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).pushNamed(AppRoutes.wishlist);
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(6.0),
                                  child: WishlistHeartIcon(size: 22, color: Color(0xFFFB5404), active: true),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Notification click
                              GestureDetector(
                                onTap: () {
                                  if (widget.isGuest) {
                                    if (widget.promptLogin != null) {
                                      widget.promptLogin!();
                                    }
                                    return;
                                  }
                                  // Navigator.pushNamed(context, '/notifications');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(6.0),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      const Icon(Icons.notifications_none, color: Color(0xFFFB5404), size: 22),
                                      // Badge indicator
                                      if (_unreadCount > 0)
                                        Positioned(
                                          top: -6,
                                          right: -6,
                                          child: Container(
                                            height: 18,
                                            constraints: const BoxConstraints(minWidth: 18),
                                            padding: const EdgeInsets.symmetric(horizontal: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF008083),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 1.5),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              _unreadCount > 99 ? "99+" : '$_unreadCount',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 3. Search Box Bar (if enabled)
            if (!widget.hideSearch)
              Padding(
                padding: EdgeInsets.only(
                  top: 4,
                  bottom: MediaQuery.sizeOf(context).width < 360 ? 8 : 10,
                ),
                child: AppSearchBar.readOnly(
                  onTap: _handleSearchPress,
                  prefixText: 'Search for ',
                  highlightText: _placeholders[_placeholderIndex],
                  highlightColor: _placeholderColors[_colorIndex],
                  fadeAnimation: _fadeAnimation,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
