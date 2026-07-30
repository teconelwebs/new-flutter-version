// lib/features/product/presentation/widgets/product_other_details_widget.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_routes.dart';

class ProductOtherDetailsWidget extends StatefulWidget {
  final Map<String, dynamic> data;

  // ignore: use_super_parameters
  const ProductOtherDetailsWidget({
    Key? key,
    required this.data,
  }) : super(key: key);

  @override
  State<ProductOtherDetailsWidget> createState() =>
      _ProductOtherDetailsWidgetState();
}

class _ProductOtherDetailsWidgetState extends State<ProductOtherDetailsWidget> {
  bool _logoError = false;

  // Selected tab state inside "All details"
  String _selectedTab = 'Summary';

  // Toggle for truncating long content
  bool _showMore = false;
  bool _hasLongContent = false;
  final GlobalKey _tabContentKey = GlobalKey();

  final List<String> _tabs = [
    'Summary',
    'Specification',
    'Description',
  ];

  final List<Map<String, dynamic>> _benefitsData = [
    {
      'svg': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="#FB5404" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 4 23 10 17 10"></polyline><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"></path></svg>''',
      'text': '5–Day Easy Return Policy!',
      'modalContent': {
        'title': '5-Day Easy Return Policy',
        'description':
            'Damaged product or not as described?\nRequest a refund within 5 days of delivery.',
        'conditions': [
          'Unused & in original condition',
          'Original packaging, MRP tag, product ID, and any freebies/accessories included',
          'No scratches, dents, or damages',
        ],
        'note':
            'Note: Refunds processed after inspection.\nReturn shipping charges may not apply.',
      },
    },
    {
      'svg': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="#FB5404" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"></path><line x1="7" y1="7" x2="7.01" y2="7"></line></svg>''',
      'text': 'Pay with UPI & Get 10% Off!',
      'modalContent': {
        'title': 'Pay with UPI & Get 10% Off',
        'description':
            'Use UPI for instant payments and enjoy a 10% discount on your order.',
      },
    },
    {
      'svg': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="#FB5404" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 12V8H6a2 2 0 0 1-2-2 2 2 0 0 1 2-2h12v4"></path><path d="M4 6v12a2 2 0 0 0 2 2h14v-4"></path><path d="M18 12a2 2 0 0 0-2 2v2a2 2 0 0 0 2 2h4v-6z"></path></svg>''',
      'text': 'Shop Now, Pay on Delivery!',
      'modalContent': {
        'title': 'Shop Now, Pay on Delivery',
        'description':
            'Pay conveniently when your product is delivered to your doorstep.',
        'conditions': [
          'Unused & in original condition',
          'Original packaging, MRP tag, product ID, and any freebies/accessories included',
          'No scratches, dents, or damages',
        ],
        'note':
            'Note: Pay with UPI now and get 10% off! Enjoy a secure and hassle-free payment experience at your convenience.',
      },
    },
    {
      'svg': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="#FB5404" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 20h20"></path><path d="M5 20V8l7 4V8l7 4v8"></path></svg>''',
      'text': 'Factory Price – Direct Savings!',
      'modalContent': {
        'title': 'Factory Price',
        'description':
            'Available at factory prices with the best prices guaranteed.',
      },
    },
    {
      'svg': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="#FB5404" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="1" y="3" width="15" height="13"></rect><polygon points="16 8 20 8 23 11 23 16 16 16 16 8"></polygon><circle cx="5.5" cy="18.5" r="2.5"></circle><circle cx="18.5" cy="18.5" r="2.5"></circle></svg>''',
      'text': 'Free Delivery!',
      'modalContent': {
        'title': 'Free Delivery',
        'description':
            'Shop More, Worry Less – Free Delivery on all eligible products!',
      },
    },
  ];

  void _showBenefitModal(Map<String, dynamic> benefit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final modalContent = benefit['modalContent'] as Map<String, dynamic>?;
        final conditions = modalContent?['conditions'] as List? ?? [];
        final String? note = modalContent?['note']?.toString();

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF008083),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        modalContent?['title'] ?? '',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                modalContent?['description'] ?? '',
                style: const TextStyle(
                    fontSize: 16, color: Color(0xFF374151), height: 1.5),
              ),
              if (conditions.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Conditions:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...conditions.map((cond) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $cond',
                          style: const TextStyle(
                              fontSize: 15, color: Color(0xFF374151))),
                    )),
              ],
              if (note != null) ...[
                const SizedBox(height: 16),
                Text(
                  note,
                  style: const TextStyle(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF4B5563)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBenefitIcon(int index) {
    const double size = 36;
    switch (index) {
      case 0:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFFECFDF5),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            color: Color(0xFF10B981),
            size: 20,
          ),
        );
      case 1:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFFFFF7ED),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text(
              '\$',
              style: TextStyle(
                color: Color(0xFFFB5404),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      case 2:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFFECFEFF),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.local_shipping_outlined,
            color: Color(0xFF0891B2),
            size: 20,
          ),
        );
      case 3:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFFF5F3FF),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.home_outlined,
            color: Color(0xFF6D28D9),
            size: 20,
          ),
        );
      case 4:
      default:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFFFFF7ED),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.hexagon_outlined,
            color: Color(0xFFEA580C),
            size: 20,
          ),
        );
    }
  }

  // Parse HTML string to render text sections and images sequentially
  List<Widget> _parseHtmlDescription(String html) {
    final List<Widget> widgets = [];
    final RegExp imgRegex = RegExp(r'''<img[^>]+src=["']([^"']+)["'][^>]*>''');

    int lastMatchEnd = 0;
    for (final match in imgRegex.allMatches(html)) {
      final textSegment = html.substring(lastMatchEnd, match.start);
      final textClean = textSegment
          .replaceAll(RegExp(r'<[^>]*>|&nbsp;'), '')
          .replaceAll(
              RegExp(r'\n\s*\n+'), '\n') // Collapse consecutive newlines
          .trim();
      if (textClean.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              textClean,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4B5563),
                height: 1.25,
              ),
            ),
          ),
        );
      }

      final imgUrl = match.group(1);
      if (imgUrl != null && imgUrl.isNotEmpty) {
        String cleanUrl = imgUrl;
        if (!cleanUrl.startsWith('http://') &&
            !cleanUrl.startsWith('https://')) {
          cleanUrl = 'https://d1f02fefkbso7w.cloudfront.net/$cleanUrl';
        }
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                cleanUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        );
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < html.length) {
      final remainingText = html.substring(lastMatchEnd);
      final textClean = remainingText
          .replaceAll(RegExp(r'<[^>]*>|&nbsp;'), '')
          .replaceAll(
              RegExp(r'\n\s*\n+'), '\n') // Collapse consecutive newlines
          .trim();
      if (textClean.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              textClean,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4B5563),
                height: 1.25,
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildTabContent(String tab) {
    switch (tab) {
      case 'Summary':
        final htmlDesc = widget.data['description']?.toString() ?? '';
        if (htmlDesc.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No summary details available.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _parseHtmlDescription(htmlDesc),
        );

      case 'Specification':
        final featuresJson = widget.data['pro_features'];
        Map<String, dynamic> features = {};
        if (featuresJson is String && featuresJson.isNotEmpty) {
          try {
            features = jsonDecode(featuresJson);
          } catch (_) {}
        } else if (featuresJson is Map<String, dynamic>) {
          features = featuresJson;
        }

        if (features.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No specifications listed.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return Column(
          children: features.entries.map((e) {
            return Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      e.key,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      e.value.toString(),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );

      case 'Description':
        final shortDesc = widget.data['sdescription']?.toString() ?? '';
        final textClean =
            shortDesc.replaceAll(RegExp(r'<[^>]*>|&nbsp;'), '').trim();
        if (textClean.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No product description details available.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        return Text(
          textClean,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF4B5563),
            height: 1.5,
          ),
        );

      case 'Warranty':
        final warranty = widget.data['warranty']?.toString() ?? '';
        final wClean =
            warranty.replaceAll(RegExp(r'<[^>]*>|&nbsp;'), '').trim();
        if (wClean.isEmpty) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1 Year Brand Warranty',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1F2937)),
              ),
              SizedBox(height: 6),
              Text(
                '• Covers all manufacturing defects during the warranty term.\n• Does not cover liquid damages, accidental drops, physical breakage, or self-repairs.',
                style: TextStyle(
                    fontSize: 13, color: Color(0xFF4B5563), height: 1.5),
              ),
            ],
          );
        }
        return Text(
          wClean,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF4B5563),
            height: 1.5,
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final RenderBox? renderBox = _tabContentKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final double height = renderBox.size.height;
        final bool isLong = height > 130.0;
        if (isLong != _hasLongContent) {
          setState(() {
            _hasLongContent = isLong;
          });
        }
      }
    });

    final shop = widget.data['user']?['shop'] as Map<String, dynamic>?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sold By shop banner card
          if (shop != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFF3F4F6),
                    ),
                    child: ClipOval(
                      child: !_logoError && shop['logo'] != null
                          ? Image.network(
                              'https://d1f02fefkbso7w.cloudfront.net/${shop['logo']}',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                setState(() => _logoError = true);
                                return Image.asset(
                                  'assets/images/shop_default_logo.png',
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                          : Image.asset(
                              'assets/images/shop_default_logo.png',
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sold By',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (shop['name'] ?? '').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        AppRoutes.shop,
                        arguments: {
                          'id': shop['id'],
                          'slug': shop['slug'],
                          'shop_id': shop['id'],
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFFB5404), width: 1.5),
                      ),
                      child: const Text(
                        'View Shop',
                        style: TextStyle(
                          color: Color(0xFFFB5404),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            // Divider line below Sold By (edge-to-edge)
            Builder(
              builder: (context) {
                final screenWidth = MediaQuery.of(context).size.width;
                return Transform.scale(
                  scaleX: screenWidth / (screenWidth - 40),
                  child: const Divider(color: Color(0xFFE5E7EB), height: 1, thickness: 1),
                );
              },
            ),
            const SizedBox(height: 2),
          ],

          // Benefits checkmarks
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              children: List.generate(_benefitsData.length, (idx) {
                final benefit = _benefitsData[idx];
                final bool isLast = idx == _benefitsData.length - 1;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                _buildBenefitIcon(idx),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    benefit['text'],
                                    style: const TextStyle(
                                      color: Color(0xFF1F2937),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showBenefitModal(benefit),
                            child: const Icon(
                              Icons.info_outline,
                              size: 20,
                              color: Color(0xFFFB5404),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      const Divider(color: Color(0xFFF3F4F6), height: 1, thickness: 1),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 2),
          // Bottom Divider line (edge-to-edge)
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              return Transform.scale(
                scaleX: screenWidth / (screenWidth - 40),
                child: const Divider(color: Color(0xFFE5E7EB), height: 1, thickness: 1),
              );
            },
          ),
          const SizedBox(height: 2),

          // Custom Tab Bar Row
          Row(
            children: _tabs.map((tab) {
              final isSelected = _selectedTab == tab;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedTab = tab;
                    _showMore = false;
                    _hasLongContent = false;
                  }),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: isSelected
                          ? const Border(
                              bottom: BorderSide(
                                color: Color(0xFFFB5404),
                                width: 3,
                              ),
                            )
                          : null,
                    ),
                    child: Text(
                      tab,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF1F2937)
                            : const Color(0xFF9CA3AF),
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          // Edge-to-edge grey line below tabs
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              return Transform.scale(
                scaleX: screenWidth / (screenWidth - 40),
                child: const Divider(color: Color(0xFFE5E7EB), height: 1, thickness: 1),
              );
            },
          ),
          const SizedBox(height: 8),

          // Tab content view (with truncation / Show More flow)
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: (_hasLongContent && !_showMore) ? 130.0 : double.infinity,
                ),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    key: _tabContentKey,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTabContent(_selectedTab),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              if (_hasLongContent && !_showMore)
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        // ignore: deprecated_member_use
                        Colors.white.withOpacity(0.0),
                        // ignore: deprecated_member_use
                        Colors.white.withOpacity(0.8),
                        Colors.white,
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Show More / Show Less Button
          if (_hasLongContent)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: GestureDetector(
                onTap: () => setState(() => _showMore = !_showMore),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _showMore ? 'Show Less' : 'Show More',
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showMore
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.chevron_right_rounded,
                        color: const Color(0xFF1F2937),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
