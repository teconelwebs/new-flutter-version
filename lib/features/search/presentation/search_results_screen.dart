import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/state/cart_state.dart';
import '../../product/data/models/product_item.dart';
import '../../product/presentation/widgets/product_card.dart';
import '../data/search_api_service.dart';

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({super.key, required this.query, this.categoryId});

  final String query;
  final String? categoryId;

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final _searchApi = SearchApiService();
  bool _loading = true;
  String _query = '';
  List<ProductItem> _products = const [];

  List<dynamic> _colors = const [];
  List<SearchCategory> _categories = const [];

  String _sortBy = ''; // '', 'newest', 'oldest', 'price-asc', 'price-desc'
  dynamic _selectedColor;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _query = widget.query;
    if (widget.categoryId != null &&
        widget.categoryId!.trim().isNotEmpty &&
        RegExp(r'^\d+$').hasMatch(widget.categoryId!.trim())) {
      _selectedCategory = widget.categoryId!.trim();
    }
    _loadInitialData();
    CartState.loadCartCount();
  }

  Future<void> _loadInitialData() async {
    _fetchCategories();
    await _fetchProducts();
  }

  Future<void> _fetchCategories() async {
    try {
      final cats = await _searchApi.fetchCategories();
      if (!mounted) return;
      setState(() => _categories = cats);
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  Future<void> _fetchProducts() async {
    setState(() => _loading = true);
    try {
      String? colorVal;
      if (_selectedColor != null) {
        if (_selectedColor is String) {
          colorVal = _selectedColor;
        } else if (_selectedColor is Map) {
          colorVal = (_selectedColor['name'] ??
                  _selectedColor['code'] ??
                  _selectedColor['color_code'] ??
                  _selectedColor['color'] ??
                  '')
              .toString();
        }
      }

      final payload = await _searchApi.searchProducts(
        _query,
        categoryId: _selectedCategory,
        color: colorVal,
        sortBy: _sortBy,
      );

      if (!mounted) return;
      setState(() {
        _products = payload.products;
        if (_colors.isEmpty && payload.colors.isNotEmpty) {
          _colors = payload.colors;
        }
      });
    } catch (e) {
      debugPrint('Error fetching search products: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  final _sortOptions = const [
    {'value': '', 'label': 'Sort by'},
    {'value': 'newest', 'label': 'Newest'},
    {'value': 'oldest', 'label': 'Oldest'},
    {'value': 'price-asc', 'label': 'Price low to high'},
    {'value': 'price-desc', 'label': 'Price high to low'},
  ];

  String get _currentSortLabel {
    final match = _sortOptions.firstWhere(
      (opt) => opt['value'] == _sortBy,
      orElse: () => {'label': 'Sort by'},
    );
    return match['label']!;
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Sort by',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111111),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF333333)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: _sortOptions.skip(1).map((opt) {
                          final isSelected = _sortBy == opt['value'];
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _sortBy = opt['value']!;
                              });
                              Navigator.pop(context);
                              _fetchProducts();
                            },
                            child: Container(
                              color: isSelected
                                  ? const Color(0xFFFFF5F0)
                                  : Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    opt['label']!,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: isSelected
                                          ? const Color(0xFFFB5404)
                                          : const Color(0xFF333333),
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check,
                                      color: Color(0xFFFB5404),
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.65,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filters',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111111),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF333333)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_categories.isNotEmpty) ...[
                              const Text(
                                'All Categories',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111111),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _categories.map((cat) {
                                  final isSelected =
                                      _selectedCategory == cat.id;
                                  return ChoiceChip(
                                    label: Text(cat.name),
                                    selected: isSelected,
                                    selectedColor: const Color(0xFFFFF5F0),
                                    backgroundColor: Colors.white,
                                    side: BorderSide(
                                      color: isSelected
                                          ? const Color(0xFFFB5404)
                                          : const Color(0xFFDDDDDD),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFFFB5404)
                                          : const Color(0xFF666666),
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                    onSelected: (selected) {
                                      setSheetState(() {
                                        if (selected) {
                                          _selectedCategory = cat.id;
                                        } else {
                                          _selectedCategory = null;
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 24),
                            ],
                            if (_colors.isNotEmpty) ...[
                              const Text(
                                'Search By Color',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111111),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: List.generate(_colors.length, (index) {
                                  final colorItem = _colors[index];
                                  final isSelected =
                                      _isSameColor(_selectedColor, colorItem);

                                  return GestureDetector(
                                    onTap: () {
                                      setSheetState(() {
                                        if (isSelected) {
                                          _selectedColor = null;
                                        } else {
                                          _selectedColor = colorItem;
                                        }
                                      });
                                    },
                                    child: _buildColorCircle(
                                        colorItem, isSelected),
                                  );
                                }),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFB5404),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            setState(() {});
                            Navigator.pop(context);
                            _fetchProducts();
                          },
                          child: const Text(
                            'Apply Filters',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _isSameColor(dynamic a, dynamic b) {
    if (a == null || b == null) return false;
    if (a == b) return true;
    if (a is Map && b is Map) {
      final idA = a['id']?.toString();
      final idB = b['id']?.toString();
      if (idA != null && idB != null && idA == idB) return true;
      final codeA = (a['code'] ?? a['color_code'] ?? a['color'] ?? '').toString();
      final codeB = (b['code'] ?? b['color_code'] ?? b['color'] ?? '').toString();
      if (codeA.isNotEmpty && codeA == codeB) return true;
    }
    return false;
  }

  Widget _buildColorCircle(dynamic colorItem, bool isSelected) {
    String colorCode = '';
    String colorName = '';
    if (colorItem is String) {
      colorCode = colorItem;
    } else if (colorItem is Map) {
      colorCode = (colorItem['color_code'] ??
              colorItem['code'] ??
              colorItem['color'] ??
              '#CCC')
          .toString();
      colorName = (colorItem['name'] ?? '').toString();
    }

    final lowerName = colorName.toLowerCase();
    final isExplicitMulti = colorCode.contains('linear-gradient');
    final isMultiName = lowerName.contains('multi') || lowerName.contains('rainbow');
    final isComboName = lowerName.contains('combo');

    BoxDecoration decoration;
    if (isExplicitMulti || isMultiName) {
      List<Color> gradientColors = [];
      if (isExplicitMulti) {
        gradientColors = _extractGradientColors(colorCode);
      }
      if (gradientColors.length < 2) {
        gradientColors = const [
          Color(0xFFFF0000),
          Color(0xFFFF7F00),
          Color(0xFFFFFF00),
          Color(0xFF00FF00),
          Color(0xFF0000FF),
          Color(0xFF4B0082),
          Color(0xFF8B00FF),
        ];
      }
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        border: Border.all(
          color: isSelected ? const Color(0xFFFB5404) : const Color(0xFFDDDDDD),
          width: isSelected ? 3 : 2,
        ),
      );
    } else if (isComboName) {
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF111111),
            Color(0xFFFB5404),
            Color(0xFFFFFFFF),
          ],
        ),
        border: Border.all(
          color: isSelected ? const Color(0xFFFB5404) : const Color(0xFFDDDDDD),
          width: isSelected ? 3 : 2,
        ),
      );
    } else {
      final parsedColor = _parseSingleColor(colorCode);
      decoration = BoxDecoration(
        color: parsedColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? const Color(0xFFFB5404) : const Color(0xFFDDDDDD),
          width: isSelected ? 3 : 2,
        ),
      );
    }

    return Tooltip(
      message: colorName.isNotEmpty ? colorName : colorCode,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: decoration,
            child: isSelected
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : null,
          ),
          if (colorName.isNotEmpty) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: 50,
              child: Text(
                colorName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? const Color(0xFFFB5404) : const Color(0xFF666666),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Color> _extractGradientColors(String raw) {
    try {
      final regex = RegExp(r'#(?:[0-9a-fA-F]{3}){1,2}\b');
      final matches = regex.allMatches(raw);
      final colors = matches.map((m) => _parseSingleColor(m.group(0)!)).toList();
      if (colors.length >= 2) return colors;
    } catch (_) {}
    return [Colors.black, Colors.white];
  }

  Color _parseSingleColor(String hex) {
    var clean = hex.replaceAll('#', '').trim();
    if (clean.length == 3) {
      clean = clean.split('').map((c) => '$c$c').join('');
    }
    if (clean.length == 6) {
      clean = 'FF$clean';
    }
    final val = int.tryParse(clean, radix: 16) ?? 0xFFCCCCCC;
    return Color(val);
  }

  Widget _buildActiveFiltersBar() {
    final hasCategoryFilter = _selectedCategory != null &&
        _selectedCategory!.isNotEmpty &&
        _selectedCategory != widget.categoryId;

    final hasColorFilter = _selectedColor != null;
    final hasSortFilter = _sortBy.isNotEmpty;

    if (!hasCategoryFilter && !hasColorFilter && !hasSortFilter) {
      return const SizedBox.shrink();
    }

    String categoryName = 'Category';
    if (hasCategoryFilter) {
      final match = _categories.firstWhere(
        (c) => c.id == _selectedCategory,
        orElse: () => const SearchCategory(id: '', name: 'Category', iconUrl: ''),
      );
      categoryName = match.name;
    }

    String colorName = 'Color';
    if (hasColorFilter) {
      if (_selectedColor is Map) {
        colorName = (_selectedColor['name'] ?? 'Color').toString();
      }
    }

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (hasCategoryFilter)
            _buildActiveTag(
              label: 'Category: $categoryName',
              onRemove: () {
                setState(() {
                  _selectedCategory = widget.categoryId;
                });
                _fetchProducts();
              },
            ),
          if (hasColorFilter)
            _buildActiveTag(
              label: 'Color: $colorName',
              colorItem: _selectedColor,
              onRemove: () {
                setState(() {
                  _selectedColor = null;
                });
                _fetchProducts();
              },
            ),
          if (hasSortFilter)
            _buildActiveTag(
              label: 'Sort: $_currentSortLabel',
              onRemove: () {
                setState(() {
                  _sortBy = '';
                });
                _fetchProducts();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActiveTag({
    required String label,
    dynamic colorItem,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFB5404)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (colorItem != null) ...[
            SizedBox(
              width: 12,
              height: 12,
              child: _buildColorCircle(colorItem, false),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFFB5404),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.cancel,
              size: 16,
              color: Color(0xFFFB5404),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _query.isNotEmpty ? _query : 'Products',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.search);
            },
            icon: const Icon(
              Icons.search_rounded,
              color: Color(0xFFDC2626),
            ),
          ),
          IconButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final token = prefs.getString('access_token') ?? '';
              if (token.isEmpty) {
                if (context.mounted) {
                  Navigator.of(context).pushNamed(AppRoutes.login);
                }
                return;
              }
              if (context.mounted) {
                Navigator.of(context).pushNamed(AppRoutes.wishlist);
              }
            },
            icon: const Icon(
              Icons.favorite_border_rounded,
              color: Color(0xFFDC2626),
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: CartState.cartCountNotifier,
            builder: (context, cartCount, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final token = prefs.getString('access_token') ?? '';
                      if (token.isEmpty) {
                        if (context.mounted) {
                          Navigator.of(context).pushNamed(AppRoutes.login);
                        }
                        return;
                      }
                      if (context.mounted) {
                        Navigator.of(context).pushNamed(AppRoutes.cart);
                      }
                    },
                    icon: const Icon(
                      Icons.shopping_cart_outlined,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  if (cartCount > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$cartCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter & Sort Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _showFilterSheet,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFDDDDDD)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.filter_alt_outlined, size: 18, color: Color(0xFF666666)),
                          SizedBox(width: 6),
                          Text(
                            'Filters',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF666666),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: _showSortSheet,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFDDDDDD)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentSortLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF666666),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: Color(0xFF666666),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Active Filters Badges
          _buildActiveFiltersBar(),

          // Products List Grid
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFB5404)),
                  )
                : _products.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: Color(0xFF9AA0A6),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Product Not Found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFB5404),
                              ),
                            ),
                          ],
                        ),
                      )
                    : (() {
                        final leftColumnItems = <ProductItem>[];
                        final rightColumnItems = <ProductItem>[];
                        for (int i = 0; i < _products.length; i++) {
                          if (i % 2 == 0) {
                            leftColumnItems.add(_products[i]);
                          } else {
                            rightColumnItems.add(_products[i]);
                          }
                        }

                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: leftColumnItems
                                      .map((item) => Padding(
                                            padding: const EdgeInsets.only(bottom: 12),
                                            child: ProductCard(item: item),
                                          ))
                                      .toList(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: rightColumnItems
                                      .map((item) => Padding(
                                            padding: const EdgeInsets.only(bottom: 12),
                                            child: ProductCard(item: item),
                                          ))
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        );
                      })(),
          ),
        ],
      ),
    );
  }
}
