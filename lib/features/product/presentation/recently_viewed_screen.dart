import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_routes.dart';
import '../../home/data/home_models.dart';
import '../../home/presentation/widgets/home_widgets.dart';
import '../data/models/product_item.dart';

class RecentlyViewedScreen extends StatefulWidget {
  const RecentlyViewedScreen({super.key});

  @override
  State<RecentlyViewedScreen> createState() => _RecentlyViewedScreenState();
}

class _RecentlyViewedScreenState extends State<RecentlyViewedScreen> {
  final List<HomeProduct> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentlyViewed();
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  Future<void> _loadRecentlyViewed() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedStr = prefs.getString('recently_viewed');
      if (cachedStr != null) {
        final decoded = jsonDecode(cachedStr);
        if (decoded is List) {
          final List<HomeProduct> loaded = decoded.map((item) {
            return HomeProduct(
              id: _toInt(item['id']),
              name: (item['name'] ?? '').toString(),
              price: _toDouble(item['price']),
              mrp: _toDouble(item['mrp'] ?? item['price']),
              image: (item['image'] ?? '').toString(),
              slug: (item['slug'] ?? '').toString(),
              duration: _toInt(item['duration']),
              brand: (item['brand'] ?? '').toString(),
              rating: _toDouble(item['rating'] ?? 4.3),
            );
          }).toList();

          setState(() {
            _products.clear();
            _products.addAll(loaded);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading recently viewed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  ProductItem _toProductItem(HomeProduct p, int index) {
    const fallbackColors = [
      Color(0xFFFFD9D9),
      Color(0xFFDDF4FF),
      Color(0xFFE8FFE1),
      Color(0xFFFFF0CC),
      Color(0xFFF3E8FF),
    ];
    return ProductItem(
      id: p.id.toString(),
      title: p.name,
      subtitle: p.brand.isEmpty ? 'Fast delivery' : p.brand,
      price: p.price,
      rating: p.rating,
      color: fallbackColors[index % fallbackColors.length],
      imageUrl: p.image,
      slug: p.slug,
      brand: p.brand,
      durationMinutes: p.duration,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A1A), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Recently Viewed',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(
            color: const Color(0xFFE5E7EB),
            height: 0.5,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFB5404)),
        ),
      );
    }

    if (_products.isEmpty) {
      return const Center(
        child: Text(
          'No recently viewed products.',
          style: TextStyle(
            color: Color(0xFF666666),
            fontSize: 14,
          ),
        ),
      );
    }

    // Split list into left and right columns for masonry layout
    final leftColumnItems = [];
    final rightColumnItems = [];
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
              children: leftColumnItems.map((p) {
                final originalIndex = _products.indexOf(p);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: HomeProductCard(
                    product: p,
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        AppRoutes.product,
                        arguments: _toProductItem(p, originalIndex),
                      ).then((_) {
                        _loadRecentlyViewed();
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rightColumnItems.map((p) {
                final originalIndex = _products.indexOf(p);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: HomeProductCard(
                    product: p,
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        AppRoutes.product,
                        arguments: _toProductItem(p, originalIndex),
                      ).then((_) {
                        _loadRecentlyViewed();
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
