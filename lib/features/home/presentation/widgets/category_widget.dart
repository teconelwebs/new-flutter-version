import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_routes.dart';

class CategoryWidget extends StatefulWidget {
  final int pullRefreshKey;
  final ValueChanged<int>? onTabChange;

  const CategoryWidget({
    super.key,
    this.pullRefreshKey = 0,
    this.onTabChange,
  });

  @override
  State<CategoryWidget> createState() => _CategoryWidgetState();
}

class _CategoryWidgetState extends State<CategoryWidget> {
  final ScrollController _scrollController = ScrollController();

  // Layout Constants matching original styling
  static const double iconBoxSize = 56.0;
  static const double tileGap = 5.0;
  static const double itemWidth = 68.0;

  final List<String> pastelColors = [
    "#fde3d2",
    "#e8f5e9",
    "#fff0e6",
    "#fce4ec",
    "#e8eaf6",
    "#e0f7fa",
    "#f3e5f5",
    "#fff8e1",
  ];

  // Static 'All' Category item
  final Map<String, dynamic> allCategory = {
    "id": "all",
    "name": "All",
    "icon_url": "",
    "isStatic": true,
  };

  // State Variables
  List<dynamic> _categories = [];
  bool _loading = true;
  bool _isUserScrolling = false;
  Timer? _autoScrollTimer;
  Timer? _scrollDebounceTimer;
  double _scrollPosition = 0.0;

  @override
  void initState() {
    super.initState();
    _categories = [allCategory];

    _initCategoriesData();
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(covariant CategoryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pullRefreshKey > 0 &&
        widget.pullRefreshKey != oldWidget.pullRefreshKey) {
      _fetchCategories(fromRefresh: true);
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollDebounceTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // Converts hex string (like #fde3d2) to Flutter Color
  Color _parseHexColor(String hex) {
    final cleanHex = hex.replaceAll("#", "");
    return Color(int.parse("FF$cleanHex", radix: 16));
  }

  // Load from local Cache first or load default
  Future<void> _initCategoriesData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString("home_nav_cat_strip_v3");

      if (raw != null) {
        final List<dynamic> parsed = jsonDecode(raw);
        if (parsed.isNotEmpty) {
          setState(() {
            _categories = parsed;
            _loading = false;
          });
          return;
        }
      }
    } catch (_) {}

    await _fetchCategories(cacheMiss: true);
  }

  // HTTP API Call equivalent
  Future<void> _fetchCategories(
      {bool fromRefresh = false, bool cacheMiss = false}) async {
    if (mounted && _categories.length <= 1) {
      setState(() {
        _loading = true;
      });
    }

    const String apiUrl = "https://welfogapi.welfog.com/api/nav_cat_data/";
    const String cdnBase = "https://d1f02fefkbso7w.cloudfront.net/";

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final rawList = decoded['categories'] as List? ?? [];

        final List<dynamic> apiCategories = rawList.whereType<Map>().map((e) {
          final String img = (e['icon_url'] ?? "").toString();
          final String fullImg = img.isEmpty
              ? ""
              : (img.startsWith("http")
                  ? img
                  : "$cdnBase${img.startsWith('/') ? img.substring(1) : img}");
          return {
            "id": (e['id'] ?? "").toString(),
            "name": (e['name'] ?? "").toString(),
            "icon_url": fullImg,
          };
        }).toList();

        final next = [allCategory, ...apiCategories];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("home_nav_cat_strip_v3", jsonEncode(next));

        if (mounted) {
          setState(() {
            _categories = next;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // Automatically scroll horizontal strip at regular intervals
  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      final scrollCategories =
          _categories.where((c) => c['id'] != 'all').toList();
      // ignore: prefer_const_declarations
      final double step = itemWidth + tileGap;

      if (_scrollController.hasClients &&
          !_isUserScrolling &&
          scrollCategories.length > 1) {
        _scrollPosition += step;
        if (_scrollPosition >= scrollCategories.length * step) {
          _scrollPosition = 0;
        }
        _scrollController.animateTo(
          _scrollPosition,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // Listeners to disable auto-scrolling when manual user swipes happen
  void _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      setState(() {
        _isUserScrolling = true;
      });
      _scrollDebounceTimer?.cancel();
    } else if (notification is ScrollEndNotification) {
      _scrollDebounceTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _isUserScrolling = false;
            // Align current offset to scroll position tracker
            _scrollPosition = _scrollController.offset;
          });
        }
      });
    }
  }

  // Navigation action on item press
  void _navigateToCategory(String id, String name) {
    if (id == 'all') {
      if (widget.onTabChange != null) {
        widget.onTabChange!(1); // Switch to Categories tab (Index 1)
      }
      return;
    }
    Navigator.of(context).pushNamed(
      AppRoutes.searchResults,
      arguments: name,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _buildSkeletonLoader();
    }

    final scrollableCategories =
        _categories.where((c) => c['id'] != 'all').toList();
    final allItem = _categories.firstWhere((c) => c['id'] == 'all',
        orElse: () => allCategory);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 14),
          // Renders Static 'All' Category
          _buildCategoryItem(allItem, 0, isAll: true),
          const SizedBox(width: tileGap),

          // Scrollable Categories list view
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                _onScrollNotification(notification);
                return true;
              },
              child: SizedBox(
                height: 80,
                child: ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: scrollableCategories.length,
                  padding: const EdgeInsets.only(right: 14),
                  itemBuilder: (context, index) {
                    final category = scrollableCategories[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: tileGap),
                      child: _buildCategoryItem(category, index + 1),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Category Item UI Builder
  Widget _buildCategoryItem(dynamic category, int index, {bool isAll = false}) {
    final bgColor = _parseHexColor(pastelColors[index % pastelColors.length]);
    final String label = category['name'] ?? "";

    return GestureDetector(
      onTap: () => _navigateToCategory(
        category['id'].toString(),
        isAll ? "All Categories" : label,
      ),
      child: SizedBox(
        width: itemWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Styled Circular Icon container
            Container(
              width: iconBoxSize,
              height: iconBoxSize,
              decoration: BoxDecoration(
                color: isAll ? _parseHexColor(pastelColors[0]) : bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: isAll
                  ? _buildAllIconGrid()
                  : Image.network(
                      category['icon_url'] ?? "",
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.category,
                          color: Colors.grey, size: 24),
                    ),
            ),
            const SizedBox(height: 6),

            // Item label
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isAll ? FontWeight.w600 : FontWeight.w500,
                color:
                    isAll ? const Color(0xFFF47405) : const Color(0xFF333333),
              ),
              textAlign: TextAlign.center,
            ),

            // Active indicator bar under 'All' tab
            if (isAll) ...[
              const SizedBox(height: 4),
              Container(
                width: 28,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFFF47405),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Dot Grid graphic inside 'All' button
  Widget _buildAllIconGrid() {
    return SizedBox(
      width: 22,
      height: 22,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        children: List.generate(4, (index) {
          return Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: const Color(0xFFF47405),
              borderRadius: BorderRadius.circular(2.5),
            ),
          );
        }),
      ),
    );
  }

  // Pre-loading shimmer skeleton
  Widget _buildSkeletonLoader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(5, (index) {
          return SizedBox(
            width: itemWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 48,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
