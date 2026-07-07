import 'package:flutter/material.dart';
import 'package:welfog_flutter_play/welfog_flutter_play.dart' as play;

import '../../features/address/presentation/address_screen.dart';
import '../../features/address/presentation/location_picker_screen.dart';
import '../../features/address/presentation/add_address_details_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/home/presentation/home_screen.dart';
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
import '../constants/app_routes.dart';


class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
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
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const HomeScreen(),
        );
      case AppRoutes.search:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const SearchScreen(),
        );
      case AppRoutes.searchResults:
        final query = (settings.arguments as String?) ?? '';
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => SearchResultsScreen(query: query),
        );
      case AppRoutes.cart:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const CartScreen(),
        );
      case AppRoutes.product:
        final item = settings.arguments as ProductItem?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ProductScreen(item: item),
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
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const OrdersScreen(),
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
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => TrackOrderScreen(
            oid: args['oid']?.toString() ?? '',
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
      default:
        return play.AppRoutes.onGenerateRoute(settings);
    }
  }
}

