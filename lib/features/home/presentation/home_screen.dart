import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:welfog_flutter_play/welfog_flutter_play.dart' as play;
import '../../../core/services/push_notification_service.dart';
import '../../../core/widgets/app_loader.dart';

import 'package:app_links/app_links.dart';
import '../../account/presentation/account_screen.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/router/app_router.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/state/cart_state.dart';
import '../../category/presentation/category_screen.dart';
import '../../cart/presentation/cart_screen.dart';
import '../../product/data/models/product_item.dart';
import '../../product/presentation/product_screen.dart';
import '../../search/presentation/search_screen.dart';
import '../../profile/data/profile_api_service.dart';
import '../data/home_api_service.dart';
import '../data/home_models.dart';
import 'widgets/home_widgets.dart';
import 'widgets/custom_bottom_tab_bar.dart';
import 'widgets/header.dart';
import 'widgets/category_widget.dart';
import 'widgets/banner_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialTab});

  final int? initialTab;
  static const routeName = AppRoutes.home;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final HomeApiService _homeApi = HomeApiService();
  late Future<HomeBundle> _bundleFuture;
  String? _loadedPincode;
  String? _displayCity;
  String? _displayPincode;

  Future<void> _loadActiveAddressFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCity = prefs.getString('city_name') ?? 'Jaipur';
    final savedPincode = prefs.getString('postal_code') ?? '302001';
    if (mounted) {
      setState(() {
        _displayCity = savedCity;
        _displayPincode = savedPincode;
      });
    }
  }

  Future<HomeBundle> _fetchBundleWithPincodeTracking() async {
    final bundle = await _homeApi.fetchHomeBundle();
    if (mounted) {
      setState(() {
        _loadedPincode = bundle.pincode;
      });
    }
    return bundle;
  }

  // Layout & Navigation State
  // ignore: unused_field
  bool _isOffline = false;
  bool _showOfflineToast = false;
  // ignore: unused_field
  bool _isLocationBlocked = false;
  bool _isCheckingLocation = false;
  bool _isGuest = true;
  // ignore: unused_field
  String _userId = 'guest';

  // Stream/Timer references for events
  StreamSubscription? _subConnectivity;
  StreamSubscription? _subDeepLinks;
  Timer? _offlineToastTimer;

  // Offline banner animation controller
  late AnimationController _offlineAnimController;
  late Animation<double> _offlineSlideAnim;

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null) {
      _currentIndex = widget.initialTab!;
    }
    _loadActiveAddressFromPrefs();
    _bundleFuture = _homeApi.getCachedHomeBundle().then((cached) {
      if (cached != null) {
        if (mounted) {
          setState(() {
            _loadedPincode = cached.pincode;
          });
        }
        return cached;
      } else {
        return _fetchBundleWithPincodeTracking();
      }
    });

    // Offline toast slide-up animation setup
    _offlineAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _offlineSlideAnim = Tween<double>(begin: 100.0, end: 0.0).animate(
      CurvedAnimation(parent: _offlineAnimController, curve: Curves.easeOut),
    );

    // Initial checkups
    _checkGuestStatus();
    CartState.loadCartCount();
    _initConnectivityListener();
    _initDeepLinkListener();
    _checkLocationStatus();
    _syncPushTokenInBackground();
    _listenToNativeFlutterEvents();
    _updateStatusBarColor();

    PushNotificationService.instance.onNotificationTapped = (data) {
      if (mounted) {
        _handleNotificationRouting(data);
      }
    };
    PushNotificationService.instance.initialize();

    play.customClosePlayCallback = () {
      if (mounted) {
        setState(() {
          _currentIndex = 0;
        });
        _updateStatusBarColor();
      }
    };
  }

  @override
  void dispose() {
    play.customClosePlayCallback = null;
    PushNotificationService.instance.onNotificationTapped = null;
    _subConnectivity?.cancel();
    _subDeepLinks?.cancel();
    _offlineToastTimer?.cancel();
    _offlineAnimController.dispose();
    super.dispose();
  }

  // 1. Dynamic Status Bar management
  void _updateStatusBarColor() {
    Color statusBarColor;
    Brightness barIconBrightness;

    switch (_currentIndex) {
      case 0: // Home
        statusBarColor = Colors.white;
        barIconBrightness = Brightness.dark;
        break;
      case 1: // Category
        statusBarColor = Colors.white;
        barIconBrightness = Brightness.dark;
        break;
      case 2: // Cart
        statusBarColor = Colors.white;
        barIconBrightness = Brightness.dark;
        break;
      case 3: // Account
        statusBarColor = Colors.white;
        barIconBrightness = Brightness.dark;
        break;
      default:
        statusBarColor = Colors.white;
        barIconBrightness = Brightness.dark;
    }

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: statusBarColor,
        statusBarIconBrightness: barIconBrightness,
        statusBarBrightness: barIconBrightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      ),
    );
  }

  // 2. Connectivity Offline handler (using placeholder stream)
  void _initConnectivityListener() {
    // Equivalent of connectivity check:
    // _subConnectivity = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
    //   bool offline = (result == ConnectivityResult.none);
    //   _toggleOfflineBanner(offline);
    // });
  }

  // ignore: unused_element
  void _toggleOfflineBanner(bool offline) {
    if (offline) {
      setState(() {
        _isOffline = true;
        _showOfflineToast = true;
      });
      _offlineAnimController.forward();
    } else {
      _offlineAnimController.reverse().then((_) {
        setState(() {
          _isOffline = false;
          _showOfflineToast = false;
        });
      });
    }
  }

  Uri? _lastHandledUri;
  DateTime? _lastHandledTime;

  // 3. Deep Linking Manager (equivalent to Linking.addEventListener)
  void _initDeepLinkListener() async {
    final appLinks = AppLinks();

    // 1. Listen to incoming links while app is running
    _subDeepLinks = appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleUriRouting(uri);
      }
    }, onError: (err) {
      debugPrint('DeepLink Error: $err');
    });

    // 2. Handle initial link if app was launched from cold state
    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUriRouting(initialUri);
      }
    } catch (e) {
      debugPrint('DeepLink Initial Link Error: $e');
    }
  }

  void _handleUriRouting(Uri uri) {
    final now = DateTime.now();
    if (_lastHandledUri == uri &&
        _lastHandledTime != null &&
        now.difference(_lastHandledTime!) < const Duration(seconds: 2)) {
      debugPrint('DeepLink: Ignore duplicate event for $uri');
      return;
    }
    _lastHandledUri = uri;
    _lastHandledTime = now;

    final segments = uri.pathSegments;
    if (segments.isEmpty) return;

    debugPrint('DeepLink: Received $uri, segments: $segments');

    final productsIdx = segments.indexOf('products');
    if (productsIdx != -1 && segments.length > productsIdx + 1) {
      final slug = segments[productsIdx + 1];
      if (slug.isNotEmpty) {
        final trimmed = slug.trim();
        if (trimmed == ProductScreen.currentlyVisibleSlug) {
          debugPrint('DeepLink: ProductScreen for slug $trimmed is already visible, skipping push.');
          return;
        }
        if (trimmed == AppRouter.lastResolvedSlug) {
          AppRouter.lastResolvedSlug = null; // Clear it so subsequent clicks are handled normally
          debugPrint('DeepLink: Skip duplicate initial route push for slug: $trimmed');
          return;
        }
        if (!mounted) return;
        Navigator.of(context).pushNamed(
          AppRoutes.product,
          arguments: trimmed,
        );
      }
    }
  }

  // 4. Background Sync Push Notifications Token status checking
  Future<void> _syncPushTokenInBackground() async {
    try {
      await PushNotificationService.instance.syncTokenWithBackend();
    } catch (e) {
      debugPrint("Background token sync skipped/failed: $e");
    }
  }

  void _handleNotificationRouting(Map<String, dynamic> data) {
    final typeForRouting = data['notificationFor'] ?? data['notification_for'];
    if (typeForRouting == null) return;

    switch (typeForRouting.toString()) {
      case 'home':
        setState(() {
          _currentIndex = 0;
        });
        _updateStatusBarColor();
        break;
      case 'track_order':
        final trackingId = data['oid'] ?? data['orderId'];
        if (trackingId != null) {
          Navigator.of(context).pushNamed(
            AppRoutes.trackOrder,
            arguments: {'oid': trackingId.toString()},
          );
        } else {
          Navigator.of(context).pushNamed(AppRoutes.trackOrder);
        }
        break;
      case 'top_deals':
        Navigator.of(context).pushNamed(AppRoutes.todayDeals);
        break;
      case 'category':
        final categoryId = data['linkId'] ?? data['categoryId'] ?? data['id'] ?? data['slug'];
        if (categoryId != null) {
          Navigator.of(context).pushNamed(
            AppRoutes.searchResults,
            arguments: {'query': '', 'categoryId': categoryId.toString()},
          );
        } else {
          setState(() {
            _currentIndex = 1; // Categories Tab index
          });
          _updateStatusBarColor();
        }
        break;
      case 'product':
        final productIdentifier = data['linkId'] ?? data['productId'] ?? data['slug'] ?? data['id'];
        if (productIdentifier != null) {
          Navigator.of(context).pushNamed(
            AppRoutes.product,
            arguments: productIdentifier.toString(),
          );
        }
        break;
    }
  }

  // 5. MethodChannel/EventEmitter listeners for Native Android/iOS calls
  void _listenToNativeFlutterEvents() {
    // Listening to native side product click notifications:
    // EventChannel or MethodChannel equivalent
  }

  // 6. User Address / Location verification logic
  Future<void> _checkLocationStatus() async {
    if (_isCheckingLocation) return;

    setState(() {
      _isCheckingLocation = true;
    });

    try {
      // final prefs = await SharedPreferences.getInstance();
      // final String? userId = prefs.getString("user_id");
      // if (userId == null) {
      //   setState(() => _isLocationBlocked = false);
      //   return;
      // }

      // API fetch call to check address count:
      // final response = await http.get(Uri.parse('$mainAPI/allAddress/$userId'));
      // final data = jsonDecode(response.body);
      // if (data['result'] == false || data['addData'].isEmpty) {
      //   setState(() => _isLocationBlocked = true);
      // } else {
      //   setState(() => _isLocationBlocked = false);
      // }
    } catch (e) {
      setState(() {
        _isLocationBlocked = false;
      });
    } finally {
      setState(() {
        _isCheckingLocation = false;
      });
    }
  }

  bool _isNameModalShowing = false;

  Future<void> _checkAndShowNameModal() async {
    if (_isNameModalShowing) return;
    final prefs = await SharedPreferences.getInstance();
    final account = prefs.getString('account') ?? 'login';
    final localName = prefs.getString('user_name') ?? '';
    final isNameSaved =
        localName.isNotEmpty &&
        localName.toLowerCase() != 'user' &&
        localName.trim().isNotEmpty;

    if (account == 'register' && !isNameSaved) {
      _isNameModalShowing = true;
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return PopScope(
            canPop: false,
            child: _NameUpdateDialog(
              onSuccess: () {
                _isNameModalShowing = false;
              },
            ),
          );
        },
      );
    }
  }

  Future<void> _checkGuestStatus() async {
    final loggedIn = await SessionStore.isLoggedIn();
    final uid = await SessionStore.getUserId();
    if (mounted) {
      setState(() {
        _isGuest = !loggedIn;
        _userId = (loggedIn && uid != null && uid.isNotEmpty) ? uid : 'guest';
      });
      if (loggedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAndShowNameModal();
          _restoreDefaultAddressCoordinates();
        });
      }
    }
  }

  Future<void> _restoreDefaultAddressCoordinates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final userId = prefs.getString('user_id') ?? '';
      if (token.isEmpty || userId.isEmpty) return;

      final cachedLat = prefs.getString('latitude');
      final cachedLng = prefs.getString('longitude');
      if (cachedLat != null &&
          cachedLat != '0' &&
          cachedLng != null &&
          cachedLng != '0') {
        return;
      }

      final uri = Uri.parse(
        'https://welfogapi.welfog.com/api/v2/get-user-by-access_token',
      );
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'access_token': token, 'userId': userId}),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['result'] == true) {
          final addressData = decoded['addressData'];
          if (addressData is Map<String, dynamic>) {
            final lat = addressData['latitude']?.toString() ?? '0';
            final lng = addressData['longitude']?.toString() ?? '0';
            final city =
                addressData['city']?.toString() ??
                addressData['city_name']?.toString() ??
                '';
            final pin = addressData['postal_code']?.toString() ?? '';

            await prefs.setString('latitude', lat);
            await prefs.setString('longitude', lng);
            if (city.isNotEmpty) {
              await prefs.setString('city_name', city);
            }
            if (pin.isNotEmpty) {
              await prefs.setString('postal_code', pin);
            }

            if (mounted) {
              setState(() {
                if (city.isNotEmpty) _displayCity = city;
                if (pin.isNotEmpty) _displayPincode = pin;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error restoring default coordinates: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomPadding = bottomInset > 0 ? bottomInset + 8 : 20.0;

    return Scaffold(
      body: Stack(
        children: [
          // Dynamic tab content
          IndexedStack(
            index: _currentIndex,
            children: [
              _HomeTab(
                bundleFuture: _bundleFuture,
                displayCity: _displayCity,
                displayPincode: _displayPincode,
                onLocationTap: () {
                  Navigator.of(context).pushNamed(AppRoutes.address).then((
                    _,
                  ) async {
                    await _loadActiveAddressFromPrefs();
                    setState(() {
                      _bundleFuture = _fetchBundleWithPincodeTracking();
                    });
                  });
                },
                onRefresh: () async {
                  await _loadActiveAddressFromPrefs();
                  setState(() {
                    _bundleFuture = _fetchBundleWithPincodeTracking();
                  });
                  await _bundleFuture;
                },
                onSearch: () {
                  Navigator.of(context).pushNamed(SearchScreen.routeName);
                },
                isGuest: _isGuest,
                promptLogin: () {
                  Navigator.of(context).pushNamed(AppRoutes.login).then((_) {
                    _checkGuestStatus();
                  });
                },
                onTabChange: (index) async {
                  setState(() {
                    _currentIndex = index;
                  });
                  _updateStatusBarColor();

                  if (index == 0) {
                    await _loadActiveAddressFromPrefs();
                    final prefs = await SharedPreferences.getInstance();
                    final savedPincode =
                        prefs.getString('postal_code') ?? '302001';
                    if (savedPincode != _loadedPincode) {
                      setState(() {
                        _bundleFuture = _fetchBundleWithPincodeTracking();
                      });
                    }
                  }
                },
              ),
              const CategoryScreen(embedded: true),
              play.EmbeddedReelsWrapper(
                key: ValueKey('play_session_$_userId'),
                viewerId: _userId,
                isActive: _currentIndex == 2,
              ),
              const CartScreen(embedded: true),
              AccountScreen(embedded: true, active: _currentIndex == 4),
            ],
          ),

          // Custom Network Offline Toast Overlay Banner
          if (_showOfflineToast)
            AnimatedBuilder(
              animation: _offlineAnimController,
              builder: (context, child) {
                return Positioned(
                  left: 20,
                  right: 20,
                  bottom: bottomPadding + 65 + _offlineSlideAnim.value,
                  child: Opacity(
                    opacity: _offlineAnimController.value,
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE63946),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      // ignore: deprecated_member_use
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                // ignore: prefer_const_constructors
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      "⚠️  No Internet Connection",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),

      // Custom Bottom Tab Bar Navigation equivalent to RN's CustomBottomTabBar
      bottomNavigationBar: _currentIndex == 2
          ? null
          : ValueListenableBuilder<int>(
              valueListenable: CartState.cartCountNotifier,
              builder: (context, cartCount, _) {
                return CustomBottomTabBar(
                  currentIndex: _currentIndex,
                  onTap: (index) async {
                    setState(() {
                      _currentIndex = index;
                    });
                    _updateStatusBarColor();
                    if (index == 3) {
                      CartScreen.emitRefreshTabAction();
                    }
                    if (index == 0) {
                      final prefs = await SharedPreferences.getInstance();
                      final savedPincode = prefs.getString('postal_code') ?? '302001';
                      if (savedPincode != _loadedPincode) {
                        setState(() {
                          _bundleFuture = _fetchBundleWithPincodeTracking();
                        });
                      }
                    }
                  },
                  isGuest: _isGuest,
                  cartCount: cartCount,
                  promptLogin: () {
                    Navigator.of(context).pushNamed(AppRoutes.login).then((_) {
                      _checkGuestStatus(); // Check guest status again when returning from Login
                    });
                  },
                  clearGuestMode: () async {
                    // Clear guest mode status if needed
                  },
                  dismissLoginModal: () {
                    // Dismiss modal if showing
                  },
                );
              },
            ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  final VoidCallback onSearch;
  final Future<HomeBundle> bundleFuture;
  final Future<void> Function() onRefresh;
  final bool isGuest;
  final VoidCallback promptLogin;
  final ValueChanged<int>? onTabChange;
  final String? displayCity;
  final String? displayPincode;
  final VoidCallback? onLocationTap;

  const _HomeTab({
    required this.onSearch,
    required this.bundleFuture,
    required this.onRefresh,
    required this.isGuest,
    required this.promptLogin,
    this.onTabChange,
    this.displayCity,
    this.displayPincode,
    this.onLocationTap,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  late ScrollController _scrollController;
  int _pullRefreshKey = 0;
  List<HomeProduct> _recentProducts = [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadRecentlyViewed();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  Future<void> _loadRecentlyViewed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedStr = prefs.getString('recently_viewed');
      if (cachedStr != null) {
        final decoded = jsonDecode(cachedStr);
        if (decoded is List) {
          final List<HomeProduct> loaded = decoded.map((item) {
            return HomeProduct(
              id: _toInt(item['id']),
              name: (item['name'] ?? '').toString(),
              price: _toDouble(item['price']),
              mrp: _toDouble(item['mrp'] ?? item['price']),
              image: (item['image'] ?? '').toString(),
              slug: (item['slug'] ?? '').toString(),
              duration: _toInt(item['duration']),
              brand: (item['brand'] ?? '').toString(),
              rating: _toDouble(item['rating'] ?? 4.3),
            );
          }).toList();

          if (mounted) {
            setState(() {
              _recentProducts = loaded;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _recentProducts = [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading recently viewed on home: $e');
    }
  }

  ProductItem _toProductItem(HomeProduct p, int index) {
    const fallbackColors = [
      Color(0xFFFFD9D9),
      Color(0xFFDDF4FF),
      Color(0xFFE8FFE1),
      Color(0xFFFFF0CC),
      Color(0xFFF3E8FF),
    ];
    return ProductItem(
      id: p.id.toString(),
      title: p.name,
      subtitle: p.brand.isEmpty ? 'Fast delivery' : p.brand,
      price: p.price,
      rating: p.rating,
      color: fallbackColors[index % fallbackColors.length],
      imageUrl: p.image,
      slug: p.slug,
      brand: p.brand,
      durationMinutes: p.duration,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeBundle>(
      future: widget.bundleFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const AppLoader.page();
        }
        if (snap.hasError || !snap.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Failed to load home data'),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: widget.onRefresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final bundle = snap.data!;
        final dealList = bundle.todayDeals.take(10).toList();
        final sections = bundle.sections.take(4).toList();

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _pullRefreshKey++;
                });
                await _loadRecentlyViewed();
                await widget.onRefresh();
              },
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.top + 140,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: CategoryWidget(
                      pullRefreshKey: _pullRefreshKey,
                      onTabChange: widget.onTabChange,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: BannerWidget(slides: bundle.mobileSlider),
                  ),
                  const SliverToBoxAdapter(child: TrustStrip()),
                  if (_recentProducts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: ProductStrip(
                          title: 'Recently Viewed',
                          products: _recentProducts,
                          onProductTap: (p) {
                            Navigator.of(context)
                                .pushNamed(
                                  AppRoutes.product,
                                  arguments: _toProductItem(
                                    p,
                                    _recentProducts.indexOf(p),
                                  ),
                                )
                                .then((_) => _loadRecentlyViewed());
                          },
                          onRightIconTap: () {
                            Navigator.of(context)
                                .pushNamed(AppRoutes.recentlyViewed)
                                .then((_) => _loadRecentlyViewed());
                          },
                        ),
                      ),
                    ),
                  if (bundle.banner1.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                        child: Column(
                          children: bundle.banner1
                              .where((b) => b.image.trim().isNotEmpty)
                              .map(
                                (b) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: GestureDetector(
                                    onTap: () {
                                      final link = b.link;
                                      if (link != null &&
                                          link.isNotEmpty &&
                                          link != '#') {
                                        final parts = link
                                            .replaceAll(RegExp(r'/$'), '')
                                            .split('/');
                                        final slug = parts.isNotEmpty
                                            ? parts.last
                                            : null;
                                        if (slug != null && slug.isNotEmpty) {
                                          Navigator.of(context)
                                              .pushNamed(
                                                AppRoutes.searchResults,
                                                arguments: slug,
                                              )
                                              .then(
                                                (_) => _loadRecentlyViewed(),
                                              );
                                        }
                                      }
                                    },
                                    child: PromoBannerImage(imageUrl: b.image),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: ProductStrip(
                        title: 'Today Deals',
                        products: dealList,
                        onProductTap: (p) {
                          Navigator.of(context)
                              .pushNamed(
                                AppRoutes.product,
                                arguments: _toProductItem(
                                  p,
                                  dealList.indexOf(p),
                                ),
                              )
                              .then((_) => _loadRecentlyViewed());
                        },
                        onRightIconTap: () {
                          Navigator.of(context)
                              .pushNamed(AppRoutes.todayDeals)
                              .then((_) => _loadRecentlyViewed());
                        },
                      ),
                    ),
                  ),
                  if (bundle.banner2.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                        child: Column(
                          children: bundle.banner2
                              .where((b) => b.image.trim().isNotEmpty)
                              .take(2)
                              .map(
                                (b) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: GestureDetector(
                                    onTap: () {
                                      final link = b.link;
                                      if (link != null &&
                                          link.isNotEmpty &&
                                          link != '#') {
                                        final parts = link
                                            .replaceAll(RegExp(r'/$'), '')
                                            .split('/');
                                        final slug = parts.isNotEmpty
                                            ? parts.last
                                            : null;
                                        if (slug != null && slug.isNotEmpty) {
                                          Navigator.of(context)
                                              .pushNamed(
                                                AppRoutes.searchResults,
                                                arguments: slug,
                                              )
                                              .then(
                                                (_) => _loadRecentlyViewed(),
                                              );
                                        }
                                      }
                                    },
                                    child: PromoBannerImage(imageUrl: b.image),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ...sections.map(
                    (s) => SliverToBoxAdapter(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: ProductStrip(
                              title: s.name,
                              products: s.products.take(10).toList(),
                              onProductTap: (p) {
                                Navigator.of(context)
                                    .pushNamed(
                                      AppRoutes.product,
                                      arguments: _toProductItem(
                                        p,
                                        s.products.indexOf(p),
                                      ),
                                    )
                                    .then((_) => _loadRecentlyViewed());
                              },
                              onRightIconTap: () {
                                Navigator.of(context)
                                    .pushNamed(
                                      AppRoutes.searchResults,
                                      arguments: {
                                        'query': s.name,
                                        'categoryId': s.id,
                                      },
                                    )
                                    .then((_) => _loadRecentlyViewed());
                              },
                            ),
                          ),
                          if (s.bannerData.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: BannerCarousel(items: s.bannerData),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            ),
            Header(
              isHome: true,
              scrollController: _scrollController,
              city: widget.displayCity ?? bundle.city,
              pincode: widget.displayPincode ?? bundle.pincode,
              isGuest: widget.isGuest,
              onSearchTap: widget.onSearch,
              promptLogin: widget.promptLogin,
              onLocationTap: widget.onLocationTap,
            ),
          ],
        );
      },
    );
  }
}

class _NameUpdateDialog extends StatefulWidget {
  final VoidCallback onSuccess;

  const _NameUpdateDialog({required this.onSuccess});

  @override
  State<_NameUpdateDialog> createState() => _NameUpdateDialogState();
}

class _NameUpdateDialogState extends State<_NameUpdateDialog> {
  final TextEditingController _controller = TextEditingController();
  final ProfileApiService _profileApi = ProfileApiService();
  String? _errorText;
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorText = 'Name is required*';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      final token = prefs.getString('access_token') ?? '';

      // Save local states immediately (just like React Native does)
      await prefs.setString('user_name', name);
      await prefs.setString('loginuser', name);
      await prefs.setString('account', 'login');
      await prefs.remove('post_login_check');

      if (userId.isNotEmpty && token.isNotEmpty) {
        try {
          await _profileApi.updateProfileName(
            userId: userId,
            accessToken: token,
            name: name,
          );
        } catch (apiError) {
          debugPrint('Profile API update failed: $apiError');
        }
      }

      if (mounted) {
        widget.onSuccess();
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorText = 'Could not save name. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_circle,
              size: 60.0,
              color: Color(0xFF008083),
            ),
            const SizedBox(height: 10.0),
            const Text(
              'Complete your profile',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20.0),
            TextField(
              controller: _controller,
              maxLength: 30,
              decoration: InputDecoration(
                hintText: 'Full Name',
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12.0,
                  horizontal: 16.0,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(
                    color: _errorText != null ? Colors.red : Colors.grey[300]!,
                    width: 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(
                    color: _errorText != null
                        ? Colors.red
                        : const Color(0xFF008083),
                    width: 1.0,
                  ),
                ),
              ),
              onChanged: (val) {
                if (_errorText != null) {
                  setState(() {
                    _errorText = null;
                  });
                }
              },
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 5.0),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 5.0),
                  child: Text(
                    _errorText!,
                    style: const TextStyle(color: Colors.red, fontSize: 12.0),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20.0),
            SizedBox(
              width: double.infinity,
              height: 50.0,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveName,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008083),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const AppLoader.button()
                    : const Text(
                        'Save & Continue',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16.0,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrustStrip extends StatelessWidget {
  const TrustStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 1.0),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _buildItem(
                Icons.local_shipping_outlined,
                'Free Delivery',
                'on orders',
              ),
            ),
            Container(width: 1, color: const Color(0xFFE6E6E6)),
            Expanded(
              child: _buildItem(
                Icons.cached_outlined,
                'Easy Returns',
                'Hassle-free returns',
              ),
            ),
            Container(width: 1, color: const Color(0xFFE6E6E6)),
            Expanded(
              child: _buildItem(
                Icons.gpp_good_outlined,
                'Secure Payment',
                '100% secure checkout',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(IconData icon, String title, String subtitle) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: const Color(0xFFFB5404), size: 20),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111111),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 10, color: Color(0xFF666666)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
