import 'package:flutter/material.dart';
import 'package:welfog_flutter_play/welfog_flutter_play.dart' as play;

import '../../features/address/presentation/address_screen.dart';
import '../../features/address/presentation/location_picker_screen.dart';
import '../../features/address/presentation/add_address_details_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/today_deals_screen.dart';
import '../../features/home/presentation/dynamic_promotion_screen.dart';
import '../../features/login/presentation/login_screen.dart';
import '../../features/product/data/models/product_item.dart';
import '../../features/product/presentation/product_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/search/presentation/search_results_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/checkout/presentation/confirm_address_screen.dart';
import '../../features/checkout/presentation/payment_confirmation_screen.dart';
import '../../features/checkout/presentation/order_success_screen.dart';
import '../../features/profile/presentation/orders_screen.dart';
import '../../features/profile/presentation/order_details_screen.dart';
import '../../features/profile/presentation/track_order_screen.dart';
import '../../features/profile/presentation/notifications_screen.dart';
import '../../features/account/presentation/settings_screen.dart';
import '../../features/account/presentation/blocked_users_screen.dart';
import '../../features/account/presentation/delete_account_help_screen.dart';
import '../../features/account/presentation/delete_account_reason_screen.dart';
import '../../features/account/presentation/account_deleted_screen.dart';
import '../../features/account/presentation/wishlist_screen.dart';
import '../../features/account/presentation/help_center_screen.dart';
import '../../features/account/presentation/faq_screen.dart';
import '../../features/account/presentation/contact_support_screen.dart';
import '../../features/account/presentation/become_supplier_screen.dart';
import '../../features/account/presentation/policy_screen.dart';
import '../../features/account/presentation/supplier_info_screen.dart';
import '../../features/account/presentation/connect_supplier_screen.dart';
import '../../features/product/presentation/recently_viewed_screen.dart';
import '../constants/app_routes.dart';
import '../../features/shop/presentation/shop_screen.dart';
import '../../features/chat_ai/presentation/chat_ai_screen.dart';


class AppRouter {
  static String? lastResolvedSlug;
  static String? lastHandledSlug;
  static DateTime? lastHandledSlugTime;

