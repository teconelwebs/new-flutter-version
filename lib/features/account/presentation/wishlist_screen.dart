import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/state/cart_state.dart';
import '../data/account_api_service.dart';
import '../../product/data/models/product_item.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> with SingleTickerProviderStateMixin {
  final AccountApiService _apiService = AccountApiService();
  List<WishlistItem> _wishlist = [];
  bool _loading = true;
  int? _removingId;
  int? _addingToCartId;

  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _fetchWishlist();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _fetchWishlist({bool force = false}) async {
    if (force || _wishlist.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = true;
        });
      }
    }

    final items = await _apiService.fetchWishlist();

    if (mounted) {
      setState(() {
        _wishlist = items;
        _loading = false;
      });
    }

    // Sync wishlist count in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wishlist_count', items.length.toString());

    // Also sync individual wishlist state flags
    for (final item in items) {
      await prefs.setString('wishlist_state_${item.product.id}', 'true');
    }
  }

  Future<void> _onRefresh() async {
    await _fetchWishlist(force: true);
  }

  bool _isOutOfStock(WishlistItem item) {
    if (item.product.isOutOfStock == true) {
      return true;
    }
    final stockStr = item.product.stock ?? item.product.quantity ?? '0';
    final stock = int.tryParse(stockStr) ?? 0;
    return stock <= 0;
  }

  double _cleanPrice(String priceStr) {
    final cleaned = priceStr.replaceAll(RegExp(r'[Rr][Ss]|₹|\s'), '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  String _formatPrice(String priceStr) {
    final price = _cleanPrice(priceStr);
    return '₹${price.toStringAsFixed(0)}';
  }

  int _calculateDiscount(String basePriceStr, String sellingPriceStr) {
    final base = _cleanPrice(basePriceStr);
    final selling = _cleanPrice(sellingPriceStr);
    if (base <= 0 || selling <= 0 || base <= selling) return 0;
    return (((base - selling) / base) * 100).round();
  }

  double _getRating(String ratingStr) {
    return double.tryParse(ratingStr) ?? 0.0;
  }

  void _showCustomPopup(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(
                fontWeight: FontWeight.w500, letterSpacing: 0.3)),
        // ignore: deprecated_member_use
        backgroundColor: const Color(0xFF222222).withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 80,
          left: 24,
          right: 24,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleRemoveItem(WishlistItem item) async {
    // Instantly update local UI list state
    setState(() {
      _wishlist.removeWhere((element) => element.id == item.id);
    });

    // Show custom black bottom popup snackbar
    _showCustomPopup('Item removed');

    // Call background API to remove product
    try {
      final success = await _apiService.removeWishlistItem(item.product.id, item.compareId);
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('wishlist_state_${item.product.id}', 'false');
        await prefs.setString('wishlist_count', _wishlist.length.toString());
      }
    } catch (_) {
      // Fail silently to keep user experience fluent
    }
  }

  Future<void> _handleAddToCart(WishlistItem item) async {
    if (_isOutOfStock(item)) return;

    setState(() {
      _addingToCartId = item.product.id;
    });

    final success = await _apiService.addToCart(item.product.id);

    if (mounted) {
      setState(() {
        _addingToCartId = null;
      });
    }

    if (success) {
      // Increment global cart notifier
      final current = CartState.cartCountNotifier.value;
      await CartState.updateCartCount(current + 1);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Added to Cart!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            backgroundColor: const Color(0xB3111111),
            behavior: SnackBarBehavior.floating,
            width: MediaQuery.sizeOf(context).width * 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add item to cart.'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleProductPress(WishlistItem item) {
    Navigator.of(context).pushNamed(
      AppRoutes.product,
      arguments: ProductItem(
        id: item.product.id.toString(),
        title: item.product.name,
        subtitle: '',
        price: _cleanPrice(item.product.sellingPrice),
        rating: _getRating(item.product.rating),
        color: Colors.transparent,
        imageUrl: 'https://d1f02fefkbso7w.cloudfront.net/${item.product.thumbnailImage}',
        slug: item.product.link,
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final opacity = 0.3 + (_shimmerController.value * 0.4);
        final screenWidth = MediaQuery.of(context).size.width;
        final double childAspectRatio = screenWidth < 360 ? 0.62 : (screenWidth < 400 ? 0.66 : 0.68);
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: 6,
          itemBuilder: (ctx, idx) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF0F0F0)),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Opacity(
                  opacity: opacity,
                  child: Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Opacity(
                  opacity: opacity,
                  child: Container(
                    height: 14,
                    width: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Opacity(
                  opacity: opacity,
                  child: Container(
                    height: 16,
                    width: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return const SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 100),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_rounded,
                size: 70,
                color: Color(0xFFFB5404),
              ),
              SizedBox(height: 16),
              Text(
                'Your wishlist is empty',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF666666),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Explore our collection and save your favorites here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF999999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWishlistGrid() {
    final leftColumnItems = <WishlistItem>[];
    final rightColumnItems = <WishlistItem>[];
    for (int i = 0; i < _wishlist.length; i++) {
      if (i % 2 == 0) {
        leftColumnItems.add(_wishlist[i]);
      } else {
        rightColumnItems.add(_wishlist[i]);
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
              children: leftColumnItems.map((item) => _buildWishlistCard(item)).toList(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rightColumnItems.map((item) => _buildWishlistCard(item)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistCard(WishlistItem item) {
    final isOutOfStock = _isOutOfStock(item);
    final basePrice = _cleanPrice(item.product.basePrice);
    final sellingPrice = _cleanPrice(item.product.sellingPrice);
    final discount = _calculateDiscount(item.product.basePrice, item.product.sellingPrice);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.black12,
          width: 0.7,
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Product Image container
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => _handleProductPress(item),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: Opacity(
                        opacity: isOutOfStock ? 0.6 : 1.0,
                        child: Image.network(
                          'https://d1f02fefkbso7w.cloudfront.net/${item.product.thumbnailImage}',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.image_outlined,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isOutOfStock)
                    Container(
                      color: const Color(0x4D000000),
                      child: const Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'OUT OF STOCK',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Floating Action buttons
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Row(
                      children: [
                        // Cart Action
                        GestureDetector(
                          onTap: isOutOfStock ? null : () => _handleAddToCart(item),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isOutOfStock ? const Color(0xFFE5E7EB) : const Color(0xFFECFDF5),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isOutOfStock ? const Color(0xFFD1D5DB) : const Color(0xFFBBF7D0),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 1,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _addingToCartId == item.product.id
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
                                      ),
                                    )
                                  : Icon(
                                      Icons.shopping_bag_outlined,
                                      size: 14,
                                      color: isOutOfStock ? const Color(0xFF9CA3AF) : const Color(0xFF16A34A),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Delete Action
                        GestureDetector(
                          onTap: _removingId == item.id ? null : () => _handleRemoveItem(item),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 1,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _removingId == item.id
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 14,
                                      color: Color(0xFFEF4444),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Name
          GestureDetector(
            onTap: () => _handleProductPress(item),
            child: Text(
              item.product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
                height: 1.3,
              ),
            ),
          ),
          // Brand (dynamic height layout tag)
          if (item.product.brand.trim().isNotEmpty &&
              item.product.brand.trim().toLowerCase() != 'no brand') ...[
            const SizedBox(height: 4),
            Text(
              item.product.brand.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6E7380),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Price block
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (basePrice > sellingPrice) ...[
                Text(
                  _formatPrice(item.product.basePrice),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF999999),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                _formatPrice(item.product.sellingPrice),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          if (basePrice > sellingPrice && discount > 0) ...[
            const SizedBox(height: 2),
            Text(
              '$discount% off',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF22C55E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Wishlist',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF333333)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFFE5E5E5),
            height: 0.5,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFFFB5404),
        child: _loading
            ? _buildShimmerGrid()
            : _wishlist.isEmpty
                ? _buildEmptyState()
                : _buildWishlistGrid(),
      ),
    );
  }
}
