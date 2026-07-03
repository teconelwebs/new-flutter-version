// lib/features/cart/presentation/cart_screen.dart
// Converted from: app/(tabs)/Cart.tsx

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_routes.dart';

// ---------------------------------------------------------------------------
// CartItem Model
// ---------------------------------------------------------------------------
class CartItem {
  final int id;
  final String? slug;
  final String? size;
  final int productId;
  final String productName;
  final String productThumbnailImage;
  final double price;
  final double? mrp;
  final String? currencySymbol;
  int quantity;
  final String? sellerName;
  final double? duration;
  final Map<String, dynamic>? shopLocation;
  final String? colorCode;
  final int? stockId;

  CartItem({
    required this.id,
    this.slug,
    this.size,
    required this.productId,
    required this.productName,
    required this.productThumbnailImage,
    required this.price,
    this.mrp,
    this.currencySymbol,
    required this.quantity,
    this.sellerName,
    this.duration,
    this.shopLocation,
    this.colorCode,
    this.stockId,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: _safeInt(json['id']),
      slug: json['slug']?.toString(),
      size: json['size']?.toString(),
      productId: _safeInt(json['product_id']),
      productName: json['product_name']?.toString() ?? '',
      productThumbnailImage: json['product_thumbnail_image']?.toString() ?? '',
      price: _safeDouble(json['price']),
      mrp: json['mrp'] != null ? _safeDouble(json['mrp']) : null,
      currencySymbol: json['currency_symbol']?.toString(),
      quantity: _safeInt(json['quantity'], defaultValue: 1),
      sellerName: json['seller_name']?.toString(),
      duration: json['duration'] != null ? _safeDouble(json['duration']) : null,
      shopLocation: json['shop_location'] is Map
          ? Map<String, dynamic>.from(json['shop_location'])
          : null,
      colorCode: json['color_code']?.toString(),
      stockId: json['stockId'] != null ? _safeInt(json['stockId']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'size': size,
        'product_id': productId,
        'product_name': productName,
        'product_thumbnail_image': productThumbnailImage,
        'price': price,
        'mrp': mrp,
        'currency_symbol': currencySymbol,
        'quantity': quantity,
        'seller_name': sellerName,
        'duration': duration,
        'shop_location': shopLocation,
        'color_code': colorCode,
        'stockId': stockId,
      };

  CartItem copyWith({int? quantity}) {
    return CartItem(
      id: id,
      slug: slug,
      size: size,
      productId: productId,
      productName: productName,
      productThumbnailImage: productThumbnailImage,
      price: price,
      mrp: mrp,
      currencySymbol: currencySymbol,
      quantity: quantity ?? this.quantity,
      sellerName: sellerName,
      duration: duration,
      shopLocation: shopLocation,
      colorCode: colorCode,
      stockId: stockId,
    );
  }

  static int _safeInt(dynamic v, {int defaultValue = 0}) {
    final n = int.tryParse(v?.toString() ?? '');
    return (n == null || n < 0) ? defaultValue : n;
  }

  static double _safeDouble(dynamic v, {double defaultValue = 0}) {
    final n = double.tryParse(v?.toString() ?? '');
    return (n == null || n < 0) ? defaultValue : n;
  }
}

// ---------------------------------------------------------------------------
// Module-level cache
// ---------------------------------------------------------------------------
class _CartModuleCache {
  final int ts;
  final List<CartItem> items;
  final Map<String, dynamic> summary;

  _CartModuleCache(
      {required this.ts, required this.items, required this.summary});
}

_CartModuleCache? _cartModuleCache;

const String _saveKey = 'saved_for_later';
const int _cartFocusTtlMs = 20000;

// ---------------------------------------------------------------------------
// Helper functions
// ---------------------------------------------------------------------------
double _safeNumber(dynamic value, {double defaultValue = 0}) {
  final num = double.tryParse(value?.toString() ?? '');
  return (num == null || num < 0) ? defaultValue : num;
}

String _safeToFixed(dynamic value, {int decimals = 2}) {
  final num = _safeNumber(value, defaultValue: 0);
  return num.toStringAsFixed(decimals);
}

({double saved, int pct}) _getDiscount(double? mrp, double? price) {
  final m = _safeNumber(mrp, defaultValue: 0);
  final p = _safeNumber(price, defaultValue: 0);
  if (m <= 0 || m <= p) return (saved: 0, pct: 0);
  final saved = m - p;
  final pct = ((saved / m) * 100).round();
  return (saved: saved, pct: pct);
}

String calculateDeliveryTime(double? duration) {
  if (duration == null) return '2-4 days';
  if (duration <= 1440) return '1 day';
  final days = (duration / 1440).ceil();
  return '$days days';
}

String calculateDeliveryTimeFormate(double? duration) {
  if (duration == null) return '';
  final now = DateTime.now();
  final delivery = now.add(Duration(minutes: duration.toInt()));
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${days[delivery.weekday - 1]}, ${months[delivery.month - 1]} ${delivery.day}';
}

// ---------------------------------------------------------------------------
// CartScreen Widget
// ---------------------------------------------------------------------------
class CartScreen extends StatefulWidget {
  // Preserved from original: routeName + embedded param
  static const routeName = AppRoutes.cart;

  final bool embedded;

  // ignore: use_super_parameters
  const CartScreen({Key? key, this.embedded = false}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen>
    with SingleTickerProviderStateMixin {
  int _cartCount = 0;

  List<CartItem> _cartItems = _cartModuleCache?.items ?? [];
  Map<String, dynamic> _cartSummary = _cartModuleCache?.summary ?? {};
  List<CartItem> _savedForLater = [];
  bool _loading = _cartModuleCache == null;
  // ignore: unused_field
  bool _refreshing = false;
  bool _isDeleting = false;

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  final ScrollController _scrollController = ScrollController();
  // ignore: prefer_final_fields, unused_field
  bool _didInitialScroll = false;

  StreamSubscription? _refreshTabSub;

  static const String _cdnBaseUrl = 'https://d1f02fefkbso7w.cloudfront.net/';

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _bounceAnimation = Tween<double>(begin: 0, end: -15).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    _refreshTabSub = _refreshTabStream.stream.listen((_) {
      _onRefresh();
    });
  }

  static final StreamController<void> _refreshTabStream =
      StreamController.broadcast();

  // ignore: unused_element
  static void emitRefreshTabAction() {
    _refreshTabStream.add(null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _onFocusEffect();
  }

  void _onFocusEffect() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });

    final cacheFresh = _cartModuleCache != null &&
        DateTime.now().millisecondsSinceEpoch - _cartModuleCache!.ts <
            _cartFocusTtlMs;

    if (cacheFresh) {
      setState(() {
        _cartItems = _cartModuleCache!.items;
        _cartSummary = _cartModuleCache!.summary;
        _loading = false;
      });
      _loadSaved();
      _updateBounceAnimation();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchCartData();
        _loadSaved();
      });
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _scrollController.dispose();
    _refreshTabSub?.cancel();
    super.dispose();
  }

