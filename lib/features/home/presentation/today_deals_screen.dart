import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
      videoUrl: p.videoUrl,
      videoLink: p.videoLink,
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Top Deals for You',
              style: TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            SvgPicture.string(
              '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#FB5404" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"></path><line x1="7" y1="7" x2="7.01" y2="7"></line></svg>''',
            ),
          ],
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

    // Split list into left and right columns for masonry layout
    final totalCount = _products.length + (_loading && _hasMore ? 2 : 0);
    final leftColumnItems = [];
    final rightColumnItems = [];
    
    for (int i = 0; i < totalCount; i++) {
      if (i < _products.length) {
        final p = _products[i];
        if (i % 2 == 0) {
          leftColumnItems.add(p);
        } else {
          rightColumnItems.add(p);
        }
      } else {
        // Skeleton loader
        if (i % 2 == 0) {
          leftColumnItems.add(null);
        } else {
          rightColumnItems.add(null);
        }
      }
    }

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: leftColumnItems.map((p) {
                if (p == null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      height: 180,
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
                    ),
                  );
                }
                
                final originalIndex = _products.indexOf(p);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: HomeProductCard(
                    product: p,
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        AppRoutes.product,
                        arguments: _toProductItem(p, originalIndex),
                      );
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
                if (p == null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      height: 180,
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
                    ),
                  );
                }
                
                final originalIndex = _products.indexOf(p);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: HomeProductCard(
                    product: p,
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        AppRoutes.product,
                        arguments: _toProductItem(p, originalIndex),
                      );
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
