import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_routes.dart';

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
  
  // Local States
  List<BannerData> _slides = [];
  bool _loading = true;
  bool _error = false;
  int _activePage = 0;
  bool _isManualSwipe = false;

  // Active timers and listeners
  Timer? _autoScrollTimer;
  Timer? _userSwipeResetTimer;
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
      duration: const Duration(milliseconds: 2800),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_progressController);

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
    _autoScrollTimer?.cancel();
    _userSwipeResetTimer?.cancel();
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
          _startProgressAnimation();
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
              _startProgressAnimation();
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
          final double ratio = info.image.width / info.image.height;
          if (mounted && ratio > 0) {
            setState(() {
              _aspectRatios[i] = ratio;
            });
          }
        }),
      );
    }
  }

  // Start periodic pages auto rotation
  void _startAutoCarousel() {
    _autoScrollTimer?.cancel();
    if (_slides.length <= 1) return;

    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isManualSwipe) {
        if (mounted) {
          setState(() {
            _isManualSwipe = false;
          });
        }
        return;
      }

      int nextPage = _activePage + 1;
      if (nextPage >= _slides.length) nextPage = 0;

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // Slide progress bar indicator transition
  void _startProgressAnimation() {
    _progressController.reset();
    _progressController.forward();
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

    final double activeAspect = _aspectRatios[_activePage] ?? 3.0;

    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 12, right: 12, bottom: 4),
      child: Column(
        children: [
          // Dynamic heights PageView Carousel container
          AspectRatio(
            aspectRatio: activeAspect,
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification notification) {
                if (notification is ScrollStartNotification) {
                  setState(() {
                    _isManualSwipe = true;
                  });
                  _userSwipeResetTimer?.cancel();
                } else if (notification is ScrollEndNotification) {
                  _userSwipeResetTimer = Timer(const Duration(seconds: 5), () {
                    if (mounted) {
                      setState(() {
                        _isManualSwipe = false;
                      });
                    }
                  });
                }
                return true;
              },
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() {
                    _activePage = index;
                  });
                  _startProgressAnimation();
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return GestureDetector(
                    onTap: () => _handleBannerPress(slide),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
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
          const SizedBox(height: 10),

          // Custom indicator pill progress bar
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.length, (index) {
              final bool isActive = index == _activePage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 5,
                width: isActive ? 30 : 15,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD4D4),
                  borderRadius: BorderRadius.circular(6),
                ),
                clipBehavior: Clip.antiAlias,
                child: isActive
                    ? AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: _progressAnimation.value,
                              child: Container(
                                color: const Color(0xFF2B2B2B),
                              ),
                            ),
                          );
                        },
                      )
                    : null,
              );
            }),
          ),
        ],
      ),
    );
  }
}
