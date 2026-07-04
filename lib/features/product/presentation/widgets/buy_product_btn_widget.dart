// lib/features/product/presentation/widgets/buy_product_btn_widget.dart
// Converted from: component/BuyProductBtn.tsx

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class BuyProductBtnWidget extends StatefulWidget {
  final Map<String, dynamic> data;
  final int selectedQuantity;

  const BuyProductBtnWidget({
    Key? key,
    required this.data,
    required this.selectedQuantity,
  }) : super(key: key);

  @override
  State<BuyProductBtnWidget> createState() => _BuyProductBtnWidgetState();
}

class _BuyProductBtnWidgetState extends State<BuyProductBtnWidget> {
  bool _buyNowLoading = false;
  bool _loading = false;
  bool _wishlist = false;

  @override
  void initState() {
    super.initState();
    _checkWishlistStatus();
  }

  Future<void> _checkWishlistStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final accessToken = prefs.getString('access_token');
      if (userId == null || accessToken == null) return;

      final productId = widget.data['id'];
      final uri = Uri.parse('https://welfogapi.welfog.com/api/wishlists/$userId');
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $accessToken'});

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final wishlistItems = data['data'] as List? ?? [];
        final isInWishlist = wishlistItems.any((item) => item['product']?['id'] == productId);
        if (mounted) {
          setState(() {
            _wishlist = isInWishlist;
          });
        }
      }
    } catch (error) {
      debugPrint('Error checking wishlist status: $error');
    }
  }

  Future<void> _addToCart(bool navigateToCart) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    final userId = prefs.getString('user_id');
    final isGuest = (accessToken == null || userId == null);

    if (isGuest) {
      Navigator.of(context).pushNamed('/User/Login');
      return;
    }

    if (navigateToCart) {
      setState(() => _buyNowLoading = true);
    } else {
      setState(() => _loading = true);
    }

    try {
      var colors = widget.data['colors'];
      List<dynamic> colorsList = [];
      if (colors is String) {
        if (colors.startsWith('[') && colors.endsWith(']')) {
          colorsList = jsonDecode(colors);
        } else {
          colorsList = colors.split(',').map((c) => c.trim()).toList();
        }
      } else if (colors is List) {
        colorsList = colors;
      }

      final String colorCode = colorsList.isNotEmpty ? colorsList[0].toString() : 'default';
      final int duration = int.tryParse(widget.data['shop_location']?['duration']?.toString() ?? '0') ?? 0;
      final int productId = int.tryParse(widget.data['id']?.toString() ?? '0') ?? 0;
      final int stockId = int.tryParse(widget.data['stocks']?[0]?['id']?.toString() ?? '0') ?? 0;

      final payload = {
        'color_code': colorCode,
        'delivery_time_minute': duration,
        'product_id': productId,
        'quantity': widget.selectedQuantity,
        'stockId': stockId,
        'temp_userId': '',
        'user_id': int.tryParse(userId) ?? 0,
        'buy_now': navigateToCart,
      };

      final uri = Uri.parse('https://welfogapi.welfog.com/api/crux/addcart');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['result'] == true) {
          // Sync cart count
          try {
            final lat = prefs.getString('latitude') ?? '0';
            final long = prefs.getString('longitude') ?? '0';
            final cartUri = Uri.parse('https://welfogapi.welfog.com/api/carts/$userId');
            final cartRes = await http.post(
              cartUri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $accessToken',
              },
              body: jsonEncode({'user_latitude': lat, 'user_longitude': long}),
            );

            if (cartRes.statusCode == 200) {
              final cartData = jsonDecode(cartRes.body) as List?;
              final cartList = cartData?.expand((c) => c['cart_items'] as List? ?? []).toList() ?? [];
              int count = 0;
              for (var it in cartList) {
                count += int.tryParse(it['quantity']?.toString() ?? '0') ?? 0;
              }
              await prefs.setString('cart_count', count.toString());
            }
          } catch (err) {
            debugPrint('Failed to sync cart count: $err');
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Added to Cart!'),
                backgroundColor: Color(0xFF008083),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }

          if (navigateToCart) {
            Navigator.of(context).pushNamed(
              '/(tabs)/Checkout',
              arguments: {'buy_now': widget.data['id']},
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(resData['message'] ?? 'Failed to add item to cart.'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (error) {
      debugPrint('Add to cart error: $error');
    } finally {
      if (mounted) {
        setState(() {
          _buyNowLoading = false;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawStock = widget.data['stock'] ??
        widget.data['product']?['stock'] ??
        widget.data['stocks']?[0]?['qty'] ??
        0;

    final int stock = int.tryParse(rawStock.toString()) ?? 0;
    final bool isOutOfStock = stock <= 0;

    return Container(
      color: const Color(0xFFFFF6F2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // ADD TO CART BUTTON
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOutOfStock
                        ? const Color(0xFF9CA3AF)
                        : (_loading || _buyNowLoading ? const Color(0xFF333333) : Colors.black),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  onPressed: (isOutOfStock || _loading || _buyNowLoading)
                      ? null
                      : () => _addToCart(false),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Add to Cart',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // BUY NOW BUTTON
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOutOfStock
                        ? const Color(0xFF9CA3AF)
                        : (_buyNowLoading || _loading ? const Color(0xFF0D6E6F) : const Color(0xFF008083)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  onPressed: (isOutOfStock || _buyNowLoading || _loading)
                      ? null
                      : () => _addToCart(true),
                  child: _buyNowLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Buy Now',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
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
