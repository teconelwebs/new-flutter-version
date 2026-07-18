import 'package:flutter/material.dart';

import '../../data/home_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../account/data/account_api_service.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/state/wishlist_state.dart';

double _safeBannerAspectRatio(double? ratio, {double fallback = 3.0}) {
  if (ratio == null || !ratio.isFinite || ratio <= 0) return fallback;
  return ratio.clamp(1.2, 5.0);
}

/// Grid cell aspect ratio for [HomeProductCard] (square image + text block).
double homeProductGridAspectRatio(
  double screenWidth, {
  double horizontalPadding = 12,
  double crossAxisSpacing = 12,
}) {
  final cardWidth =
      (screenWidth - horizontalPadding * 2 - crossAxisSpacing) / 2;
  final contentHeight = screenWidth < 360 ? 76.0 : 84.0;
  return cardWidth / (cardWidth + contentHeight);
}

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.city,
    required this.pincode,
    required this.onSearchTap,
  });

  final String city;
  final String pincode;
  final VoidCallback onSearchTap;
  static const _brandLogoUrl = 'https://welfog.com/assets/crux/welf.png';

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(12, topInset > 0 ? 6 : 10, 12, 6),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE9ECEF))),
            color: Colors.white,
          ),
          child: Row(
            children: [
              const Icon(Icons.location_pin, size: 16, color: Color(0xFFFB5404)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Deliver to $city - $pincode',
                  style: const TextStyle(
                    color: Color(0xFF0B7E7B),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: Color(0xFF0B7E7B)),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Image.network(
                      _brandLogoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Text(
                        'Welfog',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.favorite_border_rounded,
                    color: Color(0xFFFB5404)),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none_rounded,
                    color: Color(0xFFFB5404)),
              ),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: GestureDetector(
            onTap: onSearchTap,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE8E8E8)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: const Row(
                children: [
                  Icon(Icons.search, color: Color(0xFF666666), size: 20),
                  SizedBox(width: 10),
                  Text('Search for ', style: TextStyle(color: Color(0xFF999999))),
                  Text(
                    'Mobile',
                    style: TextStyle(
                      color: Color(0xFFF47405),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class BannerCarousel extends StatefulWidget {
  const BannerCarousel({
    super.key,
    required this.items,
  });

  final List<HomeBanner> items;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> with TickerProviderStateMixin {
  static const Duration _slideDuration = Duration(milliseconds: 3000);

  final _controller = PageController();
  int _index = 0;
  bool _isManualSwipe = false;
  bool _isAutoAdvancing = false;
  int? _pageAtScrollStart;
  final Map<int, double> _aspectRatios = {};

  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: _slideDuration,
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_progressController);
    _progressController.addStatusListener(_onProgressStatusChanged);
    _precalculateAspectRatios();
    _startProgressFill();
  }

  List<HomeBanner> get _validItems =>
      widget.items.where((b) => b.image.trim().isNotEmpty).toList();

  @override
  void didUpdateWidget(covariant BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _aspectRatios.clear();
      _index = 0;
      if (_controller.hasClients) {
        _controller.jumpToPage(0);
      }
      _precalculateAspectRatios();
      _startProgressFill();
    }
  }

  @override
  void dispose() {
    _progressController.removeStatusListener(_onProgressStatusChanged);
    _progressController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onProgressStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed ||
        _isManualSwipe ||
        _isAutoAdvancing ||
        _validItems.length <= 1 ||
        !mounted) {
      return;
    }
    _autoAdvance();
  }

  Future<void> _autoAdvance() async {
    if (!_controller.hasClients || !mounted) return;
    _isAutoAdvancing = true;
    final nextPage = (_index + 1) % _validItems.length;
    try {
      await _controller.animateToPage(
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
    if (_validItems.length <= 1 || !mounted) return;
    _progressController
      ..stop()
      ..value = 0;
    _progressController.forward(from: 0);
  }

  void _onPageChanged(int i) {
    if (!mounted) return;
    _progressController
      ..stop()
      ..value = 0;
    setState(() => _index = i);
    if (!_isAutoAdvancing) {
      _startProgressFill();
    }
  }

  void _precalculateAspectRatios() {
    final items = _validItems;
    for (int i = 0; i < items.length; i++) {
      final imgUrl = items[i].image;
      final image = NetworkImage(imgUrl);
      image.resolve(const ImageConfiguration()).addListener(
        ImageStreamListener((ImageInfo info, bool _) {
          final ratio = info.image.height > 0
              ? info.image.width / info.image.height
              : 3.0;
          if (mounted) {
            setState(() => _aspectRatios[i] = _safeBannerAspectRatio(ratio));
          }
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _validItems;
    if (items.isEmpty) return const SizedBox.shrink();

    final activeAspect = _safeBannerAspectRatio(_aspectRatios[_index]);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: AspectRatio(
              aspectRatio: activeAspect,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification) {
                    _pageAtScrollStart = _index;
                    _progressController.stop();
                    setState(() => _isManualSwipe = true);
                  } else if (notification is ScrollEndNotification) {
                    setState(() => _isManualSwipe = false);
                    if (_pageAtScrollStart == _index) {
                      _startProgressFill();
                    }
                  }
                  return false;
                },
                child: PageView.builder(
                  controller: _controller,
                  itemCount: items.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, i) {
                    final banner = items[i];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        banner.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFECEFF3),
                          child: const Center(child: Icon(Icons.image_not_supported)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _progressAnimation,
          builder: (context, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length, (i) {
                final isActive = i == _index;
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
    );
  }
}

class PromoBannerImage extends StatefulWidget {
  const PromoBannerImage({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  State<PromoBannerImage> createState() => _PromoBannerImageState();
}

class _PromoBannerImageState extends State<PromoBannerImage> {
  double _aspectRatio = 3.0;

  double get _displayAspectRatio {
    if (!_aspectRatio.isFinite || _aspectRatio <= 0) return 3.0;
    return _aspectRatio;
  }

  @override
  void initState() {
    super.initState();
    _loadAspectRatio();
  }

  @override
  void didUpdateWidget(covariant PromoBannerImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _aspectRatio = 3.0;
      _loadAspectRatio();
    }
  }

  void _loadAspectRatio() {
    if (widget.imageUrl.trim().isEmpty) return;
    final image = NetworkImage(widget.imageUrl);
    image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (info.image.height <= 0) return;
        final ratio = info.image.width / info.image.height;
        if (mounted && ratio.isFinite && ratio > 0) {
          setState(() => _aspectRatio = ratio);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AspectRatio(
        aspectRatio: _displayAspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            widget.imageUrl,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFFECEFF3),
              alignment: Alignment.center,
              child: const Icon(Icons.image_not_supported_outlined, size: 32),
            ),
          ),
        ),
      ),
    );
  }
}

class ProductStrip extends StatelessWidget {
  const ProductStrip({
    super.key,
    required this.title,
    required this.products,
    required this.onProductTap,
    this.onRightIconTap,
    this.titleIcon,
  });

  final String title;
  final Widget? titleIcon;
  final List<HomeProduct> products;
  final void Function(HomeProduct product) onProductTap;
  final VoidCallback? onRightIconTap;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = (screenWidth * 0.42).clamp(140.0, 175.0);
    final stripHeight = cardWidth + 88;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    if (titleIcon != null) ...[
                      const SizedBox(width: 6),
                      titleIcon!,
                    ],
                  ],
                ),
              ),
              GestureDetector(
                onTap: onRightIconTap,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFB5404),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x15FB5404),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: stripHeight,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final p = products[i];
              return HomeProductCard(
                product: p,
                cardWidth: cardWidth,
                onTap: () => onProductTap(p),
              );
            },
          ),
        ),
      ],
    );
  }
}

