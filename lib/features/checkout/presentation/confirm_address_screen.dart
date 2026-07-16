// lib/features/checkout/presentation/confirm_address_screen.dart
// Converted from: app/(tabs)/Checkout.tsx

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_routes.dart';
import 'widgets/checkout_address_widget.dart';

class ConfirmAddressScreen extends StatefulWidget {
  static const routeName = AppRoutes.confirmAddress;

  // ignore: use_super_parameters
  const ConfirmAddressScreen({Key? key}) : super(key: key);

  @override
  State<ConfirmAddressScreen> createState() => _ConfirmAddressScreenState();
}

class _ConfirmAddressScreenState extends State<ConfirmAddressScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  // ignore: unused_field
  bool _refreshing = false;
  int _refreshKey = 0;
  Map<String, dynamic> _cartSummary = {};
  List<dynamic> _cartItems = [];
  bool _isDeliveryAvailable = true;
  String _pincode = '';
  bool _isReserving = false;

  String _userName = '';
  String _selectedAddressId = '';
  bool _isNameModalVisible = false;
  final TextEditingController _nameInputController = TextEditingController();
  bool _isUpdatingName = false;

  late AnimationController _fadeAnimController;
  late Animation<double> _fadeAnimation;

  String? _buyNowProductId;

  @override
  void initState() {
    super.initState();
    _fadeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeAnimController, curve: Curves.easeIn);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _buyNowProductId = args['buy_now']?.toString();
    }
    _fetchCartData();
  }

  @override
  void dispose() {
    _nameInputController.dispose();
    _fadeAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchCartData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final userId = prefs.getString('user_id');
      if (token == null || userId == null) return;

      String currentLat = prefs.getString('latitude') ?? '0';
      String currentLng = prefs.getString('longitude') ?? '0';

      // Get user name and address
      final userUri = Uri.parse(
          'https://welfogapi.welfog.com/api/v2/get-user-by-access_token');
      final userResponse = await http.post(
        userUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'access_token': token, 'userId': userId}),
      );

      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        final localName = prefs.getString('user_name');
        final localLoginUser = prefs.getString('loginuser');
        final savedLocalName = localName ?? localLoginUser ?? '';
        final apiName = userData['name'] ?? userData['user_name'] ?? '';
        final finalName = (savedLocalName.isNotEmpty &&
                savedLocalName.toLowerCase() != 'user')
            ? savedLocalName
            : apiName;

        if (mounted) {
          setState(() {
            _userName = finalName;
          });
        }

        final addressData = userData['addressData'];
        if (addressData != null) {
          final String apiLat = addressData['latitude']?.toString() ?? '0';
          final String apiLng = addressData['longitude']?.toString() ?? '0';
          final String apiId = addressData['id']?.toString() ?? '';

          currentLat = apiLat;
          currentLng = apiLng;
          if (apiId.isNotEmpty) {
            _selectedAddressId = apiId;
          }

          // Save coordinates and pin to SharedPreferences to restore local cache/state
          await prefs.setString('latitude', apiLat);
          await prefs.setString('longitude', apiLng);
          final pin = addressData['postal_code']?.toString();
          if (pin != null && pin.isNotEmpty) {
            await prefs.setString('postal_code', pin);
          }
        }

        final pin = addressData?['postal_code']?.toString();
        if (pin != null && pin.isNotEmpty) {
          if (mounted) setState(() => _pincode = pin);
          await _checkDeliveryAvailability(pin, token);
        } else {
          if (mounted) setState(() => _isDeliveryAvailable = false);
        }
      }

      // Fetch cart items
      final cartUri =
          Uri.parse('https://welfogapi.welfog.com/api/v2/carts/$userId')
              .replace(
        queryParameters: {
          if (_buyNowProductId != null) 'buy_now': _buyNowProductId!,
          't': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      final cartResponse = await http.post(
        cartUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
        body: jsonEncode({
          'user_latitude': currentLat,
          'user_longitude': currentLng,
        }),
      );

      debugPrint(
          '[ConfirmAddress] /carts/$userId response status: ${cartResponse.statusCode}');
      debugPrint(
          '[ConfirmAddress] /carts/$userId response body: ${cartResponse.body}');

      if (cartResponse.statusCode == 200) {
        final cartData = jsonDecode(cartResponse.body) as List?;
        final list =
            cartData?.expand((c) => c['cart_items'] as List? ?? []).toList() ??
                [];
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
        queryParameters: {
          if (_buyNowProductId != null) 'buy_now': _buyNowProductId!,
          't': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      final summaryResponse = await http.get(
        summaryUri,
        headers: {
          'Authorization': 'Bearer $token',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );

      debugPrint(
          '[ConfirmAddress] /cart-summary/$userId response status: ${summaryResponse.statusCode}');
      debugPrint(
          '[ConfirmAddress] /cart-summary/$userId response body: ${summaryResponse.body}');

      if (summaryResponse.statusCode == 200) {
        final summaryData = jsonDecode(summaryResponse.body);
        if (mounted) {
          setState(() {
            _cartSummary = summaryData;
          });
        }
      }
    } catch (error) {
      debugPrint('Error fetching cart data: $error');
      if (mounted) setState(() => _isDeliveryAvailable = false);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
          _refreshKey += 1;
        });
        _fadeAnimController.forward();
      }
    }
  }

  Future<void> _checkDeliveryAvailability(String pin, String token) async {
    try {
      final uri = Uri.parse(
          'https://welfogapi.welfog.com/api/v2/delhivery_api/$pin?pincode=$pin');
      final response =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});

      debugPrint(
          '[ConfirmAddress] /delhivery_api/$pin status: ${response.statusCode} body: ${response.body}');

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _isDeliveryAvailable = resData['result'] != false;
          });
        }
      }
    } catch (err) {
      debugPrint('Delivery check failed: $err');
      if (mounted) setState(() => _isDeliveryAvailable = false);
    }
  }

  Future<void> _executeReservationAndNavigate() async {
    setState(() => _isReserving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      final payload = {
        'user_id': int.tryParse(userId ?? '') ?? 0,
        'items': _cartItems
            .map((item) => {
                  'product_id':
                      int.tryParse(item['product_id']?.toString() ?? '') ?? 0,
                  'quantity':
                      int.tryParse(item['quantity']?.toString() ?? '') ?? 0,
                })
            .toList(),
      };

      final response = await http.post(
        Uri.parse('https://welfogapi.welfog.com/api/reservations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final navParams = <String, String>{};
        if (_buyNowProductId != null) navParams['buy_now'] = _buyNowProductId!;
        if (_selectedAddressId.isNotEmpty)
          // ignore: curly_braces_in_flow_control_structures
          navParams['address_id'] = _selectedAddressId;

        if (mounted) {
          await Navigator.of(context).pushNamed(
            AppRoutes.paymentConfirmation,
            arguments: navParams,
          );
          _fetchCartData();
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Reservation Error: $error');
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error'),
            content: const Text(
                'Items currently unavailable or server error. Please try again.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReserving = false);
    }
  }

  void _handleProceed() {
    if (_userName.isEmpty ||
        _userName.trim().isEmpty ||
        _userName.toLowerCase() == 'user') {
      setState(() {
        _nameInputController.text = '';
        _isNameModalVisible = true;
      });
    } else {
      _executeReservationAndNavigate();
    }
  }

  Future<void> _handleSaveName() async {
    final nameVal = _nameInputController.text.trim();
    if (nameVal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name.')),
      );
      return;
    }

    setState(() => _isUpdatingName = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final tempUserId = prefs.getString('temp_user_id') ?? '';

      final payload = {
        'name': nameVal,
        'user_id': userId,
        'address_id': _selectedAddressId,
        'temp_user_id': tempUserId,
      };

      final response = await http.post(
        Uri.parse('https://welfogapi.welfog.com/api/v2/updateAddressName'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData != null) {
          final savedName = resData['name'] ?? nameVal;
          if (mounted) {
            setState(() {
              _userName = savedName;
              _isNameModalVisible = false;
            });
          }
          await prefs.setString('user_name', savedName);
          await prefs.setString('loginuser', savedName);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Details updated successfully')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error updating name: $e');
    } finally {
      if (mounted) setState(() => _isUpdatingName = false);
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _refreshing = true);
    await _fetchCartData();
  }

  String _cleanAmount(dynamic value) {
    if (value == null) return '0';
    final str = value.toString();
    final cleanStr = str.replaceAll(RegExp(r'[^0-9.,]'), '').trim();
    return cleanStr.isEmpty ? '0' : cleanStr;
  }

  @override
  Widget build(BuildContext context) {
    final grandTotal = double.tryParse((_cartSummary['grand_total'] ?? 0).toString().replaceAll(',', '')) ?? 0.0;
    final profit = double.tryParse((_cartSummary['profit'] ?? 0).toString().replaceAll(',', '')) ?? 0.0;
    final originalTotal = grandTotal + profit;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed(AppRoutes.home);
            }
          },
        ),
        title: const Text('Confirm Address',
            style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _onRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24, top: 12),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF008083))),
                    )
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          // ─── Step progress ─────────────────────────────────
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                            color: Colors.black)),
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
                                          color: Color(0xFFCCCCCC),
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
                                            color: Color(0xFF666666))),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // ─── Delivery Address card ─────────────────────────
                          Container(
                            margin: const EdgeInsets.only(
                                left: 14, right: 14, bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFE5E7EB)),
                              boxShadow: [
                                BoxShadow(
                                  // ignore: deprecated_member_use
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Delivery Address',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Color(0xFF0F766E)),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.of(context)
                                            .pushNamed(AppRoutes.address)
                                            .then((_) {
                                          _fetchCartData();
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: const Color(0xFF0F766E)),
                                        ),
                                        child: const Text('Change',
                                            style: TextStyle(
                                                color: Color(0xFF0F766E),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                CheckoutAddressWidget(
                                  refreshing: _refreshKey,
                                  onAddressChange: (newPin) =>
                                      setState(() => _pincode = newPin),
                                  onAddressIdChange: (id) =>
                                      setState(() => _selectedAddressId = id),
                                ),
                                if (!_isDeliveryAvailable)
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 10),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(6)),
                                    child: Text(
                                      '⚠️ Delivery not available for pincode $_pincode. Please change your address.',
                                      style: const TextStyle(
                                          color: Color(0xFFB91C1C),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // ─── Your Items list card ──────────────────────────
                          Container(
                            margin: const EdgeInsets.only(
                                left: 14, right: 14, bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFE5E7EB)),
                              boxShadow: [
                                BoxShadow(
                                  // ignore: deprecated_member_use
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Your Items',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF0F766E)),
                                ),
                                const SizedBox(height: 12),
                                if (_cartItems.isNotEmpty)
                                   ..._cartItems.map((item) {
                                    final double mrp = double.tryParse(
                                            (item['mrp'] ?? 0).toString()) ??
                                        0.0;
                                    final double price = double.tryParse(
                                            (item['price'] ?? 0).toString()) ??
                                        0.0;
                                    final int quantity = int.tryParse(
                                            (item['quantity'] ?? 1).toString()) ??
                                        1;
                                    final double saved =
                                        mrp > price ? (mrp - price) : 0.0;
                                    final double totalSaved = saved * quantity;
                                    final int pct = mrp > 0
                                        ? (((mrp - price) / mrp) * 100).round()
                                        : 0;

                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 14),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.network(
                                              'https://d1f02fefkbso7w.cloudfront.net/${item['product_thumbnail_image']}',
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(Icons.image,
                                                      size: 80),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(item['product_name'] ?? '',
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        fontSize: 13,
                                                        color: Colors.black)),
                                                if (item['seller_name'] != null)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 4),
                                                    child: Text(
                                                        'Sold by: ${item['seller_name']}',
                                                        style: const TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 13)),
                                                  ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    if (mrp > price) ...[
                                                      Text(
                                                        '₹${mrp.toStringAsFixed(0)}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Color(0xFF999999),
                                                          decoration: TextDecoration.lineThrough,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                    ],
                                                    Text(
                                                      '₹${price.toStringAsFixed(0)}',
                                                      style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.black),
                                                    ),
                                                    if (pct > 0) ...[
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        '$pct% OFF',
                                                        style: const TextStyle(
                                                            color: Color(0xFF008083),
                                                            fontWeight: FontWeight.w700,
                                                            fontSize: 11),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                if (quantity > 1)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 3),
                                                    child: Text(
                                                      'Qty: $quantity x ₹${price.toStringAsFixed(0)}',
                                                      style: const TextStyle(
                                                          color: Color(0xFF666666),
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500),
                                                    ),
                                                  ),
                                                if (totalSaved > 0)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 3),
                                                    child: Text(
                                                        'You save ₹${totalSaved.toStringAsFixed(0)} ($pct%)',
                                                        style: const TextStyle(
                                                            color: Colors.green,
                                                            fontSize: 12)),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    // ignore: unnecessary_to_list_in_spreads
                                  }).toList()
                                else
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Center(
                                        child: Text('No items found.',
                                            style:
                                                TextStyle(color: Colors.grey))),
                                  ),
                              ],
                            ),
                          ),

                          // ─── Order Summary card ────────────────────────────
                          Container(
                            margin: const EdgeInsets.only(
                                left: 14, right: 14, bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFE5E7EB)),
                              boxShadow: [
                                BoxShadow(
                                  // ignore: deprecated_member_use
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Order Summary',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF0F766E)),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        'Items Total (${_cartSummary['qty'] ?? 0})'),
                                    Text(
                                        '₹${_cleanAmount(_cartSummary['total'])}'),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Shipping'),
                                    Text(
                                        '₹${_cleanAmount(_cartSummary['shipping_cost'])}'),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Discount'),
                                    Text(
                                        '- ₹${_cleanAmount(_cartSummary['profit'])}',
                                        style: const TextStyle(
                                            color: Color(0xFF008083))),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Divider(),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total Amount',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                        '₹${_cleanAmount(_cartSummary['grand_total'])}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                if ((double.tryParse(
                                            (_cartSummary['profit'] ?? 0)
                                                .toString()) ??
                                        0.0) >
                                    0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'You’ll save ₹${_cleanAmount(_cartSummary['profit'])} on this order',
                                      style: const TextStyle(
                                          color: Color(0xFF008083),
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          // ─── Name update dialog prompt modal ───────────────────────────────
          if (_isNameModalVisible)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_circle,
                          size: 50, color: Color(0xFF008083)),
                      const SizedBox(height: 10),
                      const Text('Please enter your name',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                        'We need your name to process the delivery accurately.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _nameInputController,
                        decoration: InputDecoration(
                          hintText: 'Full Name',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF008083),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _isUpdatingName ? null : _handleSaveName,
                          child: _isUpdatingName
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text('Save & Continue',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: (!_loading &&
              _isDeliveryAvailable &&
              !_isNameModalVisible)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, -2))
                ],
              ),
              child: SafeArea(
                top: false,
                maintainBottomViewPadding: true,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'To Pay',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '₹${_cleanAmount(_cartSummary['grand_total'])}',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
                            if (profit > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                '₹${_cleanAmount(originalTotal)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF999999),
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF008083),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                        elevation: 0,
                      ),
                      onPressed: _isReserving ? null : _handleProceed,
                      child: const Row(
                        children: [
                          Text('Continue to Payment',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward,
                              color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
