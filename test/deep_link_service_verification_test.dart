import 'package:flutter_test/flutter_test.dart';
import 'package:welfog/core/deeplink/deep_link_service.dart';
import 'package:welfog/core/constants/app_routes.dart';

void main() {
  test('all provided website links resolve to the expected route', () {
    final cases = <String, Map<String, dynamic>>{
      'https://www.welfog.com/': {
        'action': DeepLinkAction.pushRoute,
        'route': AppRoutes.home,
      },
      'https://www.welfog.com/product_details/26197118/bhagat-singh-photo-frame-home-decor-photo-frame-9x12-inch-photo-frame-bhagat-singh-ki-frame-26197118':
          {
        'action': DeepLinkAction.pushRoute,
        'route': AppRoutes.product,
        'arguments':
            'bhagat-singh-photo-frame-home-decor-photo-frame-9x12-inch-photo-frame-bhagat-singh-ki-frame-26197118',
      },
      'https://www.welfog.com/shop/sharma-enterprises-jpr-1760?id=384': {
        'action': DeepLinkAction.pushRoute,
        'route': AppRoutes.shop,
        'arguments': {'slug': 'sharma-enterprises-jpr-1760', 'shop_id': '384'},
      },
      'https://www.welfog.com/search?keyword=text': {
        'action': DeepLinkAction.pushRoute,
        'route': AppRoutes.searchResults,
        'arguments': {'query': 'text'},
      },
      'https://www.welfog.com/cart': {
        'action': DeepLinkAction.pushRoute,
        'route': AppRoutes.cart,
      },
      'https://www.welfog.com/checkout?=delivery_address': {
        'action': DeepLinkAction.pushRoute,
        'route': AppRoutes.confirmAddress,
      },
      'https://www.welfog.com/process_to_payment?make_payment': {
        'action': DeepLinkAction.pushRoute,
        'route': AppRoutes.paymentConfirmation,
      },
      'https://www.welfog.com/dashboard': {
        'action': DeepLinkAction.pushRoute,
        'route': AppRoutes.home,
        'arguments': {'tab': 4},
      },
      'https://www.welfog.com/account/orders': {
        'action': DeepLinkAction.pushRoute,
        'route': AppRoutes.orders,
      },
      'https://www.welfog.com/account/order_details?id=2608012': {
        'action': DeepLinkAction.pushRoute,
        'route': AppRoutes.orderDetails,
        'arguments': {'oid': '2608012'},
      },
      'https://www.welfog.com/account/addresses': {
        'action': DeepLinkAction.pushRoute,
        'route': AppRoutes.address,
      },
      'https://www.welfog.com/account/wishlist': {
        'action': DeepLinkAction.pushRoute,
        'route': AppRoutes.wishlist,
      },
      'https://www.welfog.com/help': {
        'action': DeepLinkAction.pushRoute,
        'route': AppRoutes.helpCenter,
      },
      'https://www.welfog.com/faqs/': {
        'action': DeepLinkAction.pushRoute,
        'route': AppRoutes.faq,
      },
      'https://www.welfog.com/track_order/': {
        'action': DeepLinkAction.pushRoute,
        'route': AppRoutes.trackOrder,
      },
      'https://www.welfog.com/contact': {
        'action': DeepLinkAction.pushRoute,
        'route': AppRoutes.contactSupport,
      },
      'https://www.welfog.com/about': {
        'action': DeepLinkAction.none,
      },
      'https://www.welfog.com/page/terms-and-conditions': {
        'action': DeepLinkAction.pushRoute,
        'route': AppRoutes.policy,
        'arguments': 'terms-and-conditions',
      },
      'https://www.welfog.com/page/anti-phishing-defense-policy': {
        'action': DeepLinkAction.pushRoute,
        'route': AppRoutes.policy,
        'arguments': 'anti-phishing-defense-policy',
      },
      'https://www.welfog.com/page/privacy-policy': {
        'action': DeepLinkAction.pushRoute,
        'route': AppRoutes.policy,
        'arguments': 'privacy-policy',
      },
      'https://www.welfog.com/notifications': {
        'action': DeepLinkAction.pushRoute,
        'route': AppRoutes.notifications,
      },
    };

    cases.forEach((url, expected) {
      final result = DeepLinkService.resolve(Uri.parse(url));
      // eslint-disable-next-line
      // ignore: avoid_print
      print(
          'URL=$url  =>  action=${result.action} route=${result.routeName} args=${result.arguments}');
      expect(result.action, expected['action'], reason: 'action mismatch for $url');
      if (expected.containsKey('route')) {
        expect(result.routeName, expected['route'], reason: 'route mismatch for $url');
      }
      if (expected.containsKey('arguments')) {
        expect(result.arguments, expected['arguments'], reason: 'arguments mismatch for $url');
      }
    });
  });

  // Existing (pre-refactor) patterns must still behave exactly as before.
  test('existing product-share and play-share patterns are unchanged', () {
    final productResult =
        DeepLinkService.resolve(Uri.parse('https://api.welfog.com/products/some-product-slug'));
    expect(productResult.action, DeepLinkAction.pushRoute);
    expect(productResult.routeName, AppRoutes.product);
    expect(productResult.arguments, 'some-product-slug');

    final playR = DeepLinkService.resolve(
        Uri.parse('https://www.welfog.com/plays/r/6a36555a7751b49fd61dfcc0-abc123'));
    expect(playR.action, DeepLinkAction.playReel);
    expect(playR.reelId, '6a36555a7751b49fd61dfcc0');

    final playDl = DeepLinkService.resolve(
        Uri.parse('https://www.welfog.com/api/plays/dl/reel/665f2a/user/9'));
    expect(playDl.action, DeepLinkAction.playReel);
    expect(playDl.reelId, '665f2a');

    // Matches the actual real-world format used by
    // push_notification_service.dart's nav.pushNamed('/sepreel/$reelId') —
    // a plain path, not a 'welfog://sepreel/...' authority-style URI (Dart's
    // Uri class treats the segment right after '//' as the host, not a
    // path segment, so that shape was never a valid link to begin with).
    final sepreel = DeepLinkService.resolve(Uri.parse('/sepreel/665f2a'));
    expect(sepreel.action, DeepLinkAction.playReel);
    expect(sepreel.reelId, '665f2a');
  });
}
