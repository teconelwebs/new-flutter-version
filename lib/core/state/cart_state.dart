import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/cart/presentation/cart_screen.dart';

class CartState {
  static final ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);

  static Future<void> updateCartCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cart_count', count.toString());
    cartCountNotifier.value = count;
    CartScreen.clearCache();
  }

  static Future<void> loadCartCount() async {
    final prefs = await SharedPreferences.getInstance();
    final countStr = prefs.getString('cart_count') ?? '0';
    final count = int.tryParse(countStr) ?? 0;
    cartCountNotifier.value = count;
  }
}