  void _updateBounceAnimation() {
    if (_cartItems.isEmpty && !_loading) {
      _bounceController.repeat(reverse: true);
    } else {
      _bounceController.stop();
      _bounceController.reset();
    }
  }

  // ---------------------------------------------------------------------------
  // API Methods
  // ---------------------------------------------------------------------------

  Future<void> _fetchCartData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final userId = prefs.getString('user_id');
      // ignore: unused_local_variable
      final lat = prefs.getString('latitude');
      // ignore: unused_local_variable
      final long = prefs.getString('longitude');

      if (token == null || userId == null) return;

      // TODO: Replace with actual API call
      // final res = await mainAPI.post('/carts/$userId', data: {'user_latitude': lat, 'user_longitude': long});
      // final list = res.data.expand((c) => c['cart_items'] ?? []).map(CartItem.fromJson).toList();
      final List<CartItem> list = [];
      final int count = list.fold(0, (t, i) => t + i.quantity);

      setState(() {
        _cartItems = list;
        _cartCount = count;
      });

      // TODO: Replace with actual summary API call
      // final summaryRes = await mainAPI.get('/cart-summary/$userId');
      // final summaryData = summaryRes.data;
      final Map<String, dynamic> summaryData = {};

      setState(() {
        _cartSummary = summaryData;
        _cartItems = list;
        _cartCount = count;
      });

