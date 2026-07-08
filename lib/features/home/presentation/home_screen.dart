import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: unused_import
import 'package:welfog_flutter_play/welfog_flutter_play.dart' as play;

import '../../account/presentation/account_screen.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/state/cart_state.dart';
import '../../category/presentation/category_screen.dart';
import '../../cart/presentation/cart_screen.dart';
import '../../product/data/models/product_item.dart';
import '../../search/presentation/search_screen.dart';
import '../data/home_api_service.dart';
import '../data/home_models.dart';
import 'widgets/home_widgets.dart';
import 'widgets/custom_bottom_tab_bar.dart';
import 'widgets/header.dart';
import 'widgets/category_widget.dart';
import 'widgets/banner_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const routeName = AppRoutes.home;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
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
  }

  @override
  void dispose() {
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
        statusBarBrightness: barIconBrightness == Brightness.light ? Brightness.dark : Brightness.light,
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

  // 3. Deep Linking Manager (equivalent to Linking.addEventListener)
  void _initDeepLinkListener() {
    // Standard Universal/Scheme link mapping equivalent:
    // _subDeepLinks = linkStream.listen((String? link) {
    //   if (link != null) _handleUriRouting(Uri.parse(link));
    // });
  }

  // ignore: unused_element
  void _handleUriRouting(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return;

    switch (segments[0]) {
      case "products":
        if (segments.length > 1) {
          // ignore: unused_local_variable
          final slug = segments[1];
          // Navigate to Product Details screen
          // Navigator.pushNamed(context, '/product', arguments: slug);
        }
        break;
      case "OtheruserProfile":
        if (segments.length > 1) {
          // ignore: unused_local_variable
          final profileId = segments[1];
          // Open other user profile screen
        }
        break;
      case "Play":
        if (segments.length > 2 && segments[1] == "sepreel") {
          // ignore: unused_local_variable
          final playId = segments[2];
          // Open Reel / Play module
        }
        break;
      default:
        break;
    }
  }

  // 4. Background Sync Push Notifications Token status checking
  Future<void> _syncPushTokenInBackground() async {
    try {
      // Fetch userId from Storage/SharedPreferences:
      // final prefs = await SharedPreferences.getInstance();
      // final String? userId = prefs.getString("user_id");
      // if (userId == null) return;

      // GET API call token-status check
      // final response = await http.get(Uri.parse('$secondAPI/notification/token-status?user_id=$userId'));
      // if (response.statusCode == 200) {
      //   // Sync logic: If not exists, fetch and save token via POST '/notification/save-token'
      // }
    } catch (e) {
      debugPrint("Background token sync skipped/failed: $e");
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

  Future<void> _checkGuestStatus() async {
    final loggedIn = await SessionStore.isLoggedIn();
    final uid = await SessionStore.getUserId();
    if (mounted) {
      setState(() {
        _isGuest = !loggedIn;
        _userId = (loggedIn && uid != null && uid.isNotEmpty) ? uid : 'guest';
      });
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
                  Navigator.of(context).pushNamed(AppRoutes.address).then((_) async {
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
                onSearch: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final keyword = prefs.getString('last_search_keyword');
                  if (!context.mounted) return;
                  Navigator.of(context).pushNamed(
                    SearchScreen.routeName,
                    arguments: keyword,
                  );
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
                    final savedPincode = prefs.getString('postal_code') ?? '302001';
                    if (savedPincode != _loadedPincode) {
                      setState(() {
                        _bundleFuture = _fetchBundleWithPincodeTracking();
                      });
                    }
                  }
                },
              ),
              const CategoryScreen(embedded: true),
              // play.EmbeddedReelsWrapper(
              //   key: ValueKey('play_session_$_userId'),
              //   viewerId: _userId,
              // ),
              const CartScreen(embedded: true),
              const AccountScreen(embedded: true),
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
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: CartState.cartCountNotifier,
        builder: (context, cartCount, _) {
          return CustomBottomTabBar(
            currentIndex: _currentIndex,
            onTap: (index) async {
              setState(() {
                _currentIndex = index;
              });
              _updateStatusBarColor();
              if (index == 2) {
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

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFFB5404),
            ),
          );
        }
        if (snap.hasError || !snap.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Failed to load home data'),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: widget.onRefresh, child: const Text('Retry')),
              ],
            ),
          );
        }

        final bundle = snap.data!;
        final dealList = bundle.todayDeals.take(10).toList();
        final sections = bundle.sections.take(4).toList();
        final promo = [...bundle.banner1, ...bundle.banner2]
            .where((b) => b.image.trim().isNotEmpty)
            .take(3)
            .toList();

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _pullRefreshKey++;
                });
                await widget.onRefresh();
              },
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(height: MediaQuery.of(context).padding.top + 140),
                  ),
                  SliverToBoxAdapter(
                    child: CategoryWidget(
                      pullRefreshKey: _pullRefreshKey,
                      onTabChange: widget.onTabChange,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: BannerWidget(
                      pullRefreshKey: _pullRefreshKey,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: ProductStrip(
                        title: 'Today Deals',
                        products: dealList,
                        onProductTap: (p) {
                          Navigator.of(context).pushNamed(
                            AppRoutes.product,
                            arguments: _toProductItem(p, 0),
                          );
                        },
                        onRightIconTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.todayDeals);
                        },
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                      child: Column(
                        children: promo
                            .map(
                              (b) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: PromoBannerImage(imageUrl: b.image),
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
                                Navigator.of(context).pushNamed(
                                  AppRoutes.product,
                                  arguments: _toProductItem(p, s.products.indexOf(p)),
                                );
                              },
                              onRightIconTap: () {
                                Navigator.of(context).pushNamed(
                                  AppRoutes.searchResults,
                                  arguments: s.name,
                                );
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


