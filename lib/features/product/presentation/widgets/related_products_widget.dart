// lib/features/product/presentation/widgets/related_products_widget.dart
// Converted from: component/RelatedProduct.tsx

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class RelatedProductsWidget extends StatefulWidget {
  final String productId;

  // ignore: use_super_parameters
  const RelatedProductsWidget({
    Key? key,
    required this.productId,
  }) : super(key: key);

  @override
  State<RelatedProductsWidget> createState() => _RelatedProductsWidgetState();
}

class _RelatedProductsWidgetState extends State<RelatedProductsWidget> {
  List<dynamic> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRelatedProducts();
  }

  Future<void> _fetchRelatedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final latitude = prefs.getString('latitude') ?? '0';
      final longitude = prefs.getString('longitude') ?? '0';
      final productId = widget.productId;

      final uri = Uri.parse(
        'https://welfogapi.welfog.com/api/products/related/$productId?id=$productId&latitude=$latitude&longitude=$longitude',
      );
      final response = await http.get(uri, headers: {
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _products = data['data'] as List? ?? [];
          });
        }
      }
    } catch (error) {
      debugPrint('Error fetching related products: $error');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _formatDeliveryTime(dynamic duration) {
    if (duration == null) return 'Est. delivery: 2-4 days';
    final double dur = double.tryParse(duration.toString()) ?? 0.0;
    if (dur <= 1440) return 'Est. delivery: 1 day';
    final days = (dur / 1440).ceil();
    return 'Est. delivery: $days days';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.only(top: 24, left: 16, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Suggested Products',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.7,
              ),
              itemCount: 4,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Suggested Products',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushNamed(
                    '/Category/all',
                    arguments: {'id': 'all', 'name': 'All Categories'},
                  );
                },
                // ignore: prefer_const_constructors
                child: Row(
                  children: const [
                    Text('Explore All', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Related products grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.65,
            ),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final item = _products[index];
              final price = double.tryParse((item['main_price'] ?? 0).toString()) ?? 0.0;
              final oldPrice = double.tryParse((item['old_price'] ?? 0).toString()) ?? 0.0;
              final discount = item['data']?['discount'] ?? 0;

              return GestureDetector(
                onTap: () {
                  Navigator.of(context).pushNamed(
                    '/products',
                    arguments: {
                      'id': item['slug'],
                      'pro_id': item['id']?.toString(),
                      'name': item['name'],
                      'price': price,
                      'image': item['thumbnail_image'],
                      'brand': item['brand'],
                    },
                  );
                },
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image wrapper
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                image: DecorationImage(
                                  image: NetworkImage('https://d1f02fefkbso7w.cloudfront.net/${item['thumbnail_image']}'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            if (discount > 0)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  color: const Color(0xFFFB5404),
                                  child: Text(
                                    '$discount% OFF',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Details
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text('₹${price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(width: 6),
                                if (oldPrice > price)
                                  Text(
                                    '₹${oldPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 12),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDeliveryTime(item['duration']),
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
