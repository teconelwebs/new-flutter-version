import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_routes.dart';
import '../../data/home_models.dart';

double _safeBannerAspectRatio(double? ratio, {double fallback = 3.0}) {
  if (ratio == null || !ratio.isFinite || ratio <= 0) return fallback;
  return ratio.clamp(1.2, 5.0);
}

class BannerWidget extends StatefulWidget {
  final List<HomeBanner> slides;

  const BannerWidget({
    super.key,
    required this.slides,
  });

  @override
  State<BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<BannerWidget> with TickerProviderStateMixin {
  final PageController _pageController = PageController();

  static const Duration _slideDuration = Duration(milliseconds: 3000);

  List<HomeBanner> _slides = [];
  int _activePage = 0;
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

    _slides = widget.slides;
    _precalculateAspectRatios();
    _startAutoCarousel();
  }

  @override
  void didUpdateWidget(covariant BannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.slides != oldWidget.slides) {
      setState(() {
        _slides = widget.slides;
        _activePage = 0;
      });
      _precalculateAspectRatios();
      _startAutoCarousel();
    }
  }

  @override
  void dispose() {
    _progressController.removeStatusListener(_onProgressStatusChanged);
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _precalculateAspectRatios() {
    for (int i = 0; i < _slides.length; i++) {
      final imgUrl = _slides[i].image;
      if (imgUrl.trim().isEmpty) continue;
      final Image image = Image.network(imgUrl);
      
      image.image.resolve(const ImageConfiguration()).addListener(
        ImageStreamListener((ImageInfo info, bool _) {
          final double ratio = info.image.height > 0
              ? info.image.width / info.image.height
              : 3.0;
          if (mounted) {
            setState(() {
              _aspectRatios[i] = _safeBannerAspectRatio(ratio);
            });
          }
        }),
      );
    }
  }

  void _onProgressStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed ||
        _isManualSwipe ||
        _isAutoAdvancing ||
        _slides.length <= 1 ||
        !mounted) {
      return;
    }
    _autoAdvance();
  }

  Future<void> _autoAdvance() async {
    if (!_pageController.hasClients || !mounted) return;
    _isAutoAdvancing = true;
    final nextPage = (_activePage + 1) % _slides.length;
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
    if (_slides.length <= 1 || !mounted) return;
    _progressController
      ..stop()
      ..value = 0;
    _progressController.forward(from: 0);
  }

  void _startAutoCarousel() {
    if (_slides.length <= 1) return;
    _startProgressFill();
  }

  void _onPageChanged(int index) {
    if (!mounted) return;
    _progressController
      ..stop()
      ..value = 0;
    setState(() => _activePage = index);
    if (!_isAutoAdvancing) {
      _startProgressFill();
    }
  }

  void _handleBannerPress(HomeBanner slide) {
    if (slide.link == null || slide.link!.isEmpty) return;

    final parts = slide.link!.replaceAll(RegExp(r'/$'), '').split('/');
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
    if (_slides.isEmpty) {
      return const SizedBox.shrink();
    }

    final double activeAspect = _safeBannerAspectRatio(_aspectRatios[_activePage]);

    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 12, right: 12, bottom: 4),
      child: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: AspectRatio(
              aspectRatio: activeAspect,
              child: NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification notification) {
                  if (notification is ScrollStartNotification) {
                    _pageAtScrollStart = _activePage;
                    _progressController.stop();
                    setState(() => _isManualSwipe = true);
                  } else if (notification is ScrollEndNotification) {
                    setState(() => _isManualSwipe = false);
                    if (_pageAtScrollStart == _activePage) {
                      _startProgressFill();
                    }
                  }
                  return false;
                },
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return GestureDetector(
                      onTap: () => _handleBannerPress(slide),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: slide.image.trim().isEmpty
                            ? Container(
                                color: Colors.grey.shade300,
                                alignment: Alignment.center,
                                child: const Icon(Icons.image, size: 40),
                              )
                            : Image.network(
                                slide.image,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade300,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.image, size: 40),
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Custom indicator pill progress bar
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (index) {
                  final isActive = index == _activePage;
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
      ),
    );
  }
}
