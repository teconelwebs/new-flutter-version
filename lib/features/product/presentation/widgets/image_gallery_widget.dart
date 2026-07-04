// lib/features/product/presentation/widgets/image_gallery_widget.dart
// Converted from: component/ImageGallery.tsx

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

class ImageGalleryWidget extends StatefulWidget {
  final List<String> images;
  final String? videoUrl;
  final bool? inlineMuted;
  final bool isWishlisted;
  final VoidCallback? onWishlistPress;
  final String name;
  final double? newPrice;
  final double? oldPrice;
  final String slug;
  final String? productId;
  final String? userId;
  final bool showFloatingActions;

  const ImageGalleryWidget({
    Key? key,
    required this.images,
    this.videoUrl,
    this.inlineMuted,
    required this.isWishlisted,
    this.onWishlistPress,
    required this.name,
    this.newPrice,
    this.oldPrice,
    required this.slug,
    this.productId,
    this.userId,
    this.showFloatingActions = true,
  }) : super(key: key);

  @override
  State<ImageGalleryWidget> createState() => _ImageGalleryWidgetState();
}

class _ImageGalleryWidgetState extends State<ImageGalleryWidget> {
  int _currentIndex = 0;
  bool _localWishlisted = false;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _localWishlisted = widget.isWishlisted;
    _checkSavedWishlist();
  }

  @override
  void didUpdateWidget(ImageGalleryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isWishlisted != widget.isWishlisted && !_isToggling) {
      setState(() {
        _localWishlisted = widget.isWishlisted;
      });
    }
  }

  Future<void> _checkSavedWishlist() async {
    if (widget.productId != null) {
      final prefs = await SharedPreferences.getInstance();
      final savedState = prefs.getString('wishlist_state_${widget.productId}');
      if (savedState == 'true' && mounted) {
        setState(() => _localWishlisted = true);
      } else if (savedState == 'false' && mounted) {
        setState(() => _localWishlisted = false);
      }
    }
  }

  Future<void> _handleWishlistClick() async {
    final previousState = _localWishlisted;
    final newState = !previousState;

    setState(() {
      _localWishlisted = newState;
      _isToggling = true;
    });

    final prefs = await SharedPreferences.getInstance();
    if (widget.productId != null) {
      await prefs.setString('wishlist_state_${widget.productId}', newState.toString());
    }

    if (widget.onWishlistPress != null) {
      widget.onWishlistPress!();
    }

    // Call API directly for fallback
    if (widget.productId != null && widget.userId != null) {
      try {
        final token = prefs.getString('access_token');
        final endpoint = previousState ? 'wishlists-remove-product' : 'wishlists-add-product';
        final url = Uri.parse(
          'https://welfogapi.welfog.com/api/v2/$endpoint?product_id=${widget.productId}&user_id=${widget.userId}&islogin=true',
        );

        final response = await http.get(url, headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        });

        if (response.statusCode != 200) {
          debugPrint('Wishlist API update failed');
        }
      } catch (e) {
        debugPrint('Wishlist API Error: $e');
      } finally {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _isToggling = false;
        });
      }
    } else {
      _isToggling = false;
    }
  }

  Future<void> _onShare() async {
    try {
      final url = 'https://www.welfog.com/products/${widget.slug}';
      final price = widget.newPrice ?? widget.oldPrice ?? 0.0;
      await Share.share('${widget.name} - ₹${price.toStringAsFixed(0)}\nCheck it out: $url');
    } catch (e) {
      debugPrint('Share Error: $e');
    }
  }

  void _openFullscreenGallery(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) {
          int galleryIndex = initialIndex;
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: StatefulBuilder(
              builder: (context, setDialogState) {
                return Stack(
                  children: [
                    PageView.builder(
                      itemCount: widget.images.length,
                      controller: PageController(initialPage: initialIndex),
                      onPageChanged: (idx) {
                        setDialogState(() => galleryIndex = idx);
                      },
                      itemBuilder: (context, idx) {
                        return Center(
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 3.0,
                            child: Image.network(
                              widget.images[idx].startsWith('http')
                                  ? widget.images[idx]
                                  : 'https://d1f02fefkbso7w.cloudfront.net/${widget.images[idx]}',
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      top: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${galleryIndex + 1} / ${widget.images.length}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final imageHeight = MediaQuery.of(context).size.height * 0.45;

    if (widget.images.isEmpty) {
      return Container(
        height: imageHeight,
        color: Colors.grey.shade100,
        alignment: Alignment.center,
        child: const Icon(Icons.image, size: 64, color: Colors.grey),
      );
    }

    return Column(
      children: [
        Container(
          height: imageHeight,
          margin: const EdgeInsets.only(top: 8),
          child: Stack(
            children: [
              // Slider list
              PageView.builder(
                itemCount: widget.images.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final imgUrl = widget.images[index];
                  final fullUrl = imgUrl.startsWith('http') ? imgUrl : 'https://d1f02fefkbso7w.cloudfront.net/$imgUrl';

                  return GestureDetector(
                    onTap: () => _openFullscreenGallery(index),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                        image: DecorationImage(
                          image: NetworkImage(fullUrl),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Floating actions Share / Wishlist buttons
              if (widget.showFloatingActions)
              Positioned(
                top: 16,
                right: 16,
                child: Column(
                  children: [
                    // Wishlist action
                    GestureDetector(
                      onTap: _handleWishlistClick,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _localWishlisted ? Icons.favorite : Icons.favorite_border,
                          size: 22,
                          color: _localWishlisted ? const Color(0xFFFB5404) : const Color(0xFF333333),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Share action
                    GestureDetector(
                      onTap: _onShare,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.share,
                          size: 20,
                          color: Color(0xFFFB5404),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Slide indicator count badge positioned cleanly below the image slider
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_currentIndex + 1} / ${widget.images.length}',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
