import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_routes.dart';

double _safeBannerAspectRatio(double? ratio, {double fallback = 3.0}) {
  if (ratio == null || !ratio.isFinite || ratio <= 0) return fallback;
  return ratio.clamp(1.2, 5.0);
}

class BannerData {
  final String image;
  final String? link;

  BannerData({required this.image, this.link});

  factory BannerData.fromJson(Map<String, dynamic> json) {
    return BannerData(
      image: json['image'] ?? "",
      link: json['link'],
    );
  }

  Map<String, dynamic> toJson() => {
        'image': image,
        'link': link,
      };
}

class BannerWidget extends StatefulWidget {
  final int pullRefreshKey;

  const BannerWidget({
    super.key,
    this.pullRefreshKey = 0,
  });

  @override
  State<BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<BannerWidget> with TickerProviderStateMixin {
  final PageController _pageController = PageController();

  static const Duration _slideDuration = Duration(milliseconds: 3000);

  // Local States
  List<BannerData> _slides = [];
  bool _loading = true;
  bool _error = false;
  int _activePage = 0;
  bool _isManualSwipe = false;
  bool _isAutoAdvancing = false;
  int? _pageAtScrollStart;

  final Map<int, double> _aspectRatios = {};

  // Progress indicators animations references
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  static const String cacheKey = "home_mobile_slider_v3";

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: _slideDuration,
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_progressController);
    _progressController.addStatusListener(_onProgressStatusChanged);

    _initBannersData();
  }

  @override
  void didUpdateWidget(covariant BannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pullRefreshKey > 0 && widget.pullRefreshKey != oldWidget.pullRefreshKey) {
      _fetchBanners(force: true);
    }
  }

  @override
  void dispose() {
    _progressController.removeStatusListener(_onProgressStatusChanged);
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  // Cache loading logic
  Future<void> _initBannersData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);

      if (raw != null) {
        final parsed = jsonDecode(raw);
        final List<dynamic> rawSlides = parsed['slides'] ?? [];

        if (rawSlides.isNotEmpty) {
          final loadedSlides = rawSlides.map((s) => BannerData.fromJson(s)).toList();
          setState(() {
            _slides = loadedSlides;
            _loading = false;
          });
          _precalculateAspectRatios();
          _startAutoCarousel();
          return;
        }
      }
    } catch (_) {}

    await _fetchBanners();
  }

  // Fetch slider items from network with retry fallback
  Future<void> _fetchBanners({bool force = false}) async {
    if (!force && _slides.isNotEmpty) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = _slides.isEmpty;
        _error = false;
      });
    }

    const String apiUrl = "https://welfogapi.welfog.com/api/v2/bannerdata/";
    const String cdnBase = "https://d1f02fefkbso7w.cloudfront.net/";

    int attempts = 3;
    for (int i = 1; i <= attempts; i++) {
      try {
        final response = await http.get(Uri.parse(apiUrl));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          final rawSlides = decoded['mobile_slider'] as List? ?? [];
          
          final List<BannerData> parsedSlides = rawSlides.whereType<Map>().map((e) {
            final String img = (e['image'] ?? "").toString();
            final String fullImg = img.startsWith("http") ? img : "$cdnBase$img";
            return BannerData(
              image: fullImg,
              link: (e['link'] ?? "").toString(),
            );
          }).toList();

          if (parsedSlides.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              cacheKey,
              jsonEncode({
                'ts': DateTime.now().millisecondsSinceEpoch,
                'slides': parsedSlides.map((s) => s.toJson()).toList(),
              }),
            );

            if (mounted) {
              setState(() {
                _slides = parsedSlides;
                _loading = false;
                _error = false;
              });
              _precalculateAspectRatios();
              _startAutoCarousel();
            }
            return;
          }
        }
      } catch (err) {
        debugPrint("Error fetching banners attempt $i: $err");
        if (i == attempts && mounted) {
          setState(() {
            _error = _slides.isEmpty;
            _loading = false;
          });
        }
      }
      await Future.delayed(Duration(milliseconds: 300 * i));
    }
  }

  // Dynamic Image resolution/aspect ratio calculations
  void _precalculateAspectRatios() {
    for (int i = 0; i < _slides.length; i++) {
      final imgUrl = _slides[i].image;
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

  // Navigation triggers on slide clicks
  void _handleBannerPress(BannerData slide) {
    if (slide.link == null || slide.link!.isEmpty) return;

    final parts = slide.link!.replaceAll(RegExp(r'/$'), '').split('/');
    final slug = parts.isNotEmpty ? parts.last : null;

    if (slug != null) {
      Navigator.of(context).pushNamed(
        AppRoutes.searchResults,
        arguments: slug,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: AspectRatio(
          aspectRatio: 3 / 1,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (_error) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            "Failed to load banners",
            style: TextStyle(color: Colors.red.shade700, fontSize: 16),
          ),
        ),
      );
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
