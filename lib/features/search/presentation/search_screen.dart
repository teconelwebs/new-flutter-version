import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_routes.dart';
import '../../account/data/account_api_service.dart';
import '../../product/data/models/product_item.dart';
import '../data/search_api_service.dart';
import 'widgets/app_search_bar.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.embedded = false, this.initialQuery});

  static const routeName = AppRoutes.search;

  final bool embedded;
  final String? initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchApi = SearchApiService();
  final _accountApi = AccountApiService();
  final _queryCtrl = TextEditingController();
  final _focusNode = FocusNode();
  List<String> _suggestions = const [];
  List<String> _recent = const [];
  List<SearchCategory> _categories = const [];
  List<WishlistItem> _wishlistPreview = const [];
  bool _categoriesLoading = true;
  bool _suggestionLoading = false;
  bool _wishlistLoading = false;
  bool _isSearching = false;
  Timer? _debounce;

  ProductItem _toProductItem(WishlistProduct p) {
    final imageUrl = p.thumbnailImage.isNotEmpty
        ? 'https://d1f02fefkbso7w.cloudfront.net/${p.thumbnailImage}'
        : '';
    return ProductItem(
      id: p.id.toString(),
      title: p.name,
      subtitle: p.brand.isEmpty ? 'Fast delivery' : p.brand,
      price: _cleanPrice(p.sellingPrice),
      rating: 4.5,
      color: const Color(0xFFF3E8FF),
      imageUrl: imageUrl,
      slug: p.link.isNotEmpty ? p.link : p.id.toString(),
      brand: p.brand,
      durationMinutes: 0,
    );
  }

  double _cleanPrice(dynamic priceRaw) {
    if (priceRaw == null) return 0.0;
    if (priceRaw is num) return priceRaw.toDouble();
    final cleanStr = priceRaw.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleanStr) ?? 0.0;
  }

  Future<void> _fetchWishlistPreview() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    final token = prefs.getString('access_token') ?? '';
    if (userId.isEmpty || token.isEmpty) {
      if (mounted) {
        setState(() {
          _wishlistPreview = const [];
          _wishlistLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _wishlistLoading = true);
    }
    try {
      final items = await _accountApi.fetchWishlist();
      if (!mounted) return;
      setState(() {
        _wishlistPreview = items;
      });
    } catch (e) {
      debugPrint('Error fetching wishlist preview: $e');
    } finally {
      if (mounted) {
        setState(() => _wishlistLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _queryCtrl.text = widget.initialQuery!.trim();
    }
    _queryCtrl.addListener(_onTextChanged);
    _loadInitial();
    _fetchWishlistPreview();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _onTextChanged() => setState(() {});

  Future<void> _loadInitial() async {
    await _loadRecent();
    await _loadCategories();
    if (_queryCtrl.text.trim().isNotEmpty) {
      _onQueryChanged(_queryCtrl.text);
    }
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('recent_searches') ?? <String>[];
    if (!mounted) return;
    setState(() => _recent = raw.take(5).toList());
  }

  Future<void> _loadCategories() async {
    setState(() => _categoriesLoading = true);
    try {
      final data = await _searchApi.fetchCategories();
      if (!mounted) return;
      setState(() => _categories = data);
    } finally {
      if (mounted) setState(() => _categoriesLoading = false);
    }
  }

  Future<void> _saveRecent(String q) async {
    final prefs = await SharedPreferences.getInstance();
    final next = [q, ..._recent.where((x) => x != q)].take(5).toList();
    await prefs.setStringList('recent_searches', next);
    if (!mounted) return;
    setState(() => _recent = next);
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _suggestions = const [];
        _suggestionLoading = false;
      });
      return;
    }
    setState(() {
      _suggestionLoading = true;
      _suggestions = const []; // Clear old suggestions immediately while typing new characters
    });
    _debounce = Timer(const Duration(milliseconds: 320), () async {
      if (!mounted) return;
      try {
        final list = await _searchApi.autosuggest(trimmed);
        if (!mounted) return;
        setState(() => _suggestions = list);
      } finally {
        if (mounted) setState(() => _suggestionLoading = false);
      }
    });
  }

  Future<void> _performSearch([String? raw]) async {
    final query = (raw ?? _queryCtrl.text).trim();
    if (query.isEmpty) return;
    setState(() {
      _isSearching = true;
    });
    FocusScope.of(context).unfocus();
    _queryCtrl.text = query;
    await _saveRecent(query);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_search_keyword', query);
    if (!mounted) return;
    
    await Navigator.of(context).pushNamed(
      AppRoutes.searchResults,
      arguments: query,
    );

    if (mounted) {
      setState(() {
        _isSearching = false;
      });
      final q = _queryCtrl.text.trim();
      if (q.isNotEmpty) {
        _onQueryChanged(q);
      } else {
        _loadRecent();
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.removeListener(_onTextChanged);
    _queryCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(
                top: 8,
                bottom: MediaQuery.sizeOf(context).width < 360 ? 8 : 10,
              ),
              child: AppSearchBar.editable(
                controller: _queryCtrl,
                focusNode: _focusNode,
                autofocus: !widget.embedded,
                hintText: 'Search products',
                showBackButton: !widget.embedded,
                onBack: () => Navigator.of(context).pop(),
                onChanged: _onQueryChanged,
                onSubmitted: _performSearch,
                onClear: () {
                  _queryCtrl.clear();
                  _onQueryChanged('');
                },
              ),
            ),
          ),
          Expanded(child: _buildDiscovery()),
        ],
      ),
    );
  }

  Widget _buildDiscovery() {
    final q = _queryCtrl.text.trim();
    if (q.isNotEmpty) {
      if (_suggestionLoading || _isSearching) {
        return const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFFB5404),
          ),
        );
      }
      if (_suggestions.isEmpty) {
        return Center(
          child: Text(
            'No suggestions for "$q"',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 52, color: Color(0xFFF3F4F6)),
        itemBuilder: (_, i) {
          final s = _suggestions[i];
          return ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.search_rounded,
                  size: 18, color: Color(0xFF6B7280)),
            ),
            title: Text(
              s,
              style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
            ),
            trailing: const Icon(Icons.north_west_rounded,
                size: 16, color: Color(0xFF9CA3AF)),
            onTap: () => _performSearch(s),
          );
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        if (_recent.isNotEmpty) ...[
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Searches',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setStringList('recent_searches', const []);
                  if (!mounted) return;
                  setState(() => _recent = const []);
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFB5404),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                child: const Text('Clear All'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recent
                .map(
                  (r) => ActionChip(
                    backgroundColor: const Color(0xFFF9FAFB),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    avatar: const Icon(Icons.history_rounded,
                        size: 14, color: Color(0xFF6B7280)),
                    label: Text(
                      r,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF374151)),
                    ),
                    onPressed: () => _performSearch(r),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
        ],
        const Text(
          'Browse Categories',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Color(0xFF111827),
          ),
        ),
        if (_categoriesLoading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFFB5404),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length.clamp(0, 9),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.sizeOf(context).width < 360 ? 3 : 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio:
                  MediaQuery.sizeOf(context).width < 360 ? 0.95 : 1.05,
            ),
            itemBuilder: (_, i) {
              final c = _categories[i];
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _performSearch(c.name),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    color: Colors.white,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Image.network(
                          c.iconUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.category_outlined,
                              color: Color(0xFF9CA3AF)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildPromoCard(),
          _buildWishlistSection(),
      ],
    );
  }

  Widget _buildPromoCard() {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        border: Border.all(color: const Color(0xFFEDF2F7)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top Brands. Best Deals.',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Explore 1000+ brands and get the best offers every day!',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF6B7280),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.searchResults,
                      arguments: 'All Categories',
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFB5404),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    child: const Text(
                      'Shop Now',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Image.asset(
            'assets/vector/bag_vector.png',
            width: 48,
            height: 48,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.shopping_bag_outlined,
              size: 48,
              color: Color(0xFFFB5404),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistSection() {
    if (_wishlistLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFFB5404),
          ),
        ),
      );
    }

    if (_wishlistPreview.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayItems = _wishlistPreview.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Your wishlist',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(
              child: Divider(
                height: 1.5,
                thickness: 1.5,
                color: Color(0xFFFB5404),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.wishlist).then((_) {
                  _fetchWishlistPreview();
                });
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'See your wishlist',
                  style: TextStyle(
                    color: Color(0xFFFB5404),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const Expanded(
              child: Divider(
                height: 1.5,
                thickness: 1.5,
                color: Color(0xFFFB5404),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: displayItems.isNotEmpty
                  ? _buildWishlistMiniCard(displayItems[0])
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: displayItems.length > 1
                  ? _buildWishlistMiniCard(displayItems[1])
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            Navigator.of(context).pushNamed(AppRoutes.wishlist).then((_) {
              _fetchWishlistPreview();
            });
          },
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFB5404).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFFB5404).withValues(alpha: 0.16),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: const Text(
              'View all wishlist product',
              style: TextStyle(
                color: Color(0xFFFB5404),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWishlistMiniCard(WishlistItem item) {
    final p = item.product;
    final imageUrl = p.thumbnailImage.isNotEmpty
        ? 'https://d1f02fefkbso7w.cloudfront.net/${p.thumbnailImage}'
        : '';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          AppRoutes.product,
          arguments: _toProductItem(p),
        ).then((_) {
          _fetchWishlistPreview();
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEDEDED), width: 0.7),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1.2,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl.isEmpty
                    ? const Icon(Icons.image_outlined, color: Colors.grey)
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              p.brand.trim().isEmpty || p.brand.trim().toLowerCase() == 'no brand'
                  ? ' '
                  : p.brand.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              p.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '₹${_cleanPrice(p.sellingPrice).toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFB5404),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
