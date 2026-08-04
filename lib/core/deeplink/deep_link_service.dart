import 'package:flutter/foundation.dart';

import '../constants/app_routes.dart';

/// What the app should do with a resolved deep link.
enum DeepLinkAction { pushRoute, playReel, none }

/// Pure result of resolving an incoming [Uri] (from https://www.welfog.com/...,
/// welfog://..., or api.welfog.com/products/...) to an in-app destination.
///
/// This is a plain data object — no BuildContext/Navigator/setState here —
/// so [DeepLinkService.resolve] stays independently testable. The caller
/// (currently HomeScreen) is responsible for performing the actual
/// navigation/tab-switch side effects.
@immutable
class DeepLinkResolution {
  final DeepLinkAction action;
  final String? routeName;
  final Object? arguments;
  final String? reelId;

  const DeepLinkResolution._({
    required this.action,
    this.routeName,
    this.arguments,
    this.reelId,
  });

  factory DeepLinkResolution.route(String routeName, {Object? arguments}) =>
      DeepLinkResolution._(
        action: DeepLinkAction.pushRoute,
        routeName: routeName,
        arguments: arguments,
      );

  factory DeepLinkResolution.playReel(String reelId) => DeepLinkResolution._(
        action: DeepLinkAction.playReel,
        reelId: reelId,
      );

  static const DeepLinkResolution none =
      DeepLinkResolution._(action: DeepLinkAction.none);

  /// Stable identity used for duplicate-push suppression.
  String get dedupeKey {
    switch (action) {
      case DeepLinkAction.pushRoute:
        return 'route:$routeName:${arguments ?? ''}';
      case DeepLinkAction.playReel:
        return 'playReel:$reelId';
      case DeepLinkAction.none:
        return 'none';
    }
  }
}

/// Resolves incoming deep-link URLs (App Links on Android / Universal Links
/// on iOS once configured, plus the custom `welfog://` scheme) to an in-app
/// route + arguments.
///
/// NOTE (iOS): Universal Links won't actually reach this resolver on iOS
/// until the `com.apple.developer.associated-domains` entitlement and a
/// hosted `apple-app-site-association` file are added (currently missing —
/// see ios/Runner/Runner.entitlements). That is a separate, native-config
/// task; this file only covers the Dart-side URL -> route mapping, which
/// applies equally to both platforms once the native prerequisite is done.
class DeepLinkService {
  DeepLinkService._();

