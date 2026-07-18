import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WishlistState {
  // ValueNotifier containing a map of {productId: isWishlisted}
  static final ValueNotifier<Map<String, bool>> wishlistNotifier =
      ValueNotifier<Map<String, bool>>({});

  /// Update wishlist state locally in SharedPreferences and notify active listeners.
  static Future<void> updateWishlistState(String productId, bool isWishlisted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wishlist_state_$productId', isWishlisted.toString());

    // Update the notifier to trigger listeners
    final current = Map<String, bool>.from(wishlistNotifier.value);
    current[productId] = isWishlisted;
    wishlistNotifier.value = current;
  }

  /// Check if a product is wishlisted (checks the memory notifier first, falls back to SharedPreferences).
  static Future<bool> isWishlisted(String productId) async {
    if (wishlistNotifier.value.containsKey(productId)) {
      return wishlistNotifier.value[productId]!;
    }

    final prefs = await SharedPreferences.getInstance();
    final wishState = prefs.getString('wishlist_state_$productId');
    final isWish = wishState == 'true';

    // Store in notifier map to cache it in memory
    final current = Map<String, bool>.from(wishlistNotifier.value);
    current[productId] = isWish;
    wishlistNotifier.value = current;

    return isWish;
  }
}
