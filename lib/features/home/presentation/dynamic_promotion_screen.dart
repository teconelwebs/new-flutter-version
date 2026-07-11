import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../product/data/models/product_item.dart';
import '../../product/presentation/widgets/product_card.dart';

class DynamicPromotionScreen extends StatefulWidget {
  final String slug;

  const DynamicPromotionScreen({super.key, required this.slug});

  @override
  State<DynamicPromotionScreen> createState() => _DynamicPromotionScreenState();
}

class _DynamicPromotionScreenState extends State<DynamicPromotionScreen> {
  bool _loading = true;
  Map<String, dynamic>? _pageData;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchPromotionData();
  }

  Future<void> _fetchPromotionData() async {
    setState(() {
      _loading = true;
      _errorMessage = '';
    });

    try {
      final isNumber = RegExp(r'^\d+$').hasMatch(widget.slug);
      final apiUrl = isNumber
          ? 'https://welfogapi.welfog.com/api/v2/promotion/get?id=${widget.slug}'
          : 'https://welfogapi.welfog.com/api/v2/promotion/get?slug=${widget.slug}';

      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['page'] != null) {
          setState(() {
            _pageData = decoded['page'] as Map<String, dynamic>;
          });
        } else {
          setState(() {
            _errorMessage = 'Failed to load promotion details.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data. Please check your connection.';
      });
      debugPrint('Error fetching promotion data: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  ProductItem _toProductItem(Map<String, dynamic> p) {
    final imagePath = p['image']?.toString() ?? '';
    final imageUrl = imagePath.isNotEmpty
        ? (imagePath.startsWith('http') ? imagePath : 'https://d1f02fefkbso7w.cloudfront.net/$imagePath')
        : '';
    final durationVal = p['duration'];
    final durationMinVal = p['duration_minute'];
    final deliveryMinVal = p['delivery_time_minute'];
    debugPrint('=== BANNER PRODUCT ESTIMATE DELIVERY DEBUG ===');
    debugPrint('Product Name: ${p['name']}');
    debugPrint('raw duration: $durationVal');
    debugPrint('raw duration_minute: $durationMinVal');
    debugPrint('raw delivery_time_minute: $deliveryMinVal');
    debugPrint('=============================================');

    return ProductItem(
      id: p['id']?.toString() ?? '',
      title: p['name']?.toString() ?? '',
      subtitle: '',
      price: double.tryParse(p['price']?.toString() ?? '0.0') ?? 0.0,
      rating: 4.5,
      color: const Color(0xFFF3E8FF),
      imageUrl: imageUrl,
      slug: p['slug']?.toString() ?? p['id']?.toString() ?? '',
      brand: p['brand']?.toString() ?? '',
      durationMinutes: int.tryParse((p['duration'] ?? p['duration_minute'] ?? p['delivery_time_minute'] ?? '0').toString()) ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageTitle = _pageData != null
        ? _pageData!['slug']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'PROMOTION'
        : 'PROMOTION';

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
        title: Text(
          pageTitle,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
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
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFFB5404),
              )
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                    ),
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_pageData == null) return const SizedBox.shrink();
    final sections = _pageData!['sections'] as List? ?? [];

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 30),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index] as Map<String, dynamic>? ?? {};
        final type = section['type']?.toString() ?? '';
        final items = section['items'] as List? ?? [];

        if (items.isEmpty) return const SizedBox.shrink();

        switch (type) {
          case 'title':
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      item.toString(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: 0.3,
                        height: 1.3,
                      ),
                    ),
                  );
                }).toList(),
              ),
            );

          case 'description':
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      item.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4A4A4A),
                        height: 1.55,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  );
                }).toList(),
              ),
            );

          case 'banner':
            return _buildBannerSlider(items);

          case 'products':
            return _buildProductsGrid(items);

          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildBannerSlider(List items) {
    return _BannerSliderWidget(items: items);
  }

  Widget _buildProductsGrid(List items) {
    final products = items.map((item) {
      final productMap = (item as Map<String, dynamic>? ?? {})['product'] as Map<String, dynamic>? ?? {};
      return _toProductItem(productMap);
    }).toList();

    final leftColumnItems = <ProductItem>[];
    final rightColumnItems = <ProductItem>[];
    for (int i = 0; i < products.length; i++) {
      if (i % 2 == 0) {
        leftColumnItems.add(products[i]);
      } else {
        rightColumnItems.add(products[i]);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
  }
}

class _BannerSliderWidget extends StatefulWidget {
  final List items;

  const _BannerSliderWidget({required this.items});

  @override
  State<_BannerSliderWidget> createState() => _BannerSliderWidgetState();
}

class _BannerSliderWidgetState extends State<_BannerSliderWidget> {
  final PageController _pageController = PageController();
  int _activeIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bannerWidth = screenWidth - 32;
    final bannerHeight = bannerWidth * 0.35;

    return Column(
      children: [
        SizedBox(
          height: bannerHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.items.length,
            onPageChanged: (idx) {
              setState(() {
                _activeIndex = idx;
              });
            },
            itemBuilder: (context, index) {
              final banner = widget.items[index] as Map<String, dynamic>? ?? {};
              final imageUrl = banner['image']?.toString() ?? '';

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F9),
                      border: Border.all(color: const Color(0xFFF0F0F0)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: imageUrl.isEmpty
                        ? const Icon(Icons.image_outlined, color: Colors.grey)
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.fill,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.items.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.items.length, (i) {
              final isActive = _activeIndex == i;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 5,
                width: isActive ? 24.0 : 6.0,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF333333) : const Color(0xFFCCCCCC),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
        const SizedBox(height: 10),
      ],
    );
  }
}
