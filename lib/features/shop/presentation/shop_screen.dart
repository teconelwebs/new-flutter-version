import 'package:flutter/material.dart';

import '../data/shop_api_service.dart';
import '../data/shop_models.dart';
import '../../../core/constants/app_routes.dart';
import '../../product/data/models/product_item.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({
    super.key,
    required this.shopId,
    required this.slug,
  });

  final String shopId;
  final String slug;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _api = ShopApiService();

  ShopDetail? _shopDetail;
  List<ShopProduct> _products = [];
  int _page = 1;
  int _totalPages = 1;
  bool _loadingDetail = true;
  bool _loadingProducts = true;
  bool _refreshing = false;
  double _bannerAspectRatio = 16 / 7;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    await Future.wait([_fetchDetail(), _fetchProducts()]);
  }

  Future<void> _fetchDetail() async {
    if (!_refreshing) setState(() => _loadingDetail = true);
    final detail = await _api.fetchShopDetails(
      shopId: widget.shopId,
      slug: widget.slug,
    );
    if (mounted) {
      setState(() {
        _shopDetail = detail;
        _loadingDetail = false;
      });
      if (detail != null && detail.bannerUrl.isNotEmpty) {
        _loadBannerAspectRatio(detail.bannerUrl);
      }
    }
  }

  void _loadBannerAspectRatio(String url) {
    final image = NetworkImage(url);
    image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        final ratio = info.image.width / info.image.height;
        if (mounted && ratio > 0 && ratio != _bannerAspectRatio) {
          setState(() => _bannerAspectRatio = ratio);
        }
      }),
    );
  }

  Future<void> _fetchProducts() async {
    if (!_refreshing) setState(() => _loadingProducts = true);
    final result = await _api.fetchShopProducts(
      shopId: widget.shopId,
      slug: widget.slug,
      page: _page,
    );
    if (mounted) {
      setState(() {
        _products = result.products;
        _totalPages = result.totalPages;
        _loadingProducts = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => _refreshing = true);
    _page = 1;
    await _fetchAll();
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _changePage(int newPage) async {
    setState(() {
      _page = newPage;
      _loadingProducts = true;
    });
    await _fetchProducts();
  }

  static String _calcDelivery(int minutes) {
    if (minutes <= 0) return '2 - 4 days';
    final days = minutes ~/ 1440;
    if (days > 0) return '$days - ${days + 1} days';
    final hours = (minutes % 1440) ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) return '$hours hr${hours > 1 ? 's' : ''}';
    if (mins > 0) return '$mins min${mins > 1 ? 's' : ''}';
    return '2 - 4 days';
  }

  void _openProduct(ShopProduct p) {
    final item = ProductItem(
      id: p.id,
      title: p.name,
      subtitle: p.brand,
      price: p.newPrice > 0 ? p.newPrice : p.oldPrice,
      rating: double.tryParse(p.rating) ?? 0,
      color: const Color(0xFFFB5404),
      imageUrl: p.imageUrl,
      slug: p.slug,
      brand: p.brand,
      durationMinutes: p.durationMinutes,
    );
    Navigator.of(context).pushNamed(AppRoutes.product, arguments: item);
  }

  static double _gridAspectRatio(double screenWidth) {
    if (screenWidth < 360) return 0.64;
    if (screenWidth < 400) return 0.67;
    return 0.70;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = (screenWidth - 36) / 2;
    final gridAspectRatio = _gridAspectRatio(screenWidth);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            // Scrollable content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                color: const Color(0xFFFB5404),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (_loadingDetail)
                      SliverToBoxAdapter(child: _buildShopSkeleton())
                    else if (_shopDetail != null)
                      SliverToBoxAdapter(child: _buildShopHeader(screenWidth))
                    else
                      const SliverToBoxAdapter(child: SizedBox.shrink()),

                    // "All Products" label
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                        child: Text(
                          'All Products',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                    ),

                    // Products grid
                    if (_loadingProducts)
                      SliverToBoxAdapter(child: _buildProductsSkeleton(cardWidth))
                    else if (_products.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: Column(
                              children: const [
                                Icon(Icons.shopping_bag_outlined, size: 48, color: Color(0xFFCCCCCC)),
                                SizedBox(height: 12),
                                Text(
                                  'No products found',
                                  style: TextStyle(color: Color(0xFF888888), fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildProductCard(_products[index]),
                            childCount: _products.length,
                          ),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: gridAspectRatio,
                          ),
                        ),
                      ),

                    // Pagination
                    if (_totalPages > 1)
                      SliverToBoxAdapter(child: _buildPagination()),

                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 10),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.chevron_left, size: 26, color: Color(0xFF111111)),
          ),
          const Expanded(
            child: Text(
              'Shop',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111111),
              ),
            ),
          ),
          const SizedBox(width: 44), // Balance for back button
        ],
      ),
    );
  }

  Widget _buildShopHeader(double screenWidth) {
    final detail = _shopDetail!;
    return Column(
      children: [
        // Banner with logo overlay
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Banner image
            AspectRatio(
              aspectRatio: _bannerAspectRatio,
              child: Image.network(
                detail.bannerUrl,
                width: screenWidth,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: screenWidth,
                  color: const Color(0x1FFB5404),
                  child: const Center(
                    child: Icon(Icons.store, size: 48, color: Color(0xFFFB5404)),
                  ),
                ),
              ),
            ),
            // Logo circle
            Positioned(
              bottom: -30,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x25000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    )
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: Image.network(
                    detail.logoUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 60,
                      height: 60,
                      color: const Color(0xFFF3F4F6),
                      child: const Icon(Icons.store, color: Color(0xFFFB5404)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Info section
        const SizedBox(height: 38),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Text(
                detail.name.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Rating badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          detail.rating,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.star, color: Colors.white, size: 12),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 1,
                    height: 12,
                    color: const Color(0xFFCCCCCC),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${detail.productCount} Products',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildShopSkeleton() {
    return Column(
      children: [
        // Banner skeleton
        Container(
          width: double.infinity,
          height: 160,
          color: const Color(0xFFE5E7EB),
        ),
        const SizedBox(height: 40),
        // Name skeleton
        Center(
          child: Container(
            width: 150,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildProductsSkeleton(double cardWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: List.generate(6, (_) {
          return Container(
            width: cardWidth,
            height: cardWidth * 1.6,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(10),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildProductCard(ShopProduct p) {
    final delivery = _calcDelivery(p.durationMinutes);
    final hasDiscount = p.oldPrice > p.newPrice && p.newPrice > 0;
    final discountPct = hasDiscount ? (((p.oldPrice - p.newPrice) / p.oldPrice) * 100).round() : 0;

    return GestureDetector(
      onTap: () => _openProduct(p),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(10)),
                      child: Image.network(
                        p.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFF2F4F7),
                          child: const Center(
                            child: Icon(Icons.shopping_bag_outlined,
                                color: Color(0xFFCCCCCC)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (discountPct > 0)
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
                          '$discountPct% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined,
                          size: 11, color: Color(0xFFFB5404)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          delivery,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (p.brand.isNotEmpty && p.brand != 'No Brand') ...[
                    const SizedBox(height: 3),
                    Text(
                      p.brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.2,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (p.newPrice > 0)
                        Flexible(
                          child: Text(
                            '₹${p.newPrice.toStringAsFixed(0)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                      if (hasDiscount) ...[
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '₹${p.oldPrice.toStringAsFixed(0)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PaginationButton(
            label: 'Prev',
            enabled: _page > 1,
            onTap: _page > 1 ? () => _changePage(_page - 1) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '$_page',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          _PaginationButton(
            label: 'Next',
            enabled: _page < _totalPages,
            onTap: _page < _totalPages ? () => _changePage(_page + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  const _PaginationButton({
    required this.label,
    required this.enabled,
    this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled ? const Color(0xFFFB5404) : const Color(0xFFCCCCCC),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: enabled ? const Color(0xFFFB5404) : const Color(0xFFCCCCCC),
          ),
        ),
      ),
    );
  }
}
