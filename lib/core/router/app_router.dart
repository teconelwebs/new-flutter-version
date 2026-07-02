import 'package:flutter/material.dart';
import 'package:welfog_flutter_play/welfog_flutter_play.dart' as play;

import '../../features/address/presentation/address_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/login/presentation/login_screen.dart';
import '../../features/product/data/models/product_item.dart';
import '../../features/product/presentation/product_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/search/presentation/search_results_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
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
      default:
        return play.AppRoutes.onGenerateRoute(settings);
    }
  }
}
