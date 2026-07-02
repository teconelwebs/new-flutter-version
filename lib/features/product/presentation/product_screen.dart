import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../data/models/product_item.dart';
import '../data/product_api_service.dart';
import 'widgets/product_card.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key, this.item});

  final ProductItem? item;

  static const routeName = AppRoutes.product;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final ProductApiService _api = ProductApiService();
  final PageController _galleryController = PageController();

  ProductDetailData? _detail;
  ProductReviewBundle _reviews = ProductReviewBundle.empty();
  List<ProductItem> _related = const [];

  bool _loading = true;
  String? _error;
  int _qty = 1;
  int _selectedImage = 0;
  _ProductTab _activeTab = _ProductTab.details;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final seed = widget.item;
    if (seed == null) {
      setState(() {
        _loading = false;
        _error = 'Product not found';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final slugOrId = seed.slug.trim().isNotEmpty ? seed.slug.trim() : seed.id;
      final detail = await _api.fetchProductDetail(slugOrId: slugOrId, productId: seed.id);
      final reviews = await _api.fetchReviews(detail.id);
      final related = await _api.fetchRelatedProducts(detail.id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _reviews = reviews;
        _related = related.where((p) => p.id != detail.id).take(6).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFfb5404)),
        ),
      );
    }

    if (_error != null || _detail == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'Product not found'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _load,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final detail = _detail!;
    final avg = _reviews.averageRating > 0 ? _reviews.averageRating : detail.rating;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _ProductHeader(
              onBack: () => Navigator.of(context).maybePop(),
              onSearch: () => Navigator.of(context).pushNamed(AppRoutes.search),
              onWishlist: () {},
              onShare: () {},
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
                  children: [
                    _buildImageGallery(detail),
                    const SizedBox(height: 14),
                    _buildDetailsCard(detail, avg),
                    const SizedBox(height: 12),
                    _buildQuantityCard(detail.stock),
                    const SizedBox(height: 12),
                    _buildOtherDetailsCard(detail, avg),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.cart),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: Color(0xFF111111)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Add to Cart', style: TextStyle(color: Color(0xFF111111))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.cart),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF008083),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Buy Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGallery(ProductDetailData detail) {
    final images = detail.images.isEmpty ? [''] : detail.images;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 320,
            child: PageView.builder(
              controller: _galleryController,
              itemCount: images.length,
              onPageChanged: (index) => setState(() => _selectedImage = index),
              itemBuilder: (context, index) {
                final imageUrl = images[index];
                if (imageUrl.isEmpty) {
                  return const Center(
                    child: Icon(Icons.shopping_bag_outlined, size: 72, color: Color(0xFF9CA3AF)),
                  );
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.image_not_supported_outlined, size: 42, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              images.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                width: _selectedImage == index ? 14 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _selectedImage == index ? const Color(0xFFfb5404) : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(ProductDetailData detail, double avgRating) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.brand.trim().isNotEmpty)
            Text(
              'Brand: ${detail.brand}',
              style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 4),
          Text(
            detail.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
          ),
          if (_reviews.totalReviews > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                ...List.generate(
                  5,
                  (index) => Icon(
                    index < avgRating.floor() ? Icons.star_rounded : Icons.star_border_rounded,
                    color: const Color(0xFFFDB040),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${avgRating.toStringAsFixed(1)} (${_reviews.totalReviews} Reviews)',
                  style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${detail.sellPrice.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: Color(0xFFfb5404)),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${detail.mrpPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.lineThrough,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              const Spacer(),
              Text(
                '${detail.discountPercent}%',
                style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w800, fontSize: 17),
              ),
              const Icon(Icons.arrow_downward_rounded, size: 16, color: Color(0xFF16A34A)),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Inclusive of all taxes',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF16A34A), fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityCard(int stock) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: stock <= 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF3F4F6),
            ),
            child: Text(
              stock <= 0 ? 'Out of stock' : '($stock) left',
              style: TextStyle(
                color: stock <= 0 ? const Color(0xFFDC2626) : const Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('$_qty', style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            onPressed: () => setState(() => _qty++),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherDetailsCard(ProductDetailData detail, double avgRating) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabs(),
          const SizedBox(height: 12),
          if (_activeTab == _ProductTab.details) _buildDetailsTab(detail),
          if (_activeTab == _ProductTab.description) _buildDescriptionTab(detail),
          if (_activeTab == _ProductTab.reviews) _buildReviewsTab(avgRating),
          const SizedBox(height: 18),
          Row(
            children: [
              const Text('Suggested Products', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.home),
                child: const Text('Explore All', style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const Divider(height: 18, color: Color(0xFFE5E7EB)),
          if (_related.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(child: Text('No related products found')),
            )
          else
            GridView.builder(
              itemCount: _related.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.65,
              ),
              itemBuilder: (context, index) => ProductCard(item: _related[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Row(
      children: _ProductTab.values.map((tab) {
        final selected = _activeTab == tab;
        final label = switch (tab) {
          _ProductTab.details => 'Product Details',
          _ProductTab.description => 'Description',
          _ProductTab.reviews => 'Customer Reviews',
        };
        return Expanded(
          child: InkWell(
            onTap: () => setState(() => _activeTab = tab),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected ? const Color(0xFFfb5404) : const Color(0xFFE5E7EB),
                    width: selected ? 2.5 : 1,
                  ),
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? const Color(0xFFfb5404) : const Color(0xFF6B7280),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailsTab(ProductDetailData detail) {
    final features = detail.features.entries.toList();
    return Column(
      children: [
        Container(
          color: const Color(0xFF008083),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: const Row(
            children: [
              Expanded(child: Text('Product Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
              Expanded(child: Text('Value', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
            ],
          ),
        ),
        _SpecsRow(name: 'Brand', value: detail.brand.isEmpty ? 'Welfog' : detail.brand),
        _SpecsRow(name: 'SKU', value: detail.id),
        ...features.take(8).map((e) => _SpecsRow(name: e.key, value: e.value)),
      ],
    );
  }

  Widget _buildDescriptionTab(ProductDetailData detail) {
    final text = detail.shortDescription.trim().isNotEmpty
        ? detail.shortDescription
        : detail.description.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return Text(
      text.isEmpty ? 'No description available.' : text,
      style: const TextStyle(color: Color(0xFF4B5563), height: 1.5),
    );
  }

  Widget _buildReviewsTab(double avgRating) {
    if (_reviews.totalReviews <= 0) {
      return const Text('No reviews available.');
    }
    final bars = [5, 4, 3, 2, 1];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              avgRating.toStringAsFixed(1),
              style: const TextStyle(color: Color(0xFF388E3C), fontWeight: FontWeight.w800, fontSize: 42),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.star_rounded, color: Color(0xFF388E3C), size: 22),
            const SizedBox(width: 12),
            Text(
              '(${_reviews.totalReviews} Reviews)',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12.5),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...bars.map((stars) {
          final pct = _reviews.percentages[stars] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 86,
                  child: Row(
                    children: List.generate(
                      5,
                      (index) => Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: index < stars ? const Color(0xFFFDB040) : const Color(0xFFE5E7EB),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: pct / 100,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF8B8B8B)),
                      backgroundColor: const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text(
                    '$pct%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        const Text('Product Ratings & Reviews', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        ..._reviews.reviews.take(8).map(
          (r) => _ReviewTile(
            userName: r.userName,
            date: r.dateText,
            rating: r.rating,
            review: r.comment,
          ),
        ),
      ],
    );
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({
    required this.onBack,
    required this.onSearch,
    required this.onWishlist,
    required this.onShare,
  });

  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onWishlist;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.chevron_left_rounded, size: 28, color: Color(0xFF111827))),
          const Spacer(),
          IconButton(onPressed: onSearch, icon: const Icon(Icons.search_rounded, color: Color(0xFFDC2626))),
          IconButton(onPressed: onWishlist, icon: const Icon(Icons.favorite_border_rounded, color: Color(0xFFDC2626))),
          IconButton(onPressed: onShare, icon: const Icon(Icons.share_outlined, color: Color(0xFFDC2626))),
        ],
      ),
    );
  }
}

enum _ProductTab { details, description, reviews }

class _SpecsRow extends StatelessWidget {
  const _SpecsRow({required this.name, required this.value});
  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
      child: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: const TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.userName,
    required this.date,
    required this.rating,
    required this.review,
  });

  final String userName;
  final String date;
  final int rating;
  final String review;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 14, backgroundColor: const Color(0xFFE5E7EB), child: Text(userName.isEmpty ? 'U' : userName[0])),
              const SizedBox(width: 8),
              Expanded(child: Text(userName, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(date, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(
              5,
              (index) => Icon(index < rating ? Icons.star_rounded : Icons.star_border_rounded, size: 14, color: const Color(0xFFFDB040)),
            ),
          ),
          const SizedBox(height: 6),
          Text(review, style: const TextStyle(color: Color(0xFF4B5563), height: 1.4)),
        ],
      ),
    );
  }
}