  static bool shouldIgnoreSlug(String slug) {
    final now = DateTime.now();
    if (lastHandledSlug == slug &&
        lastHandledSlugTime != null &&
        now.difference(lastHandledSlugTime!) < const Duration(seconds: 2)) {
      return true;
    }
    lastHandledSlug = slug;
    lastHandledSlugTime = now;
    return false;
  }

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? '';
    final normalizedName = (name.startsWith('http') || name.startsWith('welfog://'))
        ? name
        : (name.startsWith('/') ? name : '/$name');
    final uri = Uri.tryParse(normalizedName);
    if (uri != null) {
      final segments = uri.pathSegments;
      final productsIdx = segments.indexOf('products');
      if (productsIdx != -1 && segments.length > productsIdx + 1) {
        final slug = segments[productsIdx + 1];
        if (slug.isNotEmpty) {
          final trimmed = slug.trim();
          if (trimmed == ProductScreen.currentlyVisibleSlug) {
            debugPrint('DeepLink Router: Slug $trimmed is already visible, ignoring push.');
            return null;
          }
          if (shouldIgnoreSlug(trimmed)) {
            debugPrint('DeepLink Router: Skip duplicate push for slug: $trimmed');
            return null;
          }
          lastResolvedSlug = trimmed;
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => ProductScreen(slug: trimmed),
          );
        }
      }
    }

    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const SplashScreen(),
        );
      case AppRoutes.login:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const LoginScreen(),
        );
      case AppRoutes.address:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AddressScreen(),
        );
      case AppRoutes.home:
        final initialTab = settings.arguments as int?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => HomeScreen(initialTab: initialTab),
        );
      case AppRoutes.todayDeals:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const TodayDealsScreen(),
        );
      case AppRoutes.search:
        final initialQuery = settings.arguments as String?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => SearchScreen(initialQuery: initialQuery),
        );
      case AppRoutes.searchResults:
        final args = settings.arguments;
        String query = '';
        String? categoryId;
        if (args is Map<String, dynamic>) {
          query = args['query']?.toString() ?? '';
          categoryId = args['categoryId']?.toString();
        } else if (args is String) {
          query = args;
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => SearchResultsScreen(query: query, categoryId: categoryId),
        );
      case AppRoutes.cart:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const CartScreen(),
        );
      case AppRoutes.product:
        final args = settings.arguments;
        ProductItem? item;
        String? slug;
        if (args is ProductItem) {
          item = args;
        } else if (args is String) {
          slug = args;
        } else if (args is Map<String, dynamic>) {
          item = args['item'] as ProductItem?;
          slug = args['slug'] as String?;
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ProductScreen(item: item, slug: slug),
        );
      case AppRoutes.profile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ProfileScreen(),
        );
      case AppRoutes.confirmAddress:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ConfirmAddressScreen(),
        );
      case AppRoutes.paymentConfirmation:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const PaymentConfirmationScreen(),
        );
      case AppRoutes.orderSuccess:
        final orderId = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => OrderSuccessScreen(orderId: orderId),
        );
      case AppRoutes.locationPicker:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final forceGPS = args['forceGPS'] as bool? ?? false;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => LocationPickerScreen(forceGPS: forceGPS),
        );
      case AppRoutes.editLocation:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => LocationPickerScreen(
            isEdit: true,
            editAddressId: args['id']?.toString() ?? '',
            editLatitude: args['latitude']?.toString() ?? '',
            editLongitude: args['longitude']?.toString() ?? '',
            editName: args['name']?.toString() ?? '',
            editPhone: args['phone']?.toString() ?? '',
            editAddressDetails: args['addressDetails']?.toString() ?? '',
          ),
        );
      case AppRoutes.orders:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final fromNotification = args['fromNotification'] as bool? ?? false;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => OrdersScreen(fromNotification: fromNotification),
        );
      case AppRoutes.notifications:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const NotificationsScreen(),
        );
      case AppRoutes.orderDetails:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => OrderDetailsScreen(
            oid: args['oid']?.toString() ?? '',
            initialRefundStatus: args['initialRefundStatus']?.toString(),
          ),
        );
      case AppRoutes.trackOrder:
        final args = settings.arguments is Map ? settings.arguments as Map : {};
        final oid = args['oid']?.toString() ?? '';
        final orderMap = args['order'] is Map
            ? Map<String, dynamic>.from(args['order'] as Map)
            : null;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => TrackOrderScreen(
            oid: oid,
            initialOrder: orderMap,
          ),
        );
      case AppRoutes.addAddressDetails:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => AddAddressDetailsScreen(
            mode: args['mode']?.toString() ?? 'add',
            editAddressId: args['id']?.toString() ?? '',
            editName: args['name']?.toString() ?? '',
            editPhone: args['phone']?.toString() ?? '',
            editAddressDetails: args['addressDetails']?.toString() ?? '',
            address: args['address']?.toString() ?? '',
            city: args['city']?.toString() ?? '',
            state: args['state']?.toString() ?? '',
            pincode: args['pincode']?.toString() ?? '',
            country: args['country']?.toString() ?? '',
          ),
        );
      case AppRoutes.settings:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const SettingsScreen(),
        );
      case AppRoutes.blockedUsers:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const BlockedUsersScreen(),
        );
      case AppRoutes.deleteAccountHelp:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final phone = args['phone']?.toString() ?? '';
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => DeleteAccountHelpScreen(phone: phone),
        );
      case AppRoutes.deleteAccountReason:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final phone = args['phone']?.toString() ?? '';
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => DeleteAccountReasonScreen(phone: phone),
        );
      case AppRoutes.accountDeleted:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final phone = args['phone']?.toString() ?? '';
        final deletedDate = args['deleted_date']?.toString();
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => AccountDeletedScreen(
            phone: phone,
            deletedDate: deletedDate,
          ),
        );
      case AppRoutes.wishlist:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const WishlistScreen(),
        );
      case AppRoutes.helpCenter:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const HelpCenterScreen(),
        );
      case AppRoutes.faq:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const FaqScreen(),
        );
      case AppRoutes.contactSupport:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ContactSupportScreen(),
        );
      case AppRoutes.becomeSupplier:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const BecomeSupplierScreen(),
        );
      case AppRoutes.supplierInfo:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const SupplierInfoScreen(),
        );
      case AppRoutes.connectSupplier:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ConnectSupplierScreen(),
        );
      case AppRoutes.policy:
        final slug = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => PolicyScreen(slug: slug),
        );
      case AppRoutes.shop:
        final shopArgs = settings.arguments as Map<String, dynamic>? ?? {};
        final shopId = (shopArgs['shop_id'] ?? shopArgs['id'] ?? '').toString();
        final shopSlug = (shopArgs['slug'] ?? '').toString();
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ShopScreen(shopId: shopId, slug: shopSlug),
        );
      case AppRoutes.recentlyViewed:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const RecentlyViewedScreen(),
        );
      case AppRoutes.dynamicPromotion:
        final slug = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => DynamicPromotionScreen(slug: slug),
        );
      case AppRoutes.chatAi:
        final userId = settings.arguments as String?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ChatAiScreen(userId: userId),
        );
      default:
        return play.AppRoutes.onGenerateRoute(settings);
    }
  }
}

