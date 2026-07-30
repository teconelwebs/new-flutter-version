import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/no_internet_widget.dart';
import '../../../core/state/cart_state.dart';
import '../data/models/product_item.dart';
import '../data/product_api_service.dart';
import 'widgets/product_card.dart';
import 'widgets/image_gallery_widget.dart';
import 'widgets/product_details_widget.dart';
import 'widgets/product_other_details_widget.dart';
import 'widgets/buy_product_widget.dart';
import 'widgets/buy_product_btn_widget.dart';
import 'widgets/customer_reviews_widget.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key, this.item, this.slug});

  final ProductItem? item;
  final String? slug;

  static const routeName = AppRoutes.product;
  static String? currentlyVisibleSlug;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final ProductApiService _api = ProductApiService();

  ProductDetailData? _detail;
  List<ProductItem> _related = const [];

  // ignore: unused_field
  bool _loading = true;
  String? _error;
  int _qty = 1;

  String _pincode = '';
  String _userId = '';
  bool _isWishlisted = false;
  bool _isTogglingWishlist = false;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _reviewsKey = GlobalKey();
  final GlobalKey _quantitySelectorKey = GlobalKey();
  bool _showStickyQuantity = false;
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    final slug = widget.slug ?? widget.item?.slug;
    if (slug != null && slug.trim().isNotEmpty) {
      ProductScreen.currentlyVisibleSlug = slug.trim();
    }
    _scrollController.addListener(_onScroll);
    // Set initial status bar icons to light (white) for unscrolled state
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _load();
    CartState.loadCartCount();
  }

  @override
  void dispose() {
    final slug = widget.slug ?? widget.item?.slug;
    if (slug != null && slug.trim().isNotEmpty) {
      if (ProductScreen.currentlyVisibleSlug == slug.trim()) {
        ProductScreen.currentlyVisibleSlug = null;
      }
    }
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    // Restore default dark status bar icons when leaving product details
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final offset = _scrollController.offset;
      _scrollOffsetNotifier.value = offset;
      // Update status bar icons color dynamically (light when unscrolled/on image, dark when scrolled)
      SystemChrome.setSystemUIOverlayStyle(
        offset > 100 ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      );

      // Check if body quantity selector has scrolled off screen
      final RenderObject? renderObject = _quantitySelectorKey.currentContext?.findRenderObject();
      if (renderObject is RenderBox && mounted) {
        final position = renderObject.localToGlobal(Offset.zero);
        // If bottom of widget is above the top portion of the screen (e.g. 100px from top)
        final bool shouldShow = (position.dy + renderObject.size.height) < 100;
        if (shouldShow != _showStickyQuantity) {
          setState(() {
            _showStickyQuantity = shouldShow;
          });
        }
      } else {
        if (_showStickyQuantity && mounted) {
          setState(() {
            _showStickyQuantity = false;
          });
        }
      }
    }
  }

  void _scrollToReviews() {
    final context = _reviewsKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _load() async {
    final seed = widget.item;
    final slug = widget.slug ?? seed?.slug;

    if (slug == null || slug.trim().isEmpty) {
      if (seed == null) {
        setState(() {
          _loading = false;
          _error = 'Product not found';
        });
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final String slugOrId = (slug != null && slug.trim().isNotEmpty) ? slug.trim() : seed!.id;
      final String productId = seed != null ? seed.id : slugOrId;

      final detail =
          await _api.fetchProductDetail(slugOrId: slugOrId, productId: productId);
      final related = await _api.fetchRelatedProducts(detail.id);

      final prefs = await SharedPreferences.getInstance();
      final pincode = prefs.getString('postal_code') ?? '';
      final userId = prefs.getString('user_id') ?? '';

      // Check local wishlist state first
      final savedWishlistState = prefs.getString('wishlist_state_${detail.id}');
      bool isWish = savedWishlistState == 'true';

      if (!mounted) return;
      setState(() {
        _detail = detail;
        _related = related.where((p) => p.id != detail.id).take(6).toList();
        _pincode = pincode;
        _userId = userId;
        _isWishlisted = isWish;
        _loading = false;
      });

      _saveToRecentlyViewed(detail);

      // Fetch from API to check actual status if logged in
      if (userId.isNotEmpty) {
        _checkWishlistStatus();
        _fetchAddress();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _selectVariant(String slug) async {
    try {
      final preservedOffset =
          _scrollController.hasClients ? _scrollController.offset : null;

      final detail = await _api.fetchProductDetail(slugOrId: slug, productId: slug);
      final related = await _api.fetchRelatedProducts(detail.id);

      final prefs = await SharedPreferences.getInstance();
      final pincode = prefs.getString('postal_code') ?? '';
      final userId = prefs.getString('user_id') ?? '';

      final savedWishlistState = prefs.getString('wishlist_state_${detail.id}');
      bool isWish = savedWishlistState == 'true';

      if (!mounted) return;
      setState(() {
        _detail = detail;
        _related = related.where((p) => p.id != detail.id).take(6).toList();
        _pincode = pincode;
        _userId = userId;
        _isWishlisted = isWish;
      });

      _saveToRecentlyViewed(detail);

      if (userId.isNotEmpty) {
        _checkWishlistStatus();
        _fetchAddress();
      }

      // Stay where the user was (size row) — don't jump to top after variant load.
      if (preservedOffset != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          final max = _scrollController.position.maxScrollExtent;
          _scrollController.jumpTo(preservedOffset.clamp(0.0, max));
        });
      }
    } catch (e) {
      debugPrint('Error loading variant: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load variant: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _saveToRecentlyViewed(ProductDetailData detail) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? existingStr = prefs.getString('recently_viewed');
      List<dynamic> list = [];
      if (existingStr != null) {
        try {
          list = jsonDecode(existingStr) as List;
        } catch (_) {}
      }

      final int parsedId = int.tryParse(detail.id) ?? 0;
      if (parsedId == 0) return;

      // Remove duplicates
      list.removeWhere((item) => (item['id'] ?? 0) == parsedId);

      final raw = detail.rawJson;
      final duration = raw['shop_location']?['duration'] ?? raw['duration'] ?? detail.rawJson['data']?['duration'] ?? 0;

      final Map<String, dynamic> itemMap = {
        'id': parsedId,
        'name': detail.name,
        'price': detail.sellPrice,
        'mrp': detail.mrpPrice,
        'image': detail.images.isNotEmpty ? detail.images.first : '',
        'slug': detail.slug,
        'brand': detail.brand,
        'rating': detail.rating,
        'duration': duration,
      };

      list.insert(0, itemMap);

      if (list.length > 10) {
        list = list.sublist(0, 10);
      }

      await prefs.setString('recently_viewed', jsonEncode(list));
    } catch (e) {
      debugPrint('Error saving recently viewed product: $e');
    }
  }

  Future<void> _checkWishlistStatus() async {
    if (_detail == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final accessToken = prefs.getString('access_token');
      if (userId == null || accessToken == null) return;

      final productId = _detail!.id;
      final uri =
          Uri.parse('https://welfogapi.welfog.com/api/wishlists/$userId');
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $accessToken'});

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final wishlistItems = data['data'] as List? ?? [];
        final isInWishlist =
            wishlistItems.any((item) => item['product']?['id'] == productId);
        if (mounted) {
          setState(() {
            _isWishlisted = isInWishlist;
          });
        }
      }
    } catch (error) {
      debugPrint('Error checking wishlist status: $error');
    }
  }

  Future<void> _fetchAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('user_id') ?? '';
      if (currentUserId.isEmpty) return;

      final uri = Uri.parse(
          'https://welfogapi.welfog.com/api/v2/allAddress/$currentUserId?id=$currentUserId');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == true && data['addData'] is List) {
          final addresses = data['addData'] as List;
          final defaultAddress = addresses.firstWhere(
            (addr) => addr['using_this'] == 1,
            orElse: () => null,
          );

          if (defaultAddress != null) {
            final pin = defaultAddress['postal_code']?.toString() ?? '';
            if (pin.isNotEmpty) {
              await prefs.setString('postal_code', pin);
              if (mounted) {
                setState(() {
                  _pincode = pin;
                });
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error finding location: $e");
    }
  }

  Future<void> _toggleWishlist() async {
    if (_detail == null || _isTogglingWishlist) return;
    final previousState = _isWishlisted;
    final newState = !previousState;

    setState(() {
      _isWishlisted = newState;
      _isTogglingWishlist = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wishlist_state_${_detail!.id}', newState.toString());

    final userId = prefs.getString('user_id');
    final accessToken = prefs.getString('access_token');

    if (userId != null && accessToken != null) {
      try {
        final endpoint = previousState
            ? 'wishlists-remove-product'
            : 'wishlists-add-product';
        final url = Uri.parse(
          'https://welfogapi.welfog.com/api/v2/$endpoint?product_id=${_detail!.id}&user_id=$userId&islogin=true',
        );

        final response = await http.get(url, headers: {
          'Authorization': 'Bearer $accessToken',
        });

        if (response.statusCode != 200) {
          debugPrint('Wishlist API update failed');
        } else {
          if (mounted) {
            final msg = newState
                ? 'Item added to wishlist'
                : 'Item removed from wishlist';
            final textWidth = (msg.length * 7.5) + 32;
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                // ignore: deprecated_member_use
                backgroundColor: const Color(0xB3111111),
                behavior: SnackBarBehavior.floating,
                width: textWidth,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                duration: const Duration(seconds: 1),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Wishlist API Error: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isTogglingWishlist = false;
          });
        }
      }
    } else {
      setState(() {
        _isTogglingWishlist = false;
      });
      // ignore: use_build_context_synchronously
      Navigator.of(context).pushNamed(AppRoutes.login);
    }
  }

  Future<void> _onShare(BuildContext context) async {
    if (_detail == null) return;
    try {
      final url = 'https://www.welfog.com/products/${_detail!.slug}';
      final price = _detail!.sellPrice;
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      final rect = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
      await Share.share(
          '${_detail!.name} - ₹${price.toStringAsFixed(0)}\nCheck it out: $url',
          sharePositionOrigin: rect,
      );
    } catch (e) {
      debugPrint('Share Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_detail == null) {
      if (_error != null) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: NoInternetWidget(
            onRetry: _load,
            title: 'Connection Error',
            message: _error!,
          ),
        );
      }
      return const Scaffold(
        body: AppLoader.page(),
      );
    }

    final detail = _detail!;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Scrollable Content
          RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 0, bottom: 48),
              children: [
                ImageGalleryWidget(
                  images: detail.images,
                  videoUrl: detail.videoUrl,
                  isWishlisted: _isWishlisted,
                  onWishlistPress: _toggleWishlist,
                  name: detail.name,
                  slug: detail.slug,
                  productId: detail.id,
                  userId: _userId,
                  showFloatingActions: false,
                ),
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Column(
                    children: [
                      // Main details container with rounded top corners
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            ProductDetailsWidget(
                              data: detail.rawJson,
                              pincode: _pincode,
                              onRatingTap: _scrollToReviews,
                              onVariantSelected: _selectVariant,
                            ),
                            const SizedBox(height: 12),
                            BuyProductWidget(
                              key: _quantitySelectorKey,
                              data: detail.rawJson,
                              quantity: _qty,
                              onQuantityChanged: (newQty) {
                                setState(() {
                                  _qty = newQty;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            ProductOtherDetailsWidget(
                              data: detail.rawJson,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      CustomerReviewsWidget(
                        key: _reviewsKey,
                        data: detail.rawJson,
                      ),
                      const SizedBox(height: 6),
                      _buildSuggestedProducts(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Dynamic Header Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _scrollOffsetNotifier,
              builder: (context, offset, _) {
                final double t = (offset / 180.0).clamp(0.0, 1.0);
                return _ProductHeader(
                  onBack: () => Navigator.of(context).maybePop(),
                  onSearch: () => Navigator.of(context).pushNamed(AppRoutes.search),
                  onShare: () => _onShare(context),
                  onWishlist: _toggleWishlist,
                  onCartTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    final token = prefs.getString('access_token') ?? '';
                    if (token.isEmpty) {
                      if (context.mounted) {
                        Navigator.of(context).pushNamed(AppRoutes.login);
                      }
                      return;
                    }
                    if (context.mounted) {
                      Navigator.of(context).pushNamed(AppRoutes.cart);
                    }
                  },
                  isWishlisted: _isWishlisted,
                  t: t,
                );
              },
            ),
          ),
          // View Cart Banner (Commented out per user request)
          // ValueListenableBuilder<int>(
          //   valueListenable: CartState.cartCountNotifier,
          //   builder: (context, cartCount, _) {
          //     if (cartCount <= 0) return const SizedBox.shrink();
          //     return Positioned(
          //       left: 0,
          //       right: 0,
          //       bottom: 8.0,
          //       child: ViewCartBanner(
          //         onTap: () {
          //           Navigator.of(context).pushNamed(AppRoutes.cart);
          //         },
          //       ),
          //     );
          //   },
          // ),
        ],
      ),
      bottomNavigationBar: BuyProductBtnWidget(
        data: detail.rawJson,
        selectedQuantity: _qty,
        showQuantitySelector: _showStickyQuantity,
        onQuantityChanged: (newQty) {
          setState(() {
            _qty = newQty;
          });
        },
      ),
    );
  }

  Widget _buildSuggestedProducts() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Related Products',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  final rawCat = _detail?.rawJson['category'];
                  String? categoryName;
                  if (rawCat is Map) {
                    categoryName = rawCat['name']?.toString();
                  } else {
                    categoryName = _detail?.rawJson['category_name']?.toString();
                  }

                  if (categoryName != null && categoryName.trim().isNotEmpty) {
                    Navigator.of(context).pushNamed(
                      AppRoutes.searchResults,
                      arguments: categoryName.trim(),
                    );
                  } else {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.home,
                      (route) => false,
                      arguments: 1,
                    );
                  }
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'More Products',
                      style: TextStyle(
                        color: Color(0xFFFB5404),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFFFB5404),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_related.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(child: Text('No related products found')),
            )
          else
            (() {
              final leftColumnItems = [];
              final rightColumnItems = [];
              for (int i = 0; i < _related.length; i++) {
                if (i % 2 == 0) {
                  leftColumnItems.add(_related[i]);
                } else {
                  rightColumnItems.add(_related[i]);
                }
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: leftColumnItems
                          .map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ProductCard(item: item),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: rightColumnItems
                          .map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ProductCard(item: item),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              );
            })(),
        ],
      ),
    );
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({
    required this.onBack,
    required this.onSearch,
    required this.onShare,
    required this.onWishlist,
    required this.onCartTap,
    required this.isWishlisted,
    required this.t,
  });

  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onShare;
  final VoidCallback onWishlist;
  final VoidCallback onCartTap;
  final bool isWishlisted;
  final double t;

  Widget _buildHeaderButton({
    required VoidCallback onTap,
    required IconData icon,
    required double iconSize,
    required Color iconColor,
    required double t,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(
          // ignore: deprecated_member_use
          Colors.black.withOpacity(0.35),
          Colors.transparent,
          t,
        ),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        icon: Icon(icon, size: iconSize, color: iconColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double topSafeArea = MediaQuery.paddingOf(context).top;
    return Container(
      height: topSafeArea + 52,
      padding: EdgeInsets.only(top: topSafeArea, left: 8, right: 8),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.white.withOpacity(t),
        boxShadow: t > 0.1
            ? [
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: Colors.black.withOpacity(0.05 * t),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          _buildHeaderButton(
            onTap: onBack,
            icon: Icons.chevron_left_rounded,
            iconSize: 28,
            iconColor: Color.lerp(Colors.white, const Color(0xFF111827), t)!,
            t: t,
          ),
          const Spacer(),
          _buildHeaderButton(
            onTap: onSearch,
            icon: Icons.search_rounded,
            iconSize: 22,
            iconColor: Color.lerp(Colors.white, const Color(0xFFDC2626), t)!,
            t: t,
          ),
          _buildHeaderButton(
            onTap: onShare,
            icon: Icons.share_outlined,
            iconSize: 20,
            iconColor: Color.lerp(Colors.white, const Color(0xFFDC2626), t)!,
            t: t,
          ),
          _buildHeaderButton(
            onTap: onWishlist,
            icon: isWishlisted ? Icons.favorite : Icons.favorite_border_rounded,
            iconSize: 20,
            iconColor: isWishlisted
                ? const Color(0xFFDC2626)
                : Color.lerp(Colors.white, const Color(0xFFDC2626), t)!,
            t: t,
          ),
          ValueListenableBuilder<int>(
            valueListenable: CartState.cartCountNotifier,
            builder: (context, cartCount, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildHeaderButton(
                    onTap: onCartTap,
                    icon: Icons.shopping_cart_outlined,
                    iconSize: 20,
                    iconColor: Color.lerp(Colors.white, const Color(0xFFDC2626), t)!,
                    t: t,
                  ),
                  if (cartCount > 0)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          '$cartCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
