import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../../../core/network/axios_instance.dart';
import '../../../../core/constants/app_routes.dart';

class PromotionSectionItem {
  final int id;
  final int categoryId;
  final List<PromotionDataItem> promotionData;

  PromotionSectionItem({
    required this.id,
    required this.categoryId,
    required this.promotionData,
  });

  factory PromotionSectionItem.fromJson(Map<String, dynamic> json) {
    final rawPromo = json['promotion_data'];
    List<dynamic> parsedPromo = [];
    if (rawPromo is String) {
      try {
        parsedPromo = jsonDecode(rawPromo) as List? ?? [];
      } catch (_) {}
    } else if (rawPromo is List) {
      parsedPromo = rawPromo;
    }
    return PromotionSectionItem(
      id: json['id'] ?? 0,
      categoryId: int.tryParse(json['category_id']?.toString() ?? '0') ?? 0,
      promotionData: parsedPromo.map((e) {
        if (e is Map) {
          return PromotionDataItem.fromJson(Map<String, dynamic>.from(e));
        }
        return PromotionDataItem(type: '', html: '', headings: [], descriptions: [], images: [], urls: []);
      }).toList(),
    );
  }
}

class PromotionDataItem {
  final String type;
  final String html;
  final List<String> headings;
  final List<String> descriptions;
  final List<String> images;
  final List<String> urls;

  PromotionDataItem({
    required this.type,
    required this.html,
    required this.headings,
    required this.descriptions,
    required this.images,
    required this.urls,
  });

  factory PromotionDataItem.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      } else if (val is String) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is List) {
            return decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
      return [];
    }

    return PromotionDataItem(
      type: json['type'] ?? '',
      html: json['html'] ?? '',
      headings: parseList(json['headings']),
      descriptions: parseList(json['descriptions']),
      images: parseList(json['images']),
      urls: parseList(json['urls']),
    );
  }
}

class CategoryPromotionWidget extends StatefulWidget {
  final String categoryId;

  const CategoryPromotionWidget({super.key, required this.categoryId});

  @override
  State<CategoryPromotionWidget> createState() => _CategoryPromotionWidgetState();
}