class HomeProductCard extends StatefulWidget {
  final HomeProduct product;
  final double? cardWidth;
  final VoidCallback onTap;

  const HomeProductCard({
    super.key,
    required this.product,
    this.cardWidth,
    required this.onTap,
  });

  @override
  State<HomeProductCard> createState() => _HomeProductCardState();
}

class _HomeProductCardState extends State<HomeProductCard> {
  final _apiService = AccountApiService();
  bool _isWishlisted = false;
  bool _toggling = false;

  static String _calcDelivery(int durationMinutes) {
    if (durationMinutes <= 0) return '2 - 4 days';
    final days = durationMinutes ~/ 1440;
    if (days > 0) return '$days - ${days + 1} days';
    final hours = (durationMinutes % 1440) ~/ 60;
    final mins = durationMinutes % 60;
    if (hours > 0) return '$hours hr${hours > 1 ? 's' : ''}';
    if (mins > 0) return '$mins min${mins > 1 ? 's' : ''}';
    return '2 - 4 days';
  }

  @override
  void initState() {
    super.initState();
    _checkWishlistState();
    WishlistState.wishlistNotifier.addListener(_wishlistListener);
  }

  @override
  void dispose() {
    WishlistState.wishlistNotifier.removeListener(_wishlistListener);
    super.dispose();
  }

