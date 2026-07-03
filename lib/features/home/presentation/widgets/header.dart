import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../search/presentation/search_screen.dart';

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
  double _translateY = 0.0;
  double _searchTranslateY = 0.0;

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

  // Scroll offset listener for interpolations
  void _onScroll() {
    if (!mounted || widget.scrollController == null) return;
    final double offset = widget.scrollController!.offset;

    setState(() {
      // 1. Logo opacity: maps scroll offset [0, 30] to [1.0, 0.0]
      _logoOpacity = (1.0 - (offset.clamp(0.0, 30.0) / 30.0));

      // 2. Logo container Translate Y: maps scroll offset [0, 46] to [0, -46]
      _translateY = (offset.clamp(0.0, 46.0) / 46.0) * -46.0;

      // 3. Search input Translate Y: maps scroll offset [0, 46] to [0, -46]
      _searchTranslateY = (offset.clamp(0.0, 46.0) / 46.0) * -46.0;
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

  // Handles search click, saves to disk, navigates
  Future<void> _handleSearchPress() async {
    final currentPlaceholder = _placeholders[_placeholderIndex];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("last_search_keyword", currentPlaceholder);
    
    if (widget.onSearchTap != null) {
      widget.onSearchTap!();
    } else {
      Navigator.pushNamed(context, SearchScreen.routeName);
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
    final double headerPaddingTop = widget.isHome ? 0.0 : topSafeArea;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsets.only(top: headerPaddingTop),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Location Address bar (if enabled)
            if (!widget.hideLocation)
              Container(
                color: widget.backgroundColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE9ECEF))),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_pin, size: 16, color: Color(0xFFFB5404)),
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

            // 2. Animated Logo and Action Buttons Bar
            Transform.translate(
              offset: Offset(0.0, _translateY),
              child: Opacity(
                opacity: _logoOpacity,
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
                              if (widget.isGuest) {
                                if (widget.promptLogin != null) {
                                  widget.promptLogin!();
                                }
                                return;
                              }
                              // Navigator.pushNamed(context, '/wishlist');
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(6.0),
                              child: Icon(Icons.favorite_border, color: Color(0xFFFB5404), size: 22),
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

            // 3. Search Box Bar (if enabled)
            if (!widget.hideSearch)
              Transform.translate(
                offset: Offset(0.0, _searchTranslateY),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: GestureDetector(
                    onTap: _handleSearchPress,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE8E8E8)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Color(0xFF666666), size: 20),
                          const SizedBox(width: 12),
                          const Text(
                            "Search for ",
                            style: TextStyle(color: Color(0xFF999999), fontSize: 15),
                          ),
                          AnimatedBuilder(
                            animation: _fadeAnimation,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _fadeAnimation.value,
                                child: Text(
                                  _placeholders[_placeholderIndex],
                                  style: TextStyle(
                                    color: _placeholderColors[_colorIndex],
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
