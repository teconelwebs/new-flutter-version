import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../product/data/models/product_item.dart';
import '../data/home_api_service.dart';
import '../data/home_models.dart';
import 'widgets/home_widgets.dart';

class TodayDealsScreen extends StatefulWidget {
  const TodayDealsScreen({super.key});

  @override
  State<TodayDealsScreen> createState() => _TodayDealsScreenState();
}

class _TodayDealsScreenState extends State<TodayDealsScreen> {
  final _api = HomeApiService();
  final _scrollController = ScrollController();

  final List<HomeProduct> _products = [];
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loading && _hasMore) {
        _page++;
        _fetch();
      }
    }
  }

  Future<void> _fetch() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _api.fetchTodayDealsPaged(_page);
      setState(() {
        _loading = false;
        if (list.isEmpty) {
          _hasMore = false;
        } else {
          _products.addAll(list);
          if (list.length < 10) {
            _hasMore = false;
          }
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load today deals. Try again.';
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _products.clear();
      _page = 1;
      _hasMore = true;
      _error = null;
    });
    await _fetch();
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
          'Top Deals for You 🔥',
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
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFFFB5404),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_products.isEmpty) {
      if (_loading) {
        return const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFB5404)),
          ),
        );
      }
      if (_error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 48),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _fetch,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFB5404),
                    side: const BorderSide(color: Color(0xFFFB5404)),
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        );
      }
      return const Center(
        child: Text('No deals available today.'),
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final childAspectRatio = homeProductGridAspectRatio(screenWidth);

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: _products.length + (_loading && _hasMore ? 2 : 0),
      itemBuilder: (context, index) {
        if (index >= _products.length) {
          // Render a simple loading skeleton or indicator
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEDEDED)),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFB5404)),
                ),
              ),
            ),
          );
        }

        final p = _products[index];
        return HomeProductCard(
          product: p,
          onTap: () {
            Navigator.of(context).pushNamed(
              AppRoutes.product,
              arguments: _toProductItem(p, index),
            );
          },
        );
      },
    );
  }
}