  static DeepLinkResolution resolve(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    if (segments.isEmpty) {
      // https://www.welfog.com/ — nothing to navigate to, caller is already
      // expected to be on/near Home.
      return DeepLinkResolution.route(AppRoutes.home);
    }

    // ---- Existing patterns (unchanged behaviour) --------------------------

    // Product share links: .../products/{slug}
    final productsIdx = segments.indexOf('products');
    if (productsIdx != -1 && segments.length > productsIdx + 1) {
      final slug = segments[productsIdx + 1].trim();
      if (slug.isNotEmpty) {
        return DeepLinkResolution.route(AppRoutes.product, arguments: slug);
      }
    }

    // Play/Video share links:
    // Pattern 1: /plays/r/{reelId}-{shareUserId}
    // Pattern 2: /plays/dl/reel/{reelId}/user/{shareUserId}
    // Pattern 3: /sepreel/{reelId}
    final playReelIdx = segments.indexOf('r');
    if (playReelIdx != -1 &&
        playReelIdx > 0 &&
        segments[playReelIdx - 1] == 'plays' &&
        segments.length > playReelIdx + 1) {
      final slug = segments[playReelIdx + 1];
      final match =
          RegExp(r'^([0-9a-fA-F]{24})-([a-zA-Z0-9]+)$').firstMatch(slug);
      final reelId = match?.group(1) ?? '';
      if (reelId.isNotEmpty) return DeepLinkResolution.playReel(reelId);
    } else if (segments.contains('plays') &&
        segments.contains('dl') &&
        segments.contains('reel')) {
      final reelIdx = segments.indexOf('reel');
      if (reelIdx != -1 && segments.length > reelIdx + 1) {
        final reelId = segments[reelIdx + 1];
        if (reelId.isNotEmpty) return DeepLinkResolution.playReel(reelId);
      }
    } else if (segments.contains('sepreel')) {
      final sepIdx = segments.indexOf('sepreel');
      if (sepIdx != -1 && segments.length > sepIdx + 1) {
        final reelId = segments[sepIdx + 1];
        if (reelId.isNotEmpty) return DeepLinkResolution.playReel(reelId);
      }
    }

    // ---- New website link patterns ----------------------------------------

    switch (segments.first) {
      case 'product_details':
        // /product_details/{id}/{slug}
        if (segments.length >= 3) {
          final slug = segments[2].trim();
          if (slug.isNotEmpty) {
            return DeepLinkResolution.route(AppRoutes.product,
                arguments: slug);
          }
        }
        break;

      case 'shop':
        // /shop/{slug}?id={id}
        if (segments.length >= 2) {
          final slug = segments[1];
          final shopId = uri.queryParameters['id'] ?? '';
          return DeepLinkResolution.route(
            AppRoutes.shop,
            arguments: {'slug': slug, 'shop_id': shopId},
          );
        }
        break;

      case 'search':
        // /search?keyword={text}
        final keyword = uri.queryParameters['keyword'] ?? '';
        return DeepLinkResolution.route(
          AppRoutes.searchResults,
          arguments: {'query': keyword},
        );

      case 'cart':
        return DeepLinkResolution.route(AppRoutes.cart);

      case 'checkout':
        // /checkout?=delivery_address
        return DeepLinkResolution.route(AppRoutes.confirmAddress);

      case 'process_to_payment':
        // /process_to_payment?make_payment
        return DeepLinkResolution.route(AppRoutes.paymentConfirmation);

      case 'dashboard':
        // /dashboard?tab=profile → switch to account tab (index 4)
        // /dashboard?tab=play    → switch to play tab   (index 2)
        // /dashboard?tab=home    → switch to home tab   (index 0)
        // /dashboard             → switch to account tab (index 4)
        final tab = uri.queryParameters['tab'] ?? 'profile';
        switch (tab) {
          case 'play':
            return DeepLinkResolution.route(AppRoutes.home,
                arguments: {'tab': 2});
          case 'home':
            return DeepLinkResolution.route(AppRoutes.home,
                arguments: {'tab': 0});
          case 'profile':
          default:
            return DeepLinkResolution.route(AppRoutes.home,
                arguments: {'tab': 4});
        }

      case 'account':
        if (segments.length >= 2) {
          switch (segments[1]) {
            case 'orders':
              return DeepLinkResolution.route(AppRoutes.orders);
            case 'order_details':
              final id = uri.queryParameters['id'] ?? '';
              return DeepLinkResolution.route(
                AppRoutes.orderDetails,
                arguments: {'oid': id},
              );
            case 'addresses':
              return DeepLinkResolution.route(AppRoutes.address);
            case 'wishlist':
              return DeepLinkResolution.route(AppRoutes.wishlist);
          }
        }
        break;

      case 'help':
        return DeepLinkResolution.route(AppRoutes.helpCenter);

      case 'faqs':
        return DeepLinkResolution.route(AppRoutes.faq);

      case 'track_order':
        return DeepLinkResolution.route(AppRoutes.trackOrder);

      case 'contact':
        return DeepLinkResolution.route(AppRoutes.contactSupport);

      case 'about':
        // No matching in-app screen exists for this one — intentionally
        // resolve to none instead of forcing it into an unrelated screen.
        return DeepLinkResolution.none;

      case 'page':
        // /page/{slug} — terms-and-conditions, privacy-policy,
        // anti-phishing-defense-policy, etc.
        if (segments.length >= 2) {
          return DeepLinkResolution.route(AppRoutes.policy,
              arguments: segments[1]);
        }
        break;

      case 'notifications':
        return DeepLinkResolution.route(AppRoutes.notifications);
    }

    return DeepLinkResolution.none;
  }

  // ---- Generalized duplicate-push suppression -----------------------------
  //
  // Mirrors AppRouter.shouldIgnoreSlug()'s 2-second-window approach, but
  // keyed by the resolved destination instead of a raw product slug, so it
  // covers every route above without touching that existing mechanism
  // (which stays dedicated to the product-slug case it was written for).
  static String? _lastKey;
  static DateTime? _lastKeyTime;

  static bool shouldIgnore(DeepLinkResolution resolution) {
    if (resolution.action == DeepLinkAction.none) return true;
    final key = resolution.dedupeKey;
    final now = DateTime.now();
    if (_lastKey == key &&
        _lastKeyTime != null &&
        now.difference(_lastKeyTime!) < const Duration(seconds: 2)) {
      return true;
    }
    _lastKey = key;
    _lastKeyTime = now;
    return false;
  }
}
