// lib/features/checkout/presentation/payment_confirmation_screen.dart
// Converted from: app/(tabs)/Checkout2.tsx

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_routes.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  static const routeName = AppRoutes.paymentConfirmation;

  // ignore: use_super_parameters
  const PaymentConfirmationScreen({Key? key}) : super(key: key);

  @override
  State<PaymentConfirmationScreen> createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  bool _loading = true;
  Map<String, dynamic> _cartSummary = {};
  List<dynamic> _cartItems = [];
  // ignore: unused_field
  List<dynamic> _paymentTypes = [];
  String? _selectedPayment;
  String _walletBalance = '0';
  String _latitude = '0';
  String _longitude = '0';

  // Coupon
  final TextEditingController _couponController = TextEditingController();
  String _couponMessage = '';
  double _discount = 0.0;

  // CAPTCHA
  int _captchaNum1 = 0;
  int _captchaNum2 = 0;
  final TextEditingController _captchaAnswerController =
      TextEditingController();
  String _captchaError = '';

  bool _isChecked = false;
  String _errorMessage = '';
  bool _isPlacingOrder = false;

  String? _buyNowProductId;
  String? _addressId;

  @override
  void initState() {
    super.initState();
    _generateCaptcha();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _buyNowProductId = args['buy_now']?.toString();
      _addressId = args['address_id']?.toString();
    }
    _fetchUserDataAndCart();
    _fetchPaymentTypes();
  }

  @override
  void dispose() {
    _couponController.dispose();
    _captchaAnswerController.dispose();
    super.dispose();
  }

  void _generateCaptcha() {
    final random = Random();
    setState(() {
      _captchaNum1 = random.nextInt(9) + 1;
      _captchaNum2 = random.nextInt(9) + 1;
      _captchaAnswerController.text = '';
      _captchaError = '';
    });
  }

  Future<void> _fetchUserDataAndCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final userId = prefs.getString('user_id');
      if (token == null || userId == null) return;

      // Fetch user profile info
      final userUri = Uri.parse(
          'https://welfogapi.welfog.com/api/v2/get-user-by-access_token');
      final userResponse = await http.post(
        userUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'access_token': token, 'userId': userId}),
      );

      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        if (mounted) {
          setState(() {
            _walletBalance = userData['balance']?.toString() ?? '0';
            _latitude = userData['addressData']?['latitude']?.toString() ?? '0';
            _longitude =
                userData['addressData']?['longitude']?.toString() ?? '0';
          });
        }
      }

      // Fetch cart items
      final cartUri =
          Uri.parse('https://welfogapi.welfog.com/api/v2/carts/$userId')
              .replace(
        queryParameters:
            _buyNowProductId != null ? {'buy_now': _buyNowProductId!} : {},
      );
      final cartResponse = await http.post(
        cartUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_latitude': _latitude,
          'user_longitude': _longitude,
        }),
      );

      debugPrint(
          '[PaymentConfirmation] /carts/$userId response status: ${cartResponse.statusCode}');
      debugPrint(
          '[PaymentConfirmation] /carts/$userId response body: ${cartResponse.body}');

      if (cartResponse.statusCode == 200) {
        final cartData = jsonDecode(cartResponse.body) as List?;
        final list =
            cartData?.expand((c) => c['cart_items'] as List? ?? []).toList() ??
                [];
        if (list.isEmpty && _buyNowProductId == null) {
          if (mounted)
            // ignore: curly_braces_in_flow_control_structures
            Navigator.of(context).pushReplacementNamed(AppRoutes.home);
          return;
        }
        if (mounted) {
          setState(() {
            _cartItems = list;
          });
        }
      }

      // Fetch cart summary
      final summaryUri =
          Uri.parse('https://welfogapi.welfog.com/api/v2/cart-summary/$userId')
              .replace(
        queryParameters:
            _buyNowProductId != null ? {'buy_now': _buyNowProductId!} : {},
      );
      final summaryResponse = await http.get(
        summaryUri,
        headers: {'Authorization': 'Bearer $token'},
      );

      debugPrint(
          '[PaymentConfirmation] /cart-summary/$userId response status: ${summaryResponse.statusCode}');
      debugPrint(
          '[PaymentConfirmation] /cart-summary/$userId response body: ${summaryResponse.body}');

      if (summaryResponse.statusCode == 200) {
        final summaryData = jsonDecode(summaryResponse.body);
        if (mounted) {
          setState(() {
            _cartSummary = summaryData;
          });
        }
      }
    } catch (e) {
      debugPrint('fetchCartData error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchPaymentTypes() async {
    try {
      final uri = Uri.parse('https://welfogapi.welfog.com/api/payment-types');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _paymentTypes = data as List? ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('fetchPaymentTypes error: $e');
    }
  }

  Future<void> _handleApplyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) {
      setState(() => _couponMessage = 'Please enter a coupon code.');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final userId = prefs.getString('user_id');

      final uri = Uri.parse('https://welfogapi.welfog.com/api/coupon-apply');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'user_id': userId, 'coupon_code': code}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == true) {
          final amt =
              double.tryParse(data['couponDiscount']?.toString() ?? '') ?? 0.0;
          setState(() {
            _discount = amt;
            _couponMessage = data['message'] ?? 'Coupon applied successfully!';
          });
          await _fetchUserDataAndCart();
        } else {
          setState(() {
            _couponMessage = 'Invalid or expired coupon.';
          });
        }
      }
    } catch (_) {
      setState(() => _couponMessage = 'Failed to apply coupon.');
    }
  }

  void _handleRemoveCoupon() {
    setState(() {
      _couponController.text = '';
      _discount = 0.0;
      _couponMessage = '';
    });
    _fetchUserDataAndCart();
  }

  Future<void> _updateCartAfterOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final userId = prefs.getString('user_id');

    if (_buyNowProductId == null) {
      await prefs.setString('cart_count', '0');
    } else {
      try {
        final cartUri =
            Uri.parse('https://welfogapi.welfog.com/api/carts/$userId');
        final cartResponse = await http.post(
          cartUri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'user_latitude': _latitude,
            'user_longitude': _longitude,
          }),
        );

        if (cartResponse.statusCode == 200) {
          final cartData = jsonDecode(cartResponse.body) as List?;
          final list = cartData
                  ?.expand((c) => c['cart_items'] as List? ?? [])
                  .toList() ??
              [];
          int remaining = 0;
          for (var it in list) {
            remaining += int.tryParse(it['quantity']?.toString() ?? '') ?? 0;
          }
          await prefs.setString('cart_count', remaining.toString());
        }
      } catch (err) {
        debugPrint('Failed to sync cart: $err');
      }
    }
  }

  Future<void> _placeOrder() async {
    if (_isPlacingOrder) return;

    if (!_isChecked) {
      setState(() => _errorMessage = 'Please agree to the Terms & Conditions.');
      return;
    }

    if (_selectedPayment == 'cod') {
      final correctAnswer = _captchaNum1 + _captchaNum2;
      final userAnswer = int.tryParse(_captchaAnswerController.text.trim());
      if (userAnswer == null || userAnswer != correctAnswer) {
        setState(
            () => _captchaError = 'Please enter the correct sum to proceed.');
        return;
      }
    }

    setState(() {
      _errorMessage = '';
      _isPlacingOrder = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final userId = prefs.getString('user_id');

      // Fetch user profile info
      final userUri = Uri.parse(
          'https://welfogapi.welfog.com/api/v2/get-user-by-access_token');
      final userResponse = await http.post(
        userUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'access_token': token, 'userId': userId}),
      );

      final userData = jsonDecode(userResponse.body);
      final activeAddress = userData['addressData'] ?? {};
      final localName = prefs.getString('user_name');

      final finalCustomerName =
          activeAddress['name'] ?? localName ?? userData['name'] ?? 'User';
      final finalCustomerPhone =
          activeAddress['phone'] ?? userData['phone'] ?? '';
      final finalCustomerEmail = userData['email'] ?? '';

      final double payableValue = (double.tryParse(
                  (_cartSummary['grand_total_value'] ??
                          _cartSummary['grand_total'])
                      .toString()) ??
              0.0) -
          _discount;

      if (_selectedPayment == 'wallet') {
        final bal = double.tryParse(_walletBalance) ?? 0.0;
        if (bal < payableValue) {
          setState(() {
            _errorMessage = 'Insufficient wallet balance.';
            _isPlacingOrder = false;
          });
          return;
        }
      }

      final payload = {
        'user_id': int.tryParse(userId ?? '') ?? 0,
        'payment_method': _selectedPayment,
        'amount': payableValue,
        'ship_amt':
            double.tryParse((_cartSummary['shipping_cost'] ?? 0).toString()) ??
                0.0,
        'customer_name': finalCustomerName,
        'customer_email': finalCustomerEmail,
        'customer_phone': finalCustomerPhone,
        'currency': 'INR',
        'buy_now': _buyNowProductId,
        'delivery_address_id': _addressId,
        'coupon_code': _discount > 0 ? _couponController.text.trim() : null,
      };

      final orderUri =
          Uri.parse('https://welfogapi.welfog.com/api/payment/create-order');
      final response = await http.post(
        orderUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);

        if (_selectedPayment == 'cod' || _selectedPayment == 'wallet') {
          await _updateCartAfterOrder();
          final String cashOrderId = resData['order_id']?.toString() ?? '';

          if (mounted) {
            Navigator.of(context).pushReplacementNamed(
              '/profile/order-detail',
              arguments: {'id': cashOrderId, 'status': 'PAID'},
            );
          }
        } else if (_selectedPayment == 'pay_online') {
          // Cashfree online redirection fallback using clean Webview model mock/trigger
          final String sessionId = resData['payment_session_id'] ?? '';
          final String orderId =
              resData['transaction_id'] ?? resData['order_id'] ?? '';

          _launchCashfreeWebViewFlow(sessionId, orderId);
        }
      }
    } catch (e) {
      debugPrint('Order Placement Error: $e');
      setState(() => _errorMessage = 'Failed to place order.');
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  void _launchCashfreeWebViewFlow(String sessionId, String orderId) {
    // REDIRECTS to web checkout simulation
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Online checkout simulated'),
          content: Text(
              'Simulating Cashfree Online order processing for Order ID: $orderId'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _updateCartAfterOrder();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed(
                    '/profile/order-detail',
                    arguments: {'id': orderId, 'status': 'PAID'},
                  );
                }
              },
              child: const Text('Simulate Success'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedPayment == value;

    return GestureDetector(
      onTap: () => setState(() {
        _selectedPayment = value;
        _captchaError = '';
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDFA) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF0F766E) : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                // ignore: deprecated_member_use
                color: const Color(0xFF0F766E).withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            // Left Payment Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    // ignore: deprecated_member_use
                    ? const Color(0xFF0F766E).withOpacity(0.1)
                    : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? const Color(0xFF0F766E)
                    : const Color(0xFF6B7280),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Middle Text Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFF111827)
                          : const Color(0xFF374151),
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected
                            ? const Color(0xFF0F766E)
                            : const Color(0xFF6B7280),
                        fontWeight:
                            isSelected ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Right Custom Radio Indicator
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF0F766E)
                      : const Color(0xFFD1D5DB),
                  width: isSelected ? 6 : 2,
                ),
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double payable = (double.tryParse(
                (_cartSummary['grand_total_value'] ??
                        _cartSummary['grand_total'] ??
                        0)
                    .toString()) ??
            0.0) -
        _discount;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Payment & Confirmation',
            style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF008083)))
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.only(bottom: 100, top: 4),
                  children: [
                    // Step layout bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                    color: Color(0xFF008083),
                                    shape: BoxShape.circle),
                                child: const Text('1',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 6),
                              const Text('Confirm Address',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF666666))),
                            ],
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right,
                              size: 14, color: Color(0xFF999999)),
                          const SizedBox(width: 8),
                          Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                    color: Color(0xFF008083),
                                    shape: BoxShape.circle),
                                child: const Text('2',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 6),
                              const Text('Payment & Order',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Order summary panel
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Order Items',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF0F766E))),
                          const SizedBox(height: 12),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _cartItems.length,
                            itemBuilder: (context, idx) {
                              final item = _cartItems[idx];
                              final imageUrl =
                                  item['product_thumbnail_image'] ??
                                      item['product']?['thumbnail_image'];
                              final productName = item['product_name'] ??
                                  item['product']?['name'] ??
                                  '';
                              final double mrp = double.tryParse(
                                      (item['mrp'] ?? 0).toString()) ??
                                  0.0;
                              final double price = double.tryParse(
                                      (item['price'] ?? 0).toString()) ??
                                  0.0;
                              final double saved =
                                  mrp > price ? mrp - price : 0.0;
                              final int pct =
                                  mrp > 0 ? ((saved / mrp) * 100).round() : 0;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: const Color(0xFFE5E7EB)),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(5),
                                        child: Image.network(
                                          imageUrl != null
                                              ? 'https://d1f02fefkbso7w.cloudfront.net/$imageUrl'
                                              : 'https://welfogapi.welfog.com/public/images/no-image.png',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.image, size: 44),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            productName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Qty: ${item['quantity']} × ₹${item['price'] ?? 0}',
                                            style: const TextStyle(
                                                color: Color(0xFF666666),
                                                fontSize: 12),
                                          ),
                                          if (saved > 0)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 2),
                                              child: Text(
                                                'You save ₹${saved.toStringAsFixed(0)} ($pct%)',
                                                style: const TextStyle(
                                                    color: Colors.green,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w500),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('₹${item['price'] ?? 0}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Apply Coupon Container
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Apply Coupon',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF0F766E))),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFFD1D5DB)),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextField(
                                      controller: _couponController,
                                      style: const TextStyle(
                                          fontSize: 14, height: 1.2),
                                      decoration: const InputDecoration(
                                        hintText: 'Enter Promo Code',
                                        hintStyle: TextStyle(
                                            color: Color(0xFF9CA3AF),
                                            fontSize: 14),
                                        filled: true,
                                        fillColor: Colors.transparent,
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F766E),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  minimumSize: const Size(80, 44),
                                ),
                                onPressed: _discount > 0
                                    ? _handleRemoveCoupon
                                    : _handleApplyCoupon,
                                child: Text(
                                  _discount > 0 ? 'Remove' : 'Apply',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          if (_couponMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(_couponMessage,
                                  style: TextStyle(
                                      color: _discount > 0
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ),

                    // Payment selection list
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Select Payment Method',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF0F766E))),
                          const SizedBox(height: 16),

                          // Online
                          _buildPaymentOption(
                            value: 'pay_online',
                            title: 'Pay Online',
                            subtitle: 'UPI, Cards, NetBanking, Wallets',
                            icon: Icons.payment_rounded,
                          ),

                          // Wallet
                          _buildPaymentOption(
                            value: 'wallet',
                            title: 'Wallet',
                            subtitle: 'Available Balance: ₹$_walletBalance',
                            icon: Icons.account_balance_wallet_rounded,
                          ),

                          // Cash on delivery
                          _buildPaymentOption(
                            value: 'cod',
                            title: 'Cash on Delivery (COD)',
                            subtitle: 'Pay cash at your doorstep',
                            icon: Icons.local_shipping_rounded,
                          ),

                          // CAPTCHA check for COD selection
                          if (_selectedPayment == 'cod')
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(top: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Verification CAPTCHA',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF374151))),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text('$_captchaNum1 + $_captchaNum2 = ',
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F766E))),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Container(
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF9FAFB),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: const Color(0xFFD1D5DB)),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: TextField(
                                              controller:
                                                  _captchaAnswerController,
                                              keyboardType:
                                                  TextInputType.number,
                                              style: const TextStyle(
                                                  fontSize: 14, height: 1.2),
                                              decoration: const InputDecoration(
                                                hintText: 'Answer',
                                                hintStyle: TextStyle(
                                                    color: Color(0xFF9CA3AF),
                                                    fontSize: 14),
                                                filled: true,
                                                fillColor: Colors.transparent,
                                                border: InputBorder.none,
                                                enabledBorder: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                                isDense: true,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                          onPressed: _generateCaptcha,
                                          icon: const Icon(Icons.refresh,
                                              color: Color(0xFF0F766E))),
                                    ],
                                  ),
                                  if (_captchaError.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(_captchaError,
                                          style: const TextStyle(
                                              color: Colors.red, fontSize: 12)),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Pricing summary panel
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bill Details',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF0F766E))),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Items Total (${_cartSummary['qty'] ?? 0})'),
                              Text('₹${_cartSummary['total'] ?? 0}'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Shipping'),
                              Text('₹${_cartSummary['shipping_cost'] ?? 0}'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Discount'),
                              Text('- ₹${_cartSummary['profit'] ?? 0}',
                                  style: const TextStyle(
                                      color: Color(0xFF008083))),
                            ],
                          ),
                          if (_discount > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Coupon Discount',
                                    style: TextStyle(color: Colors.green)),
                                Text('- ₹${_discount.toStringAsFixed(0)}',
                                    style:
                                        const TextStyle(color: Colors.green)),
                              ],
                            ),
                          ],
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Payable',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              Text('₹${payable.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF0F766E))),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Terms and Conditions checkbox
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _isChecked,
                              activeColor: const Color(0xFF0F766E),
                              checkColor: Colors.white,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              onChanged: (val) =>
                                  setState(() => _isChecked = val ?? false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text.rich(
                              TextSpan(
                                text: 'I agree to the ',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF4B5563),
                                    height: 1.3),
                                children: [
                                  TextSpan(
                                    text: 'Terms & Conditions',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F766E)),
                                  ),
                                  TextSpan(text: ', '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F766E)),
                                  ),
                                  TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Anti-Phishing Defense Policy',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F766E)),
                                  ),
                                  TextSpan(text: '.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(_errorMessage,
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),

                // Grand total payable and order button bottom panel
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        border:
                            Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Amount: ₹${payable.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF008083),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            onPressed: _isPlacingOrder ? null : _placeOrder,
                            child: _isPlacingOrder
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text('Place Order',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
