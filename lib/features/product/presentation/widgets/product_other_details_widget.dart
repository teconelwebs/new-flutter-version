// lib/features/product/presentation/widgets/product_other_details_widget.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  // Collapse state for the entire "All details" accordion
  bool _isAllDetailsExpanded = false;

  // Selected tab state inside "All details"
  String _selectedTab = 'Summary';

  // Toggle for truncating long content
  bool _showMore = false;
  bool _hasLongContent = false;
  final GlobalKey _tabContentKey = GlobalKey();

  final List<String> _tabs = [
    'Summary',
    'Specifications',
    'Description',
  ];

  final List<Map<String, dynamic>> _benefitsData = [
    {
      'svg': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="#FB5404" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 4 23 10 17 10"></polyline><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"></path></svg>''',
      'text': '5-Days Easy Return Policy.',
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
      'text': ' Pay with UPI & Get 10% Off.',
      'modalContent': {
        'title': 'Pay with UPI & Get 10% Off',
        'description':
            'Use UPI for instant payments and enjoy a 10% discount on your order.',
      },
    },
    {
      'svg': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="#FB5404" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 12V8H6a2 2 0 0 1-2-2 2 2 0 0 1 2-2h12v4"></path><path d="M4 6v12a2 2 0 0 0 2 2h14v-4"></path><path d="M18 12a2 2 0 0 0-2 2v2a2 2 0 0 0 2 2h4v-6z"></path></svg>''',
      'text': 'Shop Now, Pay on Delivery.',
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
      'text': 'Factory Price – Direct Savings.',
      'modalContent': {
        'title': 'Factory Price',
        'description':
            'Available at factory prices with the best prices guaranteed.',
      },
    },
    {
      'svg': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="#FB5404" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="1" y="3" width="15" height="13"></rect><polygon points="16 8 20 8 23 11 23 16 16 16 16 8"></polygon><circle cx="5.5" cy="18.5" r="2.5"></circle><circle cx="18.5" cy="18.5" r="2.5"></circle></svg>''',
      'text': 'Free Delivery.',
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
          return const Text('No summary details available.',
              style: TextStyle(color: Colors.grey));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _parseHtmlDescription(htmlDesc),
        );

      case 'Specifications':
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
          return const Text('No specifications listed.',
              style: TextStyle(color: Colors.grey));
        }

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: features.entries.map((e) {
              final isLast = features.keys.last == e.key;
              return Container(
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : const Border(
                          bottom: BorderSide(color: Color(0xFFE5E7EB))),
                  color: features.keys.toList().indexOf(e.key) % 2 == 0
                      ? const Color(0xFFF9FAFB)
                      : Colors.white,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        e.key,
                        style: const TextStyle(
                          color: Color(0xFF4B5563),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        e.value.toString(),
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );

      case 'Description':
        final shortDesc = widget.data['sdescription']?.toString() ?? '';
        final textClean =
            shortDesc.replaceAll(RegExp(r'<[^>]*>|&nbsp;'), '').trim();
        if (textClean.isEmpty) {
          return const Text('No product description details available.',
              style: TextStyle(color: Colors.grey));
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
          if (shop != null)
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sold By',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: !_logoError && shop['logo'] != null
                              ? Image.network(
                                  'https://d1f02fefkbso7w.cloudfront.net/${shop['logo']}',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) {
                                    setState(() => _logoError = true);
                                    return const Icon(Icons.store,
                                        color: Colors.orange);
                                  },
                                )
                              : Image.network(
                                  'https://welfog.com/_nuxt/img/defaultlogo.b490002.png',
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          shop['name'] ?? '',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF666666)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                        ),
                        onPressed: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.shop,
                            arguments: {
                              'id': shop['id'],
                              'slug': shop['slug'],
                              'shop_id': shop['id'],
                            },
                          );
                        },
                        child: const Text('View Shop'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Benefits checkmarks
          Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: _benefitsData.map((benefit) {
                final bool isLast =
                    _benefitsData.indexOf(benefit) == _benefitsData.length - 1;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SvgPicture.string(
                            benefit['svg']!,
                            width: 22,
                            height: 22,
                          ),
                          const SizedBox(width: 12),
                          Text(benefit['text'],
                              style: const TextStyle(
                                  color: Color(0xFF333333), fontSize: 15)),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _showBenefitModal(benefit),
                        child: const Icon(Icons.info_outline,
                            size: 18, color: Color(0xFFE65C00)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // const SizedBox(height: 12),

          // "All details" Accordion Dropdown
          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (All details + collapse toggle button)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'All details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(
                          () => _isAllDetailsExpanded = !_isAllDetailsExpanded),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isAllDetailsExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFF1F2937),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),

                // Expanded content
                if (_isAllDetailsExpanded) ...[
                  const SizedBox(height: 16),

                  // Horizontal scrollable pills tab bar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _tabs.map((tab) {
                        final isSelected = _selectedTab == tab;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _selectedTab = tab;
                              _showMore = false; // reset show more state on tab change
                              _hasLongContent = false;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF1F2937)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: const Color(0xFFE5E7EB)),
                              ),
                              child: Text(
                                tab,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF4B5563),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
