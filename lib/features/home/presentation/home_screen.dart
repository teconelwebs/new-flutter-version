import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:welfog_flutter_play/welfog_flutter_play.dart' as play;
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/check_app_update.dart';
import '../../../core/utils/safe_insets.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/no_internet_widget.dart';
import '../../../core/widgets/view_cart_banner.dart';

import 'package:app_links/app_links.dart';
import '../../account/presentation/account_screen.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/deeplink/deep_link_service.dart';
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
// TEMP: Chat AI hidden — uncomment to re-enable.
// import '../../chat_ai/presentation/chat_ai_screen.dart';
import 'widgets/home_widgets.dart';
import 'widgets/custom_bottom_tab_bar.dart';
import 'widgets/header.dart';
import 'widgets/category_widget.dart';
import 'widgets/banner_widget.dart';
import 'widgets/category_promotion_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialTab});

  final int? initialTab;
  static const routeName = AppRoutes.home;

  static State<HomeScreen>? activeState;

  static void playReel(String reelId) {
    final state = activeState;
    if (state is _HomeScreenState) {
      state.playReel(reelId);
    }
  }

  static void goBackTab() {
    final state = activeState;
    if (state is _HomeScreenState) {
      state.goBackTab();
    }
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  int _currentIndex = 0;
  int _previousIndex = 0;
  // True while a screen (e.g. product details) is pushed on top of Home.
  // Plain Timer.periodic loops (unlike AnimationController tickers) keep
  // firing even while a route is covered/offstage, so this flag is used to
  // explicitly pause Home's background timers/animations until the user
  // comes back — avoiding a rebuild/paint burst on the final "back to Home".
  bool _routeCovered = false;
  String _shareReelId = '';
  final HomeApiService _homeApi = HomeApiService();
  late Future<HomeBundle> _bundleFuture;
  String? _loadedPincode;
  String? _displayCity;
  String? _displayPincode;
  // TEMP: Chat AI hidden — uncomment with FAB/overlay.
  // double? _aiX;
  // double? _aiY;

  void playReel(String reelId) {
    if (mounted) {
      setState(() {
        _shareReelId = reelId;
        _currentIndex = 2; // Switch to Play/Reels tab
      });
      _updateStatusBarColor();
    }
  }

  void goBackTab() {
    if (mounted) {
      setState(() {
        _currentIndex = _previousIndex;
      });
      _updateStatusBarColor();
    }
  }

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
  // TEMP: Chat AI hidden — uncomment with FAB/overlay.
  // bool _aiChatVisible = false;
  // bool _aiChatMounted = false;

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
    HomeScreen.activeState = this;
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
        // Trigger a background refresh to fetch fresh API promotions & categories
        _fetchBundleWithPincodeTracking().then((fresh) {
          if (mounted) {
            setState(() {
              _bundleFuture = Future.value(fresh);
            });
          }
        }).catchError((_) {});
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
    _syncPlayUserIdInBackground();
    _listenToNativeFlutterEvents();
    _updateStatusBarColor();

    // Notification deep-links are routed via appNavigatorKey once Home is ready.
    PushNotificationService.instance.markHomeReady();
    PushNotificationService.instance.flushPendingNavigation();
    PushNotificationService.instance.refreshInitialMessage();
    PushNotificationService.instance.requestPermissions();

    play.customClosePlayCallback = () {
      if (mounted) {
        setState(() {
          _currentIndex = _previousIndex == 2 ? 0 : _previousIndex;
        });
        _updateStatusBarColor();
      }
    };

    // Trigger app update check after a small delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        checkAppUpdate(context);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      play.appRouteObserver.subscribe(this, route);
    }
  }

  void _runAfterTransition(VoidCallback callback) {
    if (!mounted) return;
    final animation = ModalRoute.of(context)?.secondaryAnimation;

    // Guard: wait if animation is actively running OR if value > 0 (home is
    // still "receded" behind a child route). The isAnimating-only check has a
    // timing window — on fast devices didPopNext can fire before isAnimating
    // flips to true, causing carousels to restart mid-transition.
    if (animation != null && (animation.isAnimating || animation.value > 0.0)) {
      late AnimationStatusListener listener;
      listener = (AnimationStatus status) {
        if (status == AnimationStatus.dismissed) {
          // Pop complete — home fully visible again.
          animation.removeStatusListener(listener);
          if (mounted) callback();
        } else if (status == AnimationStatus.completed) {
          // User cancelled gesture — clean up; didPopNext re-registers on next pop.
          animation.removeStatusListener(listener);
        }
      };
      animation.addStatusListener(listener);
      return;
    }
    callback();
  }

  @override
  void didPushNext() {
    if (mounted && !_routeCovered) {
      setState(() => _routeCovered = true);
    }
  }

  @override
  void didPopNext() {
    if (mounted && _routeCovered) {
      _runAfterTransition(() {
        if (mounted) {
          setState(() => _routeCovered = false);
        }
      });
    }
  }

  @override
  void dispose() {
    if (HomeScreen.activeState == this) {
      HomeScreen.activeState = null;
    }
    play.appRouteObserver.unsubscribe(this);
    play.customClosePlayCallback = null;
    // Keep homeReady true during brief rebuilds; routing no longer depends on it.
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
        // Keep nav bar transparent so edge-to-edge insets stay correct on Android.
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
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

    // 2. Handle initial link if app was launched from cold state.
    // Wrapped in addPostFrameCallback so the Navigator is fully mounted
    // before we attempt pushNamed — without this, pushRoute actions silently
    // fail on cold-start while playReel (which uses setState) appears to
    // "work", causing all cold-start links to land on the Play tab.
    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _handleUriRouting(initialUri);
        });
      }
    } catch (e) {
      debugPrint('DeepLink Initial Link Error: $e');
    }
  }

  Uri? _pendingDeepLinkUri;

  void _checkPendingDeepLinkAfterLogin() async {
    final loggedIn = await SessionStore.isLoggedIn();
    if (loggedIn && _pendingDeepLinkUri != null) {
      final uri = _pendingDeepLinkUri!;
      _pendingDeepLinkUri = null;
      debugPrint('DeepLink: User successfully logged in, executing pending link: $uri');
      await _checkGuestStatus(); // Ensure _isGuest and status are updated
      _handleUriRouting(uri);
    } else {
      _pendingDeepLinkUri = null;
    }
  }

  void _handleUriRouting(Uri uri) async {
    debugPrint('DeepLink: Received $uri, segments: ${uri.pathSegments}');

    final resolution = DeepLinkService.resolve(uri);

    // Auth Guard check: if user is logged out, redirect to LoginScreen
    // unless the link is Home page (tab != 4), Product details, or Shop.
    final loggedIn = await SessionStore.isLoggedIn();
    if (!loggedIn) {
      bool isWhitelisted = false;
      if (resolution.routeName == AppRoutes.product) {
        isWhitelisted = true;
      } else if (resolution.routeName == AppRoutes.shop) {
        isWhitelisted = true;
      } else if (resolution.routeName == AppRoutes.home) {
        final args = resolution.arguments;
        final tabIndex = (args is Map && args['tab'] is int) ? args['tab'] as int : 0;
        if (tabIndex != 4) {
          isWhitelisted = true;
        }
      }

      if (!isWhitelisted) {
        debugPrint('DeepLink: User is logged out, saving pending link and redirecting to login page: $uri');
        _pendingDeepLinkUri = uri;
        if (mounted) {
          Navigator.of(context).pushNamed(AppRoutes.login).then((_) {
            _checkPendingDeepLinkAfterLogin();
          });
        }
        return;
      }
    }

    switch (resolution.action) {
      case DeepLinkAction.none:
        debugPrint('DeepLink: No matching in-app destination for $uri');
        return;

      case DeepLinkAction.playReel:
        final reelId = resolution.reelId ?? '';
        if (reelId.isEmpty) return;
        // Preserves the exact existing product-share dedupe behaviour —
        // untouched from before this refactor.
        debugPrint('DeepLink: Parsed play reel ID: $reelId');
        if (mounted) {
          setState(() {
            _shareReelId = reelId;
            _currentIndex = 2; // Switch to Play tab
          });
          _updateStatusBarColor();
        }
        return;

      case DeepLinkAction.pushRoute:
        final routeName = resolution.routeName;
        if (routeName == null) return;

        // Product route keeps its original, dedicated dedupe checks
        // (ProductScreen.currentlyVisibleSlug + AppRouter.shouldIgnoreSlug)
        // exactly as before this refactor — untouched.
        if (routeName == AppRoutes.product) {
          final slug = resolution.arguments as String?;
          if (slug == null || slug.isEmpty) return;
          if (slug == ProductScreen.currentlyVisibleSlug) {
            debugPrint(
                'DeepLink: ProductScreen for slug $slug is already visible, skipping push.');
            return;
          }
          if (AppRouter.shouldIgnoreSlug(slug)) {
            debugPrint('DeepLink: Skip duplicate push for slug: $slug');
            return;
          }
          if (!mounted) return;
          Navigator.of(context).pushNamed(routeName, arguments: slug);
          return;
        }

        // Home (either "https://www.welfog.com/" or "/dashboard") — this
        // listener already lives inside HomeScreen, so no pushNamed needed.
        // Always switch to tab 0 (Home). If a ?tab= argument was passed,
        // switch to that specific tab instead.
        if (routeName == AppRoutes.home) {
          final args = resolution.arguments;
          final tabIndex = (args is Map && args['tab'] is int)
              ? args['tab'] as int
              : 0; // default: Home tab
          debugPrint('DeepLink: Switching to tab $tabIndex from home/dashboard link.');
          if (mounted) {
            setState(() {
              if (_currentIndex != 2) _previousIndex = _currentIndex;
              _currentIndex = tabIndex;
            });
            _updateStatusBarColor();
          }
          return;
        }

        // All other new website-link routes share one generalized
        // duplicate-push guard (see DeepLinkService.shouldIgnore).
        if (DeepLinkService.shouldIgnore(resolution)) {
          debugPrint('DeepLink: Skip duplicate push for $routeName');
          return;
        }
        if (!mounted) return;
        Navigator.of(context)
            .pushNamed(routeName, arguments: resolution.arguments);
        return;
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

  /// Backfill play profile userid (random UUID → shop user_id) via Play API.
  Future<void> _syncPlayUserIdInBackground() async {
    try {
      await play.PlayProfileHelper.syncShopUserIdViaUpdateApi();
    } catch (e) {
      debugPrint("Play userid sync skipped/failed: $e");
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
    final isNameSaved = localName.isNotEmpty &&
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
            final city = addressData['city']?.toString() ??
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
    final bottomInset = systemBottomInset(context);
    final bottomPadding = bottomInset > 0 ? bottomInset + 8 : 20.0;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Stack(
        children: [
          Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // TEMP Chat AI position math (unused while AI FAB is commented):
          // final double maxWidth = constraints.maxWidth;
          // final double maxHeight = constraints.maxHeight;
          // const double buttonSize = 56.0;
          // const double padding = 16.0;
          // final double defaultX = maxWidth - buttonSize - padding;
          // final double defaultY = maxHeight - buttonSize - (bottomPadding + 52);
          // final double clampedX = (_aiX ?? defaultX).clamp(0.0, maxWidth - buttonSize);
          // final double clampedY = (_aiY ?? defaultY).clamp(0.0, maxHeight - buttonSize);

          return Stack(
            children: [
              // Dynamic tab content
              IndexedStack(
                index: _currentIndex,
                children: [
                  RepaintBoundary(
                    child: _HomeTab(
                    bundleFuture: _bundleFuture,
                    displayCity: _displayCity,
                    displayPincode: _displayPincode,
                    isActive: _currentIndex == 0 && !_routeCovered,
                    onLocationTap: () {
                      if (_isGuest) {
                        Navigator.of(context).pushNamed(AppRoutes.login).then((_) {
                          _runAfterTransition(() {
                            _checkGuestStatus();
                          });
                        });
                        return;
                      }
                      Navigator.of(context).pushNamed(AppRoutes.address).then((
                        _,
                      ) async {
                        _runAfterTransition(() async {
                          await _loadActiveAddressFromPrefs();
                          // Only refetch the whole home bundle when the pincode
                          // actually changed — same guard used on tab-switch —
                          // otherwise every back-from-address hits the API again.
                          final prefs = await SharedPreferences.getInstance();
                          final savedPincode =
                              prefs.getString('postal_code') ?? '302001';
                          if (savedPincode != _loadedPincode) {
                            setState(() {
                              _bundleFuture = _fetchBundleWithPincodeTracking();
                            });
                          }
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
                        _runAfterTransition(() {
                          _checkGuestStatus();
                        });
                      });
                    },
                    onTabChange: (index) async {
                      setState(() {
                        if (_currentIndex != 2) {
                          _previousIndex = _currentIndex;
                        }
                        _currentIndex = index;
                        if (index != 2) {
                          _shareReelId =
                              ''; // Clear shared reel ID when leaving play tab
                        }
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
                  ),
                  const RepaintBoundary(child: CategoryScreen(embedded: true)),
                  RepaintBoundary(
                    child: play.EmbeddedReelsWrapper(
                      key: ValueKey('play_session_${_userId}_$_shareReelId'),
                      viewerId: _userId,
                      isActive: _currentIndex == 2,
                      initialReelId: _shareReelId,
                    ),
                  ),
                  const RepaintBoundary(child: CartScreen(embedded: true)),
                  RepaintBoundary(
                    child: AccountScreen(embedded: true, active: _currentIndex == 4),
                  ),
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
              // TEMP: Floating AI Chat Button — uncomment to re-enable.
              // if (_currentIndex != 2 && !_aiChatVisible)
              //   Positioned(
              //     left: clampedX,
              //     top: clampedY,
              //     child: GestureDetector(
              //       onPanUpdate: (details) {
              //         setState(() {
              //           _aiX = (clampedX + details.delta.dx).clamp(0.0, maxWidth - buttonSize);
              //           _aiY = (clampedY + details.delta.dy).clamp(0.0, maxHeight - buttonSize);
              //         });
              //       },
              //       onTap: () {
              //         if (_isGuest) {
              //           Navigator.of(context).pushNamed(AppRoutes.login).then((_) {
              //             _checkGuestStatus();
              //           });
              //           return;
              //         }
              //         setState(() {
              //           _aiChatMounted = true;
              //           _aiChatVisible = true;
              //         });
              //       },
              //       child: Container(
              //         width: buttonSize,
              //         height: buttonSize,
              //         decoration: BoxDecoration(
              //           gradient: const LinearGradient(
              //             colors: [Color(0xFFFF5404), Color(0xFFFF8500)],
              //             begin: Alignment.topLeft,
              //             end: Alignment.bottomRight,
              //           ),
              //           shape: BoxShape.circle,
              //           boxShadow: [
              //             BoxShadow(
              //               // ignore: deprecated_member_use
              //               color: const Color(0xFFFF5404).withOpacity(0.35),
              //               blurRadius: 14,
              //               offset: const Offset(0, 6),
              //             ),
              //           ],
              //         ),
              //         child: Stack(
              //           alignment: Alignment.center,
              //           children: [
              //             const Icon(
              //               Icons.chat_bubble_rounded,
              //               color: Colors.white,
              //               size: 26,
              //             ),
              //             Positioned(
              //               top: 10,
              //               right: 8,
              //               child: Container(
              //                 padding: const EdgeInsets.symmetric(
              //                   horizontal: 4,
              //                   vertical: 1,
              //                 ),
              //                 decoration: BoxDecoration(
              //                   color: Colors.white,
              //                   borderRadius: BorderRadius.circular(6),
              //                   boxShadow: [
              //                     BoxShadow(
              //                       // ignore: deprecated_member_use
              //                       color: Colors.black.withOpacity(0.1),
              //                       blurRadius: 2,
              //                       offset: const Offset(0, 1),
              //                     ),
              //                   ],
              //                 ),
              //                 child: const Text(
              //                   'AI',
              //                   style: TextStyle(
              //                     color: Color(0xFFFF5404),
              //                     fontSize: 8,
              //                     fontWeight: FontWeight.w900,
              //                   ),
              //                 ),
              //               ),
              //             ),
              //           ],
              //         ),
              //       ),
              //     ),
              //   ),
              if (_currentIndex != 2 && _currentIndex != 3)
                ValueListenableBuilder<int>(
                  valueListenable: CartState.cartCountNotifier,
                  builder: (context, cartCount, _) {
                    if (cartCount <= 0) return const SizedBox.shrink();
                    return Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8.0,
                      child: ViewCartBanner(
                        onTap: () {
                          setState(() {
                            if (_currentIndex != 2) {
                              _previousIndex = _currentIndex;
                            }
                            _currentIndex = 3;
                          });
                          _updateStatusBarColor();
                          CartScreen.emitRefreshTabAction();
                        },
                      ),
                    );
                  },
                ),
            ],
          );
        },
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
                      if (_currentIndex != 2) {
                        _previousIndex = _currentIndex;
                      }
                      _currentIndex = index;
                    });
                    _updateStatusBarColor();
                    if (index == 3) {
                      CartScreen.emitRefreshTabAction();
                    }
                    if (index == 0) {
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
                  isGuest: _isGuest,
                  cartCount: cartCount,
                   promptLogin: () {
                    Navigator.of(context).pushNamed(AppRoutes.login).then((_) {
                      _runAfterTransition(() {
                        _checkGuestStatus(); // Check guest status again when returning from Login
                      });
                    });
                  },
                  clearGuestMode: () async {
                    // Clear guest mode status if needed
                  },
                  dismissLoginModal: () {
                    // Dismiss modal if showing
                  },
                  onPlayLoginSuccess: () {
                    _checkGuestStatus(); // Check guest status to refresh play screen visibility
                  },
                );
              },
            ),
          ),
          // TEMP: Full-screen AI overlay — uncomment to re-enable.
          // if (_aiChatMounted && !_isGuest)
          //   Positioned.fill(
          //     child: Offstage(
          //       offstage: !_aiChatVisible,
          //       child: Material(
          //         color: Colors.white,
          //         child: SafeArea(
          //           child: ChatAiScreen(
          //             userId: _userId,
          //             isModal: true,
          //             onClose: () {
          //               setState(() => _aiChatVisible = false);
          //             },
          //           ),
          //         ),
          //       ),
          //     ),
          //   ),
        ],
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
  /// True only when the Home tab is the currently visible tab. Used to pause
  /// background timers/animations (placeholder rotation, category auto-scroll)
  /// while this tab is hidden behind another tab in the IndexedStack.
  final bool isActive;

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
    this.isActive = true,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  late ScrollController _scrollController;
  final int _pullRefreshKey = 0;
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

  void _runAfterTransition(VoidCallback callback) {
    if (!mounted) return;
    final animation = ModalRoute.of(context)?.secondaryAnimation;

    if (animation != null && (animation.isAnimating || animation.value > 0.0)) {
      late AnimationStatusListener listener;
      listener = (AnimationStatus status) {
        if (status == AnimationStatus.dismissed) {
          animation.removeStatusListener(listener);
          if (mounted) callback();
        } else if (status == AnimationStatus.completed) {
          animation.removeStatusListener(listener);
        }
      };
      animation.addStatusListener(listener);
      return;
    }
    callback();
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
      videoUrl: p.videoUrl,
      videoLink: p.videoLink,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeBundle>(
      future: widget.bundleFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snap.hasError || !snap.hasData) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: true,
              title: const Text(
                'Welfog',
                style: TextStyle(
                  color: Color(0xFFFB5404),
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            body: NoInternetWidget(
              onRetry: widget.onRefresh,
              title: 'No Internet Connection',
              message: 'Failed to load home data. Check your connection.',
            ),
          );
        }

        final bundle = snap.data!;
        final dealList = bundle.todayDeals.take(10).toList();
        final sections = bundle.sections;

        return Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.top + 140,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: CategoryWidget(
                        pullRefreshKey: _pullRefreshKey,
                        onTabChange: widget.onTabChange,
                        isActive: widget.isActive,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: BannerWidget(
                        slides: bundle.mobileSlider,
                        isActive: widget.isActive,
                      ),
                    ),
                  ),
                  if (_recentProducts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: RepaintBoundary(
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
                                  .then((_) => _runAfterTransition(() => _loadRecentlyViewed()));
                            },
                            onRightIconTap: () {
                              Navigator.of(context)
                                  .pushNamed(AppRoutes.recentlyViewed)
                                  .then((_) => _runAfterTransition(() => _loadRecentlyViewed()));
                            },
                          ),
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
                                  child: PromoBannerImage(imageUrl: b.image),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: TrustStrip()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: RepaintBoundary(
                        child: ProductStrip(
                          title: 'Today Deals',
                          titleIcon: SvgPicture.string(
                            '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="#FB5404" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"></path><line x1="7" y1="7" x2="7.01" y2="7"></line></svg>''',
                          ),
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
                                .then((_) => _runAfterTransition(() => _loadRecentlyViewed()));
                          },
                          onRightIconTap: () {
                            Navigator.of(context)
                                .pushNamed(AppRoutes.todayDeals)
                                .then((_) => _runAfterTransition(() => _loadRecentlyViewed()));
                          },
                        ),
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
                                  child: PromoBannerImage(imageUrl: b.image),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  // Lazy-built per section (was an eager .map spread) — with many
                  // categories, eagerly building every section meant every
                  // BannerCarousel's animation ran simultaneously even when
                  // scrolled far off-screen, causing raster jank. Now a section
                  // (and its carousel) only mounts once it's near the viewport.
                  SliverList.builder(
                    itemCount: sections.length,
                    itemBuilder: (context, index) {
                      final s = sections[index];
                      return RepaintBoundary(
                        child: Column(
                          children: [
                            if (s.products.isNotEmpty)
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
                                        .then((_) => _runAfterTransition(() => _loadRecentlyViewed()));
                                  },
                                  onRightIconTap: () {
                                    Navigator.of(context).pushNamed(
                                      AppRoutes.searchResults,
                                      arguments: {
                                        'query': s.name,
                                        'categoryId': s.id,
                                      },
                                    ).then((_) => _runAfterTransition(() => _loadRecentlyViewed()));
                                  },
                                ),
                              ),
                            if (s.bannerData.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: BannerCarousel(
                                  items: s.bannerData,
                                  isActive: widget.isActive,
                                ),
                              ),
                            CategoryPromotionWidget(
                              categoryId: s.id,
                              isActive: widget.isActive,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            Header(
              isHome: true,
              scrollController: _scrollController,
              city: widget.displayCity ?? bundle.city,
              pincode: widget.displayPincode ?? bundle.pincode,
              isGuest: widget.isGuest,
              isActive: widget.isActive,
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

      // Bootstrap Play profile with display name + login userid only.
      // Real Play username is chosen later in the Play setup sheet.
      await play.PlayProfileHelper.bootstrapAfterNameSave(name: name);

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