  void _wishlistListener() {
    final productId = widget.product.id.toString();
    if (WishlistState.wishlistNotifier.value.containsKey(productId)) {
      final val = WishlistState.wishlistNotifier.value[productId]!;
      if (val != _isWishlisted && mounted) {
        setState(() {
          _isWishlisted = val;
        });
      }
    }
  }

  @override
  void didUpdateWidget(HomeProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) {
      _checkWishlistState();
    }
  }

  Future<void> _checkWishlistState() async {
    final wishState = await WishlistState.isWishlisted(widget.product.id.toString());
    if (mounted) {
      setState(() {
        _isWishlisted = wishState;
      });
    }
  }

  Future<void> _toggleWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) {
      if (mounted) {
        Navigator.of(context).pushNamed(AppRoutes.login);
      }
      return;
    }

    setState(() => _toggling = true);

    try {
      if (_isWishlisted) {
        final compareMapStr = prefs.getString('wishlist_compare_map') ?? '{}';
        final compareMap = Map<String, dynamic>.from(jsonDecode(compareMapStr));
        final compareIdStr = compareMap[widget.product.id.toString()];
        final compareId = int.tryParse(compareIdStr ?? '') ?? 0;

        final success = await _apiService.removeWishlistItem(widget.product.id, compareId);
        if (success) {
          await WishlistState.updateWishlistState(widget.product.id.toString(), false);
          if (mounted) {
            const msg = 'Item removed from wishlist';
            const textWidth = (msg.length * 7.5) + 32;
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
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
      } else {
        final success = await _apiService.addWishlistItem(widget.product.id);
        if (success) {
          await WishlistState.updateWishlistState(widget.product.id.toString(), true);
          if (mounted) {
            const msg = 'Item added to wishlist';
            const textWidth = (msg.length * 7.5) + 32;
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
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
      }
    } catch (_) {
      // Ignore
    } finally {
      if (mounted) {
        setState(() => _toggling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final discount = p.mrp > p.price && p.price > 0
        ? (((p.mrp - p.price) / p.mrp) * 100).round()
        : 0;

    final contentSection = Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            p.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              height: 1.2,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Flexible(
                child: Text(
                  'Rs ${p.price.toStringAsFixed(0)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0B7E7B),
                    fontSize: 12.5,
                  ),
                ),
              ),
              if (p.mrp > p.price) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Rs ${p.mrp.toStringAsFixed(0)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Color(0xFF9AA0A6),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined, size: 11, color: Color(0xFFFB5404)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Est. delivery: ${_calcDelivery(p.duration)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF555555),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: widget.onTap,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: widget.cardWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEDEDED)),
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
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                      child: Container(
                        color: const Color(0xFFF8F9FA),
                        child: Image.network(
                          p.image,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFF2F4F7),
                            child: const Center(child: Icon(Icons.shopping_bag_outlined)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (discount > 0)
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
                          '$discount% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: _toggling ? null : _toggleWishlist,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          // ignore: deprecated_member_use
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x10000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _toggling
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFB5404)),
                                  ),
                                )
                              : Icon(
                                  _isWishlisted ? Icons.favorite : Icons.favorite_border,
                                  color: _isWishlisted ? const Color(0xFFFB5404) : const Color(0xFF777777),
                                  size: 16,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            contentSection,
          ],
        ),
      ),
    ));
  }
}