      _cartModuleCache = _CartModuleCache(
        ts: DateTime.now().millisecondsSinceEpoch,
        items: list,
        summary: summaryData,
      );

      _updateBounceAnimation();
    } catch (err) {
      debugPrint('fetchCartData error: $err');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
        _updateBounceAnimation();
      }
    }
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_saveKey);
    if (raw != null) {
      final decoded = jsonDecode(raw) as List;
      if (mounted) {
        setState(() {
          _savedForLater = decoded.map((e) => CartItem.fromJson(e)).toList();
        });
      }
    }
  }

  Future<void> _persistSaved(List<CartItem> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _saveKey, jsonEncode(data.map((e) => e.toJson()).toList()));
  }

  Future<void> _removeCartItem(int id) async {
    try {
      // TODO: Replace with actual API call
      // final prefs = await SharedPreferences.getInstance();
      // final token = prefs.getString('access_token');
      // await mainAPI.post('/carts', data: {'id': id});
      setState(() {
        _cartItems = _cartItems.where((x) => x.id != id).toList();
      });
      await _fetchCartData();
    } catch (error) {
      debugPrint('removeCartItem error: $error');
      rethrow;
    }
  }

  Future<void> _removeSaved(int id) async {
    final updated = _savedForLater.where((s) => s.id != id).toList();
    setState(() {
      _savedForLater = updated;
    });
    await _persistSaved(updated);
  }

  Future<void> _handleDeleteItem(CartItem item, {bool saved = false}) async {
    setState(() => _isDeleting = true);
    try {
      if (saved) {
        await _removeSaved(item.id);
      } else {
        await _removeCartItem(item.id);
      }
      _showCustomPopup('Item removed successfully');
    } catch (error) {
      debugPrint('handleDeleteItem error: $error');
      _showCustomPopup('Unable to delete item.');
    } finally {
      setState(() => _isDeleting = false);
    }
  }

  // ignore: unused_element
  Future<void> _saveForLater(CartItem item) async {
    await _removeCartItem(item.id);
    final updated = [item, ..._savedForLater];
    setState(() {
      _savedForLater = updated;
    });
    await _persistSaved(updated);
  }

  Future<bool> _addToCartBackend(CartItem item) async {
    try {
      // TODO: Replace with actual API call
      // final prefs = await SharedPreferences.getInstance();
      // final userId = prefs.getString('user_id');
      // final tempUserId = prefs.getString('temp_user_id');
      // final res = await secondAPI.post('/crux/addcart', data: { ... });
      // return res.statusCode == 200 && res.data['result'] == true;
      return true;
    } catch (e) {
      debugPrint('addToCartBackend error: $e');
      return false;
    }
  }

  Future<void> _moveToCart(CartItem item) async {
    try {
      final updatedSaved =
          _savedForLater.where((s) => s.id != item.id).toList();
      setState(() {
        _savedForLater = updatedSaved;
      });
      await _persistSaved(updatedSaved);

      final ok = await _addToCartBackend(item);
      if (ok) {
        await _fetchCartData();
      } else {
        setState(() {
          _cartItems = [
            item.copyWith(quantity: item.quantity > 0 ? item.quantity : 1),
            ..._cartItems
          ];
        });
      }
    } catch (err) {
      debugPrint('moveToCart error: $err');
    }
  }

  Future<bool> _updateCart(int id, int quantity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) throw Exception('No token');

      // TODO: Replace with actual API call
      // final res = await mainAPI.post('/carts/change-quantity', data: {'id': id, 'quantity': quantity});
      await _fetchCartData();
      return true;
    } catch (err) {
      debugPrint('updateCart error: $err');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Computed Values
  // ---------------------------------------------------------------------------

  double get _subtotalLocal {
    return _cartItems.fold(0.0, (acc, it) {
      return acc +
          _safeNumber(it.price) * _safeNumber(it.quantity, defaultValue: 0);
    });
  }

  double get _totalSavings {
    return _cartItems.fold(0.0, (sum, it) {
      final mrp = _safeNumber(it.mrp, defaultValue: 0);
      final price = _safeNumber(it.price, defaultValue: 0);
      final quantity = _safeNumber(it.quantity, defaultValue: 1);
      if (mrp > price) return sum + (mrp - price) * quantity;
      return sum;
    });
  }

  Map<String, List<CartItem>> get _groupedBySeller {
    final map = <String, List<CartItem>>{};
    for (final it in _cartItems) {
      final seller = it.sellerName ?? 'Other sellers';
      map.putIfAbsent(seller, () => []).add(it);
    }
    return map;
  }

  bool get _hasAnyItems => _cartItems.isNotEmpty || _savedForLater.isNotEmpty;

  // ---------------------------------------------------------------------------
  // Event Handlers
  // ---------------------------------------------------------------------------

  Future<void> _onRefresh() async {
    setState(() => _refreshing = true);
    await _fetchCartData();
    await _loadSaved();
  }

  void _handleCheckoutPress() {
    Navigator.of(context).pushNamed('/Checkout');
  }

  void _showCustomPopup(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(
                fontWeight: FontWeight.w500, letterSpacing: 0.3)),
        backgroundColor: const Color(0xFF222222).withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 80,
          left: 24,
          right: 24,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _changeQuantity(CartItem item, int newQty) async {
    final safeQty = newQty < 1 ? 1 : newQty;
    if (safeQty < 1) return;

    if (safeQty > 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum you can buy 2 items at one time'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _cartItems = _cartItems
          .map((x) => x.id == item.id ? x.copyWith(quantity: safeQty) : x)
          .toList();
    });

    final recalculatedCount = _cartItems.fold(0, (t, i) => t + i.quantity);
    setState(() => _cartCount = recalculatedCount);

    final ok = await _updateCart(item.id, safeQty);
    if (!ok) {
      _showCustomPopup('Could not update quantity. Re-syncing cart.');
      await _fetchCartData();
    }
  }

  String _formatDeliveryText(double? duration) {
    final rawEst = calculateDeliveryTime(duration).trim();
    final rawDate = calculateDeliveryTimeFormate(duration).trim();

    String clean(String s) {
      return s
          .replaceAll(
              RegExp(r'\b(est\.?\s*)?delivery\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\bdelivery\s*by\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\bby\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
    }

    final days = clean(rawEst);
    final byDate = clean(rawDate);

    if (days.isEmpty && byDate.isEmpty) return 'Est. delivery: 2–4 days';
    if (days.isNotEmpty && byDate.isNotEmpty)
      return 'Est. delivery: $days • By $byDate';
    if (days.isNotEmpty) return 'Est. delivery: $days';
    return 'Est. delivery: By $byDate';
  }

  // ---------------------------------------------------------------------------
  // Build: Individual Product Card
  // ---------------------------------------------------------------------------
  Widget _renderProduct(CartItem item, {bool saved = false}) {
    final discount = _getDiscount(item.mrp, item.price);
    final deliveryText = _formatDeliveryText(item.duration);

    return Container(
      key: ValueKey('${saved ? 'saved' : 'cart'}-${item.id}'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image + Quantity Section
          SizedBox(
            width: 90,
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    if (item.slug != null) {
                      Navigator.of(context).pushNamed('/products/${item.slug}');
                    }
                  },
                  child: Image.network(
                    '$_cdnBaseUrl${item.productThumbnailImage}',
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 90,
                      height: 90,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image_outlined),
                    ),
                  ),
                ),
                if (!saved)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            final currentQty =
                                item.quantity < 1 ? 1 : item.quantity;
                            _changeQuantity(
                                item, (currentQty - 1).clamp(1, 99));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(4),
                              border:
                                  Border.all(color: const Color(0xFFDDDDDD)),
                            ),
                            child: const Text('-',
                                style: TextStyle(
                                    fontSize: 15, color: Color(0xFF333333))),
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(minWidth: 22),
                          alignment: Alignment.center,
                          child: Text(
                            '${item.quantity < 1 ? 1 : item.quantity}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            final currentQty =
                                item.quantity < 1 ? 1 : item.quantity;
                            _changeQuantity(item, currentQty + 1);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            margin: const EdgeInsets.only(left: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(4),
                              border:
                                  Border.all(color: const Color(0xFFDDDDDD)),
                            ),
                            child:
                                const Text('+', style: TextStyle(fontSize: 15)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Details Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (item.slug != null) {
                              Navigator.of(context)
                                  .pushNamed('/products/${item.slug}');
                            }
                          },
                          child: Text(
                            item.productName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                color: Color(0xFF111111)),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          if (saved)
                            GestureDetector(
                              onTap: () => _moveToCart(item),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                margin: const EdgeInsets.only(left: 8),
                                child: const Icon(Icons.shopping_cart_outlined,
                                    color: Color(0xFF008083), size: 21),
                              ),
                            ),
                          GestureDetector(
                            onTap: _isDeleting
                                ? null
                                : () => _handleDeleteItem(item, saved: saved),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              margin: const EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.delete_outline,
                                color: _isDeleting
                                    ? Colors.grey.shade300
                                    : const Color(0xFF999999),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (item.size != null && item.size!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Size: ${item.size}',
                          style: const TextStyle(color: Color(0xFF666666))),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        if (item.mrp != null)
                          Text(
                            '₹${item.mrp!.toStringAsFixed(0)}',
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Color(0xFF999999),
                              fontSize: 13,
                            ),
                          ),
                        if (item.mrp != null) const SizedBox(width: 6),
                        Text(
                          '₹${item.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        if (discount.pct > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${discount.pct}% OFF',
                            style: const TextStyle(
                                color: Color(0xFF008083),
                                fontWeight: FontWeight.w700,
                                fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      deliveryText,
                      style: const TextStyle(
                          color: Color(0xFF777777), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Summary Row Helper
  // ---------------------------------------------------------------------------
  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Color(0xFF555555), fontSize: 14)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final groupedBySeller = _groupedBySeller;
    final subtotalLocal = _subtotalLocal;
    final totalSavings = _totalSavings;

    final grandTotal = _safeNumber(_cartSummary['grand_total'],
        defaultValue: subtotalLocal +
            _safeNumber(_cartSummary['shipping_cost']) -
            _safeNumber(_cartSummary['coupon_discount']));

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: Column(
        children: [
          // ─── Header — Responsive Android & iOS ────────────────────────
          Container(
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status bar spacer — picks up correct height on both platforms
                SizedBox(height: MediaQuery.of(context).padding.top),
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border:
                        Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
                  ),
                  child: Row(
                    children: [
                      // Back button — always visible
                      GestureDetector(
                        onTap: () {
                          try {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              Navigator.of(context).pushReplacementNamed('/');
                            }
                          } catch (_) {
                            Navigator.of(context).pushReplacementNamed('/');
                          }
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: const Icon(Icons.chevron_left,
                              size: 24, color: Color(0xFF111111)),
                        ),
                      ),
                      // Title — center
                      const Expanded(
                        child: Text(
                          'Your Cart',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111111),
                          ),
                        ),
                      ),
                      // Item count badge
                      Container(
                        width: 40,
                        alignment: Alignment.center,
                        child: Text(
                          '${_cartItems.length}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Main Content ────────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: _hasAnyItems
                        ? const AlwaysScrollableScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    slivers: [
                      if (_loading)
                        const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_cartItems.isEmpty && _savedForLater.isEmpty)
                        // ─── Empty Cart — centered vertically ──────────────
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedBuilder(
                                    animation: _bounceAnimation,
                                    builder: (context, child) {
                                      return Transform.translate(
                                        offset:
                                            Offset(0, _bounceAnimation.value),
                                        child: child,
                                      );
                                    },
                                    child: Container(
                                      width: 140,
                                      height: 140,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFF0A6B69).withOpacity(0.12),
                                            const Color(0xFF0A6B69).withOpacity(0.01),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Outer ring
                                          Container(
                                            width: 120,
                                            height: 120,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFF0A6B69).withOpacity(0.15),
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                          // Floating circular card
                                          Container(
                                            width: 88,
                                            height: 88,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.04),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.local_mall_rounded,
                                              size: 38,
                                              color: Color(0xFF0A6B69),
                                            ),
                                          ),
                                          // Orange notification dot
                                          Positioned(
                                            right: 26,
                                            top: 26,
                                            child: Container(
                                              width: 13,
                                              height: 13,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: const Color(0xFFFB5404),
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    "Looks like you haven't added anything yet.\nStart shopping and add items to your cart.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF6B7280),
                                      height: 1.8,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  GestureDetector(
                                    onTap: () =>
                                        Navigator.of(context).pushNamed(
                                      '/Category',
                                      arguments: {
                                        'id': 'all',
                                        'name': 'All Categories'
                                      },
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14, horizontal: 32),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFB5404),
                                        borderRadius: BorderRadius.circular(25),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFB5404)
                                                .withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.search,
                                              size: 18, color: Colors.white),
                                          SizedBox(width: 8),
                                          Text(
                                            'Explore Products',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        // ─── Cart Items + Saved + Summary ─────────────────
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(10, 6, 10, 100),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              // Cart items grouped by seller
                              ...groupedBySeller.entries.expand((entry) {
                                return entry.value
                                    .map((item) => _renderProduct(item));
                              }),

                              // Saved for Later
                              if (_savedForLater.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 24),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 14),
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        decoration: const BoxDecoration(
                                          border: Border(
                                              bottom: BorderSide(
                                                  color: Color(0xFFE5E5E5))),
                                        ),
                                        child: const Text(
                                          'Saved for Later',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1A1A),
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                      ..._savedForLater.map((i) =>
                                          _renderProduct(i, saved: true)),
                                    ],
                                  ),
                                ),

                              // Order Summary
                              if (_cartItems.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: const Color(0xFFE5E5E5)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        decoration: const BoxDecoration(
                                          border: Border(
                                              bottom: BorderSide(
                                                  color: Color(0xFFE5E5E5))),
                                        ),
                                        child: const Text(
                                          'Order Summary',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 17,
                                            color: Color(0xFF1A1A1A),
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                      _summaryRow('Items subtotal',
                                          '₹${_safeToFixed(subtotalLocal)}'),
                                      _summaryRow('Shipping',
                                          '₹${_safeToFixed(_cartSummary['shipping_cost'])}'),
                                      _summaryRow('Total Discounts',
                                          '- ₹${_safeToFixed(totalSavings)}'),
                                      if (_safeNumber(
                                              _cartSummary['coupon_discount']) >
                                          0)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 10),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('Coupon Applied',
                                                  style: TextStyle(
                                                      color: Color(0xFF008083),
                                                      fontWeight:
                                                          FontWeight.w500)),
                                              Text(
                                                  '- ₹${_safeToFixed(_cartSummary['coupon_discount'])}',
                                                  style: const TextStyle(
                                                      color: Color(0xFF008083),
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                      Container(
                                          height: 1,
                                          color: const Color(0xFFEEEEEE),
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 8)),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Subtotal',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w900)),
                                          Text('₹${_safeToFixed(grandTotal)}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w900)),
                                        ],
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          "You'll save ₹${_safeToFixed(totalSavings)} on this order",
                                          style: const TextStyle(
                                              color: Color(0xFF008083),
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),

                // ─── Sticky Checkout Button ──────────────────────────────
                if (_cartItems.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 12,
                        bottom: MediaQuery.of(context).padding.bottom + 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: const Border(
                            top: BorderSide(color: Color(0xFFEEEEEE))),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₹${_safeToFixed(grandTotal)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: Color(0xFF111111),
                                ),
                              ),
                              if (totalSavings > 0)
                                Text(
                                  'Save ₹${_safeToFixed(totalSavings)}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF008083),
                                      fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GestureDetector(
                              onTap: _handleCheckoutPress,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFB5404),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  'Proceed to Checkout',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