class _CategoryPromotionWidgetState extends State<CategoryPromotionWidget> {
  List<PromotionSectionItem> _sections = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPromotions();
  }

  Future<void> _fetchPromotions() async {
    try {
      final response = await AxiosInstance.mainAPI.get('/promotion-section/${widget.categoryId}');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true && decoded['data'] is List) {
          final list = decoded['data'] as List;
          if (mounted) {
            setState(() {
              _sections = list.map((e) {
                if (e is Map) {
                  return PromotionSectionItem.fromJson(Map<String, dynamic>.from(e));
                }
                return PromotionSectionItem(id: 0, categoryId: 0, promotionData: []);
              }).where((item) => item.id > 0).toList();
              _loading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching promotions for category ${widget.categoryId}: $e');
    }
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  String _resolveImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return 'https://d1f02fefkbso7w.cloudfront.net/$path';
  }

  void _handleBannerTap(BuildContext context, String targetUrl) {
    if (targetUrl.isEmpty) return;

    final parts = targetUrl.replaceAll(RegExp(r'/$'), '').split('/');
    final slug = parts.isNotEmpty ? parts.last : null;

    if (slug != null && slug.isNotEmpty) {
      Navigator.of(context).pushNamed(
        AppRoutes.dynamicPromotion,
        arguments: slug,
      );
    }
  }

  String _preprocessHtml(String html) {
    var processed = html;

    // 1. Transform tables, table rows, and cells into stacked responsive divs
    processed = processed.replaceAll(RegExp(r'<table[^>]*>'), '<div style="width: 100%;">');
    processed = processed.replaceAll('</table>', '</div>');
    processed = processed.replaceAll(RegExp(r'<tbody[^>]*>'), '<div>');
    processed = processed.replaceAll('</tbody>', '</div>');
    processed = processed.replaceAll(RegExp(r'<tr[^>]*>'), '<div style="width: 100%;">');
    processed = processed.replaceAll('</tr>', '</div>');
    
    // Replace <td style="..."> with <div style="margin-bottom: 12px; display: block; width: 100%; ...">
    processed = processed.replaceAll(
      RegExp(r'<td\s+style="'),
      '<div style="margin-bottom: 12px; display: block; width: 100%; ',
    );
    processed = processed.replaceAll('</td>', '</div>');

    // 2. Generic linear-gradient extractor and replacer to support custom gradient background boxes
    final gradientRegex = RegExp(
      r'background(?:-image)?\s*:\s*linear-gradient\([^)]+\)',
      caseSensitive: false,
    );
    processed = processed.replaceAllMapped(gradientRegex, (match) {
      final text = match.group(0) ?? '';
      // Find the first color hex (e.g., #ff4d6d or #1f2937) in the matched gradient rule
      final hexRegex = RegExp(r'#([0-9a-fA-F]{3,6})');
      final hexMatch = hexRegex.firstMatch(text);
      if (hexMatch != null) {
        return 'background-color: ${hexMatch.group(0)}';
      }
      return 'background-color: #ffe8ef'; // Default fallback shade
    });

    // Replace invalid decimal opacity representations (e.g. .08 -> 0.08) for CSS parser compatibility
    processed = processed.replaceAll('.08', '0.08');
    processed = processed.replaceAll('.12', '0.12');

    // 3. Transform Flexbox containers and flex items to responsive blocks and inline-blocks
    // Replace display:flex; with display:block; for outer blocks
    processed = processed.replaceAll('display:flex;', 'display: block; text-align: center;');
    processed = processed.replaceAll('display: flex;', 'display: block; text-align: center;');
    processed = processed.replaceAll('justify-content:space-between;align-items:center;', '');
    processed = processed.replaceAll('justify-content: space-between; align-items: center;', '');
    processed = processed.replaceAll('flex-wrap:wrap;', '');
    processed = processed.replaceAll('flex-wrap: wrap;', '');
    
    // Replace flex columns (like text wrappers) with full width blocks centered on mobile
    processed = processed.replaceAll('flex:1;min-width:260px;', 'display: block; width: 100%; text-align: center; box-sizing: border-box;');
    processed = processed.replaceAll('flex: 1; min-width: 260px;', 'display: block; width: 100%; text-align: center; box-sizing: border-box;');
    
    // Replace features container (which has gap and center alignment)
    processed = processed.replaceAll(
      RegExp(r'display:\s*flex;gap:\s*\d+px;flex-wrap:\s*wrap;justify-content:\s*center;'),
      'display: block; width: 100%; margin-top: 16px; text-align: center; box-sizing: border-box;',
    );
    processed = processed.replaceAll(
      RegExp(r'display:\s*flex;\s*gap:\s*\d+px;\s*flex-wrap:\s*wrap;\s*justify-content:\s*center;'),
      'display: block; width: 100%; margin-top: 16px; text-align: center; box-sizing: border-box;',
    );

    // Convert flex cards with min-width to inline-blocks with 44% width, 90px height, and 2% horizontal margin
    processed = processed.replaceAll('min-width:110px;', 'display: inline-block; width: 44%; height: 90px; margin: 8px 2%; box-sizing: border-box; vertical-align: top;');
    processed = processed.replaceAll('min-width: 110px;', 'display: inline-block; width: 44%; height: 90px; margin: 8px 2%; box-sizing: border-box; vertical-align: top;');
    processed = processed.replaceAll('min-width:110px', 'display: inline-block; width: 44%; height: 90px; margin: 8px 2%; box-sizing: border-box; vertical-align: top;');
    processed = processed.replaceAll('min-width: 110px', 'display: inline-block; width: 44%; height: 90px; margin: 8px 2%; box-sizing: border-box; vertical-align: top;');

    processed = processed.replaceAll('min-width:120px;', 'display: inline-block; width: 44%; height: 90px; margin: 8px 2%; box-sizing: border-box; vertical-align: top;');
    processed = processed.replaceAll('min-width: 120px;', 'display: inline-block; width: 44%; height: 90px; margin: 8px 2%; box-sizing: border-box; vertical-align: top;');
    processed = processed.replaceAll('min-width:120px', 'display: inline-block; width: 44%; height: 90px; margin: 8px 2%; box-sizing: border-box; vertical-align: top;');
    processed = processed.replaceAll('min-width: 120px', 'display: inline-block; width: 44%; height: 90px; margin: 8px 2%; box-sizing: border-box; vertical-align: top;');

    // 4. Adjust internal padding of feature cards to prevent text wrapping on mobile
    processed = processed.replaceAll('padding:14px 18px;', 'padding: 12px 6px;');
    processed = processed.replaceAll('padding: 14px 18px;', 'padding: 12px 6px;');
    processed = processed.replaceAll('padding:14px 22px;', 'padding: 12px 6px;');
    processed = processed.replaceAll('padding: 14px 22px;', 'padding: 12px 6px;');

    // 5. Adjust static 1200px max-width to allow responsive auto-scaling
    processed = processed.replaceAll('max-width:1200px;', 'max-width:100%;');
    processed = processed.replaceAll('max-width: 1200px;', 'max-width:100%;');
    processed = processed.replaceAll('margin:20px auto;', 'margin: 10px 0;');
    processed = processed.replaceAll('margin: 20px auto;', 'margin: 10px 0;');
    
    // 6. Center any max-width paragraph elements
    processed = processed.replaceAll('max-width:520px;', 'max-width: 100%; margin-left: auto; margin-right: auto; text-align: center;');
    processed = processed.replaceAll('max-width: 520px;', 'max-width: 100%; margin-left: auto; margin-right: auto; text-align: center;');

    // 7. Replace large static paddings and margins with fluid responsive parameters
    processed = processed.replaceAll('padding:22px 30px;', 'padding: 16px 20px;');
    processed = processed.replaceAll('padding: 22px 30px;', 'padding: 16px 20px;');
    processed = processed.replaceAll('padding:60px 40px;', 'padding: 24px 16px;');
    processed = processed.replaceAll('padding: 60px 40px;', 'padding: 24px 16px;');
    processed = processed.replaceAll('padding:45px 30px;', 'padding: 20px 14px;');
    processed = processed.replaceAll('padding: 45px 30px;', 'padding: 20px 14px;');
    processed = processed.replaceAll('padding:45px 35px;', 'padding: 20px 14px;');
    processed = processed.replaceAll('padding: 45px 35px;', 'padding: 20px 14px;');
    processed = processed.replaceAll('padding:35px;', 'padding: 20px 14px;');
    processed = processed.replaceAll('padding: 35px;', 'padding: 20px 14px;');
    processed = processed.replaceAll('margin:35px;', 'margin: 12px;');
    processed = processed.replaceAll('margin: 35px;', 'margin: 12px;');
    
    // 8. Reduce oversized headers and text sizes for clean mobile formatting
    processed = processed.replaceAll('font-size:34px;', 'font-size: 22px;');
    processed = processed.replaceAll('font-size: 34px;', 'font-size: 22px;');
    processed = processed.replaceAll('font-size:45px;', 'font-size: 26px;');
    processed = processed.replaceAll('font-size: 45px;', 'font-size: 26px;');
    processed = processed.replaceAll('font-size:42px;', 'font-size: 24px;');
    processed = processed.replaceAll('font-size: 42px;', 'font-size: 24px;');
    processed = processed.replaceAll('font-size:38px;', 'font-size: 20px;');
    processed = processed.replaceAll('font-size: 38px;', 'font-size: 20px;');
    processed = processed.replaceAll('font-size:30px;', 'font-size: 18px;');
    processed = processed.replaceAll('font-size: 30px;', 'font-size: 18px;');
    processed = processed.replaceAll('font-size:28px;', 'font-size: 24px;'); // Restored size 24px to balance 50% box visually
    processed = processed.replaceAll('font-size: 28px;', 'font-size: 24px;');
    processed = processed.replaceAll('font-size:22px;', 'font-size: 15px;');
    processed = processed.replaceAll('font-size: 22px;', 'font-size: 15px;');
    processed = processed.replaceAll('font-size:18px;', 'font-size: 13px;');
    processed = processed.replaceAll('font-size: 18px;', 'font-size: 13px;');
    processed = processed.replaceAll('font-size:17px;', 'font-size: 13px;');
    processed = processed.replaceAll('font-size: 17px;', 'font-size: 13px;');
    processed = processed.replaceAll('font-size:16px;', 'font-size: 12px;');
    processed = processed.replaceAll('font-size: 16px;', 'font-size: 12px;');
    
    // 9. Line height styling fixes
    processed = processed.replaceAll('line-height:40px;', 'line-height: 28px;');
    processed = processed.replaceAll('line-height: 40px;', 'line-height: 28px;');
    processed = processed.replaceAll('line-height:38px;', 'line-height: 26px;');
    processed = processed.replaceAll('line-height: 38px;', 'line-height: 26px;');
    processed = processed.replaceAll('line-height:30px;', 'line-height: 20px;');
    processed = processed.replaceAll('line-height: 30px;', 'line-height: 20px;');
    processed = processed.replaceAll('line-height:26px;', 'line-height: 18px;');
    processed = processed.replaceAll('line-height: 26px;', 'line-height: 18px;');

    // 10. Refit action buttons
    processed = processed.replaceAll('padding:14px 35px;', 'padding: 10px 24px;');
    processed = processed.replaceAll('padding: 14px 35px;', 'padding: 10px 24px;');
    processed = processed.replaceAll('padding:16px 40px;', 'padding: 10px 24px;');
    processed = processed.replaceAll('padding: 16px 40px;', 'padding: 10px 24px;');
    processed = processed.replaceAll('padding:14px 25px;', 'padding: 8px 16px;');
    processed = processed.replaceAll('padding: 14px 25px;', 'padding: 8px 16px;');
    processed = processed.replaceAll('margin:8px;', 'margin: 4px;');
    processed = processed.replaceAll('margin: 8px;', 'margin: 4px;');

    return processed;
  }

  Widget _buildPromoItem(PromotionDataItem promo) {
    if (promo.type == 'html') {
      final htmlContent = promo.html;
      if (htmlContent.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: HtmlWidget(
          _preprocessHtml(htmlContent),
          textStyle: const TextStyle(fontSize: 14),
        ),
      );
    } else if (promo.type == 'default') {
      final imageUrl = promo.images.isNotEmpty ? _resolveImageUrl(promo.images.first) : '';
      if (imageUrl.isEmpty) return const SizedBox.shrink();

      final heading = promo.headings.isNotEmpty ? promo.headings.first : '';
      final description = promo.descriptions.isNotEmpty ? promo.descriptions.first : '';
      final targetUrl = promo.urls.isNotEmpty ? promo.urls.first : '';

      return GestureDetector(
        onTap: () => _handleBannerTap(context, targetUrl),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                // ignore: deprecated_member_use
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 2.3, // Fully responsive aspect ratio instead of a fixed height
              child: Stack(
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.fill, // BoxFit.fill shows the entire image cleanly without side/phone cutoffs
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade100,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            // ignore: deprecated_member_use
                            Colors.black.withOpacity(0.85),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (heading.isNotEmpty)
                          Text(
                            heading,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              // ignore: deprecated_member_use
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _sections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16), // Premium spacing between category product zones
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _sections.map((section) {
          final defaultPromos = section.promotionData.where((e) => e.type == 'default').toList();
          final htmlPromos = section.promotionData.where((e) => e.type == 'html').toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (defaultPromos.isNotEmpty) ...[
                if (defaultPromos.length == 1)
                  _buildPromoItem(defaultPromos.first)
                else
                  _PromoSectionSlider(items: defaultPromos),
              ],
              if (htmlPromos.isNotEmpty)
                ...htmlPromos.map(_buildPromoItem),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _PromoSectionSlider extends StatefulWidget {
  final List<PromotionDataItem> items;

  const _PromoSectionSlider({required this.items});

  @override
  State<_PromoSectionSlider> createState() => _PromoSectionSliderState();
}

class _PromoSectionSliderState extends State<_PromoSectionSlider> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _activeIndex = 0;
  bool _isManualSwipe = false;
  bool _isAutoAdvancing = false;
  int? _pageAtScrollStart;

  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // 4 seconds duration per dynamic slide
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_progressController);
    _progressController.addStatusListener(_onProgressStatusChanged);
    _startProgressFill();
  }

  void _onProgressStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed ||
        _isManualSwipe ||
        _isAutoAdvancing ||
        widget.items.length <= 1 ||
        !mounted) {
      return;
    }
    _autoAdvance();
  }

  Future<void> _autoAdvance() async {
    if (!_pageController.hasClients || !mounted) return;
    _isAutoAdvancing = true;
    final nextPage = (_activeIndex + 1) % widget.items.length;
    try {
      await _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } finally {
      _isAutoAdvancing = false;
      if (mounted) _startProgressFill();
    }
  }

  void _startProgressFill() {
    if (widget.items.length <= 1 || !mounted) return;
    _progressController
      ..stop()
      ..value = 0;
    _progressController.forward(from: 0);
  }

  @override
  void dispose() {
    _progressController.removeStatusListener(_onProgressStatusChanged);
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  String _resolveImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return 'https://d1f02fefkbso7w.cloudfront.net/$path';
  }

  void _handleBannerTap(BuildContext context, String targetUrl) {
    if (targetUrl.isEmpty) return;

    final parts = targetUrl.replaceAll(RegExp(r'/$'), '').split('/');
    final slug = parts.isNotEmpty ? parts.last : null;

    if (slug != null && slug.isNotEmpty) {
      Navigator.of(context).pushNamed(
        AppRoutes.dynamicPromotion,
        arguments: slug,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 2.3, // Responsive aspect ratio scales cleanly across tablet & phones
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              if (notification is ScrollStartNotification) {
                _pageAtScrollStart = _activeIndex;
                _progressController.stop();
                setState(() => _isManualSwipe = true);
              } else if (notification is ScrollEndNotification) {
                setState(() => _isManualSwipe = false);
                if (_pageAtScrollStart == _activeIndex) {
                  _startProgressFill();
                }
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              onPageChanged: (idx) {
                setState(() {
                  _activeIndex = idx;
                });
                if (!_isAutoAdvancing) {
                  _startProgressFill();
                }
              },
              itemBuilder: (context, index) {
                final promo = widget.items[index];
                final imageUrl = promo.images.isNotEmpty ? _resolveImageUrl(promo.images.first) : '';
                if (imageUrl.isEmpty) return const SizedBox.shrink();

                final heading = promo.headings.isNotEmpty ? promo.headings.first : '';
                final description = promo.descriptions.isNotEmpty ? promo.descriptions.first : '';
                final targetUrl = promo.urls.isNotEmpty ? promo.urls.first : '';

                return GestureDetector(
                  onTap: () => _handleBannerTap(context, targetUrl),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            // ignore: deprecated_member_use
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            Image.network(
                              imageUrl,
                              fit: BoxFit.fill, // BoxFit.fill shows the entire image cleanly without side/phone cutoffs
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade100,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            ),
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      // ignore: deprecated_member_use
                                      Colors.black.withOpacity(0.85),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (heading.isNotEmpty)
                                    Text(
                                      heading,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  if (description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        // ignore: deprecated_member_use
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (widget.items.length > 1) ...[
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.items.length, (index) {
                  final isActive = index == _activeIndex;
                  final fill = isActive
                      ? _progressAnimation.value.clamp(0.0, 1.0)
                      : 0.0;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    height: 5,
                    width: isActive ? 30 : 15,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD4D4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: fill,
                        child: Container(
                          color: isActive
                              ? const Color(0xFF2B2B2B)
                              : Colors.transparent,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}
