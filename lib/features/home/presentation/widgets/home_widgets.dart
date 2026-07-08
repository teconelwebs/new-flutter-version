import 'package:flutter/material.dart';

import '../../data/home_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../account/data/account_api_service.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.city,
    required this.pincode,
    required this.onSearchTap,
  });

  final String city;
  final String pincode;
  final VoidCallback onSearchTap;
  static const _brandLogoUrl = 'https://welfog.com/assets/crux/welf.png';

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(12, topInset > 0 ? 6 : 10, 12, 6),
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
                  'Deliver to $city - $pincode',
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
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Image.network(
                      _brandLogoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Text(
                        'Welfog',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.favorite_border_rounded,
                    color: Color(0xFFFB5404)),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none_rounded,
                    color: Color(0xFFFB5404)),
              ),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: GestureDetector(
            onTap: onSearchTap,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE8E8E8)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: const Row(
                children: [
                  Icon(Icons.search, color: Color(0xFF666666), size: 20),
                  SizedBox(width: 10),
                  Text('Search for ', style: TextStyle(color: Color(0xFF999999))),
                  Text(
                    'Mobile',
                    style: TextStyle(
                      color: Color(0xFFF47405),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class BannerCarousel extends StatefulWidget {
  const BannerCarousel({
    super.key,
    required this.items,
  });

  final List<HomeBanner> items;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 125,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final banner = widget.items[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    banner.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFECEFF3),
                      child: const Center(child: Icon(Icons.image_not_supported)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.items.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: i == _index ? 24 : 8,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: i == _index ? const Color(0xFF2B2B2B) : const Color(0xFFCBD4D4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ProductStrip extends StatelessWidget {
  const ProductStrip({
    super.key,
    required this.title,
    required this.products,
    required this.onProductTap,
    this.onRightIconTap,
  });

  final String title;
  final List<HomeProduct> products;
  final void Function(HomeProduct product) onProductTap;
  final VoidCallback? onRightIconTap;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              GestureDetector(
                onTap: onRightIconTap,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFB5404),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x15FB5404),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 226,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final p = products[i];
              return HomeProductCard(
                product: p,
                onTap: () => onProductTap(p),
              );
            },
          ),
        ),
      ],
    );
  }
}

class HomeProductCard extends StatefulWidget {
  final HomeProduct product;
  final VoidCallback onTap;

  const HomeProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  State<HomeProductCard> createState() => _HomeProductCardState();
}

class _HomeProductCardState extends State<HomeProductCard> {
  final _apiService = AccountApiService();
  bool _isWishlisted = false;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _checkWishlistState();
  }

  @override
  void didUpdateWidget(HomeProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) {
      _checkWishlistState();
    }
  }

  Future<void> _checkWishlistState() async {
    final prefs = await SharedPreferences.getInstance();
    final wishState = prefs.getString('wishlist_state_${widget.product.id}');
    if (mounted) {
      setState(() {
        _isWishlisted = wishState == 'true';
      });
    }
  }

  Future<void> _toggleWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to add items to wishlist'),
            backgroundColor: Color(0xFFFB5404),
          ),
        );
      }
      return;
    }

    setState(() => _toggling = true);

    try {
      if (_isWishlisted) {
        final compareMapStr = prefs.getString('wishlist_compare_map') ?? '{}';
        final compareMap = Map<String, dynamic>.from(jsonDecode(compareMapStr));
        final compareIdStr = compareMap[widget.product.id.toString()];
        final compareId = int.tryParse(compareIdStr ?? '') ?? 0;

        final success = await _apiService.removeWishlistItem(widget.product.id, compareId);
        if (success) {
          setState(() {
            _isWishlisted = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Item removed from wishlist'),
                 // ignore: deprecated_member_use
                backgroundColor: const Color(0xFF222222).withOpacity(0.85),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                duration: const Duration(milliseconds: 1000),
              ),
            );
          }
        }
      } else {
        final success = await _apiService.addWishlistItem(widget.product.id);
        if (success) {
          setState(() {
            _isWishlisted = true;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Item added to wishlist'),
                 // ignore: deprecated_member_use
                backgroundColor: const Color(0xFF222222).withOpacity(0.85),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                duration: const Duration(milliseconds: 1000),
              ),
            );
          }
        }
      }
    } catch (_) {
      // Ignore
    } finally {
      if (mounted) {
        setState(() => _toggling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final discount = p.mrp > p.price && p.price > 0
        ? (((p.mrp - p.price) / p.mrp) * 100).round()
        : 0;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 158,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEDEDED)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                      child: Image.network(
                        p.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFF2F4F7),
                          child: const Center(child: Icon(Icons.shopping_bag_outlined)),
                        ),
                      ),
                    ),
                  ),
                  if (discount > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFB5404),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$discount% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: _toggling ? null : _toggleWishlist,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          // ignore: deprecated_member_use
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x10000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _toggling
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFB5404)),
                                  ),
                                )
                              : Icon(
                                  _isWishlisted ? Icons.favorite : Icons.favorite_border,
                                  color: _isWishlisted ? const Color(0xFFFB5404) : const Color(0xFF777777),
                                  size: 16,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.2,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        'Rs ${p.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0B7E7B),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (p.mrp > p.price)
                        Text(
                          'Rs ${p.mrp.toStringAsFixed(0)}',
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Color(0xFF9AA0A6),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
