// lib/features/product/presentation/widgets/product_details_widget.dart
// Converted from: component/ProductDetails.tsx

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;


class ProductDetailsWidget extends StatefulWidget {
  final Map<String, dynamic> data;
  final String pincode;
  final VoidCallback? onRatingTap;

  // ignore: use_super_parameters
  const ProductDetailsWidget({
    Key? key,
    required this.data,
    required this.pincode,
    this.onRatingTap,
  }) : super(key: key);

  @override
  State<ProductDetailsWidget> createState() => _ProductDetailsWidgetState();
}

class _ProductDetailsWidgetState extends State<ProductDetailsWidget> {
  final TextEditingController _pincodeController = TextEditingController();
  String _deliveryMessage = '';
  String _errorMessage = '';
  bool _checkingDelivery = false;
  String _lastCheckedPin = '';
  dynamic _checkedPincodeDuration;

  int _apiTotalReviews = 0;
  double _apiRating = 0.0;
  int _totalRatings = 0;

  @override
  void initState() {
    super.initState();
    _pincodeController.text = widget.pincode;

    // Pre-initialize values from widget details if available
    final rVal =
        widget.data['rating'] ?? widget.data['product']?['rating'] ?? 0.0;
    _apiRating = double.tryParse(rVal.toString()) ?? 0.0;

    final rawRc = widget.data['total_ratings'] ??
        widget.data['rating_count'] ??
        widget.data['ratings_count'] ??
        widget.data['product']?['total_ratings'] ??
        widget.data['product']?['rating_count'];
    _totalRatings = int.tryParse(rawRc?.toString() ?? '') ?? 0;

    _fetchReviews();
    if (widget.pincode.isNotEmpty) {
      _checkDelivery(widget.pincode);
    }
  }

  @override
  void didUpdateWidget(ProductDetailsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pincodeChanged = oldWidget.pincode != widget.pincode;
    final dataChanged = oldWidget.data != widget.data;
    if (pincodeChanged || dataChanged) {
      if (widget.pincode.isNotEmpty) {
        _pincodeController.text = widget.pincode;
        _checkDelivery(widget.pincode);
      }
    }
  }

  @override
  void dispose() {
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _fetchReviews() async {
    try {
      final productId = widget.data['id'];
      if (productId == null) return;

      final uri = Uri.parse(
          'https://welfogapi.welfog.com/api/v2/reviews/product_review/$productId');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == true && mounted) {
          setState(() {
            _apiTotalReviews =
                int.tryParse(data['total_reviews']?.toString() ?? '0') ?? 0;
            final rVal = widget.data['rating'] ??
                widget.data['product']?['rating'] ??
                0.0;
            _apiRating = double.tryParse(rVal.toString()) ?? 0.0;

            final rawRc = data['total_ratings'] ??
                data['rating_count'] ??
                data['ratings_count'] ??
                widget.data['total_ratings'] ??
                widget.data['rating_count'] ??
                widget.data['product']?['total_ratings'] ??
                widget.data['product']?['rating_count'];
            _totalRatings =
                int.tryParse(rawRc?.toString() ?? '') ?? _apiTotalReviews;
          });
        }
      }
    } catch (e) {
      debugPrint('Review API Error: $e');
    }
  }

  Future<void> _checkDelivery(String pin) async {
    if (pin.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a pincode first.';
        _deliveryMessage = '';
      });
      return;
    }

    setState(() {
      _checkingDelivery = true;
      _lastCheckedPin = pin;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userIdStr = prefs.getString('user_id') ?? '';
      final accessToken = prefs.getString('access_token') ?? '';
      final dynamicShopLocationId =
          widget.data['location_id'] ?? widget.data['product']?['location_id'];

      // Parse IDs to numbers (int) if possible
      final dynamic userId = int.tryParse(userIdStr) ?? (userIdStr.isEmpty ? null : userIdStr);
      
      final shopLocationIdStr = (dynamicShopLocationId ?? '').toString();
      final dynamic shopLocationId = int.tryParse(shopLocationIdStr) ?? (shopLocationIdStr.isEmpty ? null : shopLocationIdStr);

      final productIdStr = (widget.data['id'] ?? widget.data['product']?['id'] ?? widget.data['product_id'] ?? '').toString();
      final dynamic shopProductId = int.tryParse(productIdStr) ?? (productIdStr.isEmpty ? null : productIdStr);

      // Parse coordinates to numbers (double) if possible
      final latVal = widget.data['shop_location']?['shop_latitude'] ??
          widget.data['product']?['shop_location']?['shop_latitude'];
      final lngVal = widget.data['shop_location']?['shop_longitude'] ??
          widget.data['product']?['shop_location']?['shop_longitude'];
      final dynamic shopLatitude = double.tryParse(latVal?.toString() ?? '') ?? latVal;
      final dynamic shopLongitude = double.tryParse(lngVal?.toString() ?? '') ?? lngVal;

      final payload = {
        'pincode': pin,
        'shop_latitude': shopLatitude,
        'shop_longitude': shopLongitude,
        'shop_product_id': shopProductId,
        'user_id': userId,
        'shop_location_id': shopLocationId,
      };

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      if (accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }

      final uri = Uri.parse('https://welfogapi.welfog.com/api/v2/pincode/check');
      
      debugPrint('🔍 Outgoing Pincode Check Payload: ${jsonEncode(payload)}');
      debugPrint('🔍 Outgoing Headers: $headers');

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(payload),
      );

      debugPrint('🔍 Response Status Code: ${response.statusCode}');
      debugPrint('🔍 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == true && mounted) {
          setState(() {
            _deliveryMessage =
                data['message'] ?? 'Product available for delivery';
            _errorMessage = '';
            _checkedPincodeDuration = data['duration'] ?? data['data']?['duration'];
          });
        } else {
          setState(() {
            _errorMessage = 'Ops.. Product is Not available on this pincode';
            _deliveryMessage = '';
            _checkedPincodeDuration = null;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Ops.. Product is Not available on this pincode';
          _deliveryMessage = '';
          _checkedPincodeDuration = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Something went wrong.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _checkingDelivery = false;
        });
      }
    }
  }

  String _formatDeliveryTime(dynamic duration) {
    if (duration == null) return '2 - 4 days';
    final double? parsedVal = double.tryParse(duration.toString());
    if (parsedVal == null || parsedVal < 0) {
      return '2 - 4 days';
    }

    final int minutes = parsedVal.toInt();
    final int days = minutes ~/ 1440; // Math.floor(minutes / 1440)

    if (days > 0) {
      final int min = days;
      final int max = days + 1;
      return '$min - $max days';
    }

    final int hours = (minutes % 1440) ~/ 60;
    final int mins = minutes % 60;

    String result = '';
    if (hours > 0) {
      result += '$hours hr${hours > 1 ? 's' : ''}';
    }
    if (mins > 0) {
      result += '${result.isNotEmpty ? ' ' : ''}$mins min${mins > 1 ? 's' : ''}';
    }

    return result.trim().isNotEmpty ? result.trim() : '0 min';
  }

  List<Color> _parseGradient(String colorVal) {
    try {
      final cleaned = colorVal
          .replaceAll(RegExp(r'linear-gradient\(|\)'), '')
          .split(',')
          .map((c) => c.trim())
          .where((c) => !c.startsWith('to ') && !c.endsWith('deg'))
          .toList();

      if (cleaned.length >= 2) {
        return cleaned.map((c) => _colorFromHex(c)).toList();
      }
    } catch (_) {}
    return [Colors.black, Colors.black];
  }

  Color _colorFromHex(String hexString) {
    try {
      final cleanHex = hexString.replaceAll('#', '').trim();

      // Handle standard CSS color name fallbacks
      final htmlColors = {
        'black': 0xFF000000,
        'white': 0xFFFFFFFF,
        'red': 0xFFFF0000,
        'green': 0xFF00FF00,
        'blue': 0xFF0000FF,
        'yellow': 0xFFFFE000,
        'cyan': 0xFF00FFFF,
        'magenta': 0xFFFF00FF,
        'gray': 0xFF808080,
        'grey': 0xFF808080,
        'orange': 0xFFFFA500,
        'pink': 0xFFFFC0CB,
        'purple': 0xFF800080,
        'brown': 0xFFA52A2A,
        'silver': 0xFFC0C0C0,
        'gold': 0xFFFFD700,
      };

      if (htmlColors.containsKey(cleanHex.toLowerCase())) {
        return Color(htmlColors[cleanHex.toLowerCase()]!);
      }

      final buffer = StringBuffer();
      if (cleanHex.length == 6 || cleanHex.length == 7) {
        buffer.write('ff');
      }
      buffer.write(cleanHex);
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.grey.shade400; // Return a default color instead of crashing
    }
  }

  @override
  Widget build(BuildContext context) {
    // Brand parsing
    final rawBrand = widget.data['brand_name'] ??
        widget.data['brandName'] ??
        widget.data['brand'] ??
        widget.data['Brand'] ??
        widget.data['brand_title'] ??
        widget.data['brandTitle'] ??
        widget.data['brand']?['name'] ??
        widget.data['brand']?['title'];

    final brandName =
        (rawBrand is String && rawBrand != 'No Brand') ? rawBrand.trim() : '';

    final rawStock = widget.data['stock'] ??
        widget.data['product']?['stock'] ??
        widget.data['stocks']?[0]?['qty'] ??
        0;
    final int stock = int.tryParse(rawStock.toString()) ?? 0;
    final bool isOutOfStock = stock <= 0;

    final sellPrice = widget.data['final_price']?['sellPrice'] ??
        widget.data['product']?['final_price']?['sellPrice'] ??
        0.0;
    final mrpPrice = widget.data['final_price']?['mrpPrice'] ??
        widget.data['product']?['final_price']?['mrpPrice'] ??
        0.0;
    final discountPercentage = widget.data['final_price']
            ?['discountPercentage'] ??
        widget.data['product']?['final_price']?['discountPercentage'] ??
        0;

    final variants = widget.data['variant_products'] ??
        widget.data['product']?['variant_products'] as Map<String, dynamic>?;

    final bool isCheckDisabled =
        _checkingDelivery || _pincodeController.text == _lastCheckedPin;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Label
          if (brandName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Brand: $brandName',
                style: const TextStyle(
                  color: Color(0xFF71717A),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // Title
          Padding(
            padding: EdgeInsets.only(top: brandName.isNotEmpty ? 2 : 4),
            child: Text(
              widget.data['name'] ?? widget.data['product']?['name'] ?? '',
              style: const TextStyle(
                color: Color(0xFF2B2B2B),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Star rating reviews summary
          if (_apiTotalReviews > 0)
            GestureDetector(
              onTap: widget.onRatingTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Row(
                  children: [
                    // Green capsule rating badge
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A), // Emerald Green
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _apiRating > 0
                                ? _apiRating.toStringAsFixed(1)
                                : '0.0',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.star, color: Colors.white, size: 13),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Rating & Review counts
                    Text(
                      '$_totalRatings Ratings | $_apiTotalReviews Reviews',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4B5563),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF9CA3AF),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),

          // Price info
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '₹$sellPrice',
                      style: const TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (mrpPrice > sellPrice)
                      Text(
                        '₹$mrpPrice',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (discountPercentage > 0)
                      Row(
                        children: [
                          Text(
                            '$discountPercentage% ',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Icon(Icons.arrow_downward,
                              color: Colors.green, size: 16),
                        ],
                      ),
                  ],
                ),
                const Text(
                  'Inclusive of all taxes',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Pincode and Stock Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Check Delivery
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Check Delivery',
                      style: TextStyle(
                          color: Color(0xFF71717A),
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextField(
                                controller: _pincodeController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.2,
                                  color: Color(0xFF1F2937),
                                ),
                                onChanged: (value) {
                                  setState(() {});
                                },
                                decoration: const InputDecoration(
                                  hintText: 'Enter Pincode',
                                  counterText: '',
                                  contentPadding:
                                      EdgeInsets.symmetric(horizontal: 10),
                                  isDense: true,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: isCheckDisabled
                                ? null
                                : () => _checkDelivery(_pincodeController.text),
                            child: Container(
                              width: 75,
                              height: 50,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isCheckDisabled
                                    ? const Color(0xFFCCCCCC)
                                    : const Color(0xFFFB5404),
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(7),
                                  bottomRight: Radius.circular(7),
                                ),
                              ),
                              child: Text(
                                _checkingDelivery ? 'Checking...' : 'Check',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Stock Status
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOutOfStock ? 'Out of Stock' : 'Left Stock',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isOutOfStock
                            ? Colors.red.shade600
                            : const Color(0xFF71717A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? Colors.red.shade50
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isOutOfStock
                              ? Colors.red.shade300
                              : const Color(0xFFD1D5DB),
                        ),
                      ),
                      child: Text(
                        '($stock)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isOutOfStock
                              ? Colors.red.shade600
                              : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Pincode check responses
          if (_checkingDelivery ||
              _deliveryMessage.isNotEmpty ||
              _errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: _checkingDelivery
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFFFB5404)),
                          ),
                          SizedBox(width: 8),
                          Text('Checking pincode...',
                              style: TextStyle(color: Color(0xFF4B5563))),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        if (_deliveryMessage.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.local_shipping,
                                    color: Color(0xFFFB5404), size: 18),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Estimated Delivery ${_formatDeliveryTime(
                                      _checkedPincodeDuration ??
                                      widget.data['shop_location']?['duration'] ??
                                      widget.data['duration'] ??
                                      widget.data['data']?['duration'] ??
                                      widget.data['product']?['shop_location']?['duration'] ??
                                      widget.data['product']?['duration']
                                    )}',
                                    style: TextStyle(
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_errorMessage.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error,
                                    color: Colors.red.shade600, size: 18),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _errorMessage,
                                    style: TextStyle(
                                        color: Colors.red.shade600,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),

          // Variants Section
          if (variants != null)
            ...variants.entries.map((entry) {
              final String variantKey = entry.key;
              final List<dynamic> variantValues = entry.value as List? ?? [];
              if (variantValues.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 2),
                    child: Text(
                      variantKey,
                      style: const TextStyle(
                        color: Color(0xFF27272A),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 46,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: variantValues.length,
                      itemBuilder: (context, idx) {
                        final item = variantValues[idx];
                        final bool isSelected =
                            widget.data['slug'] == item['slug'];

                        // 1. SIZES LOGIC
                        if (variantKey.toLowerCase() == 'sizes' ||
                            variantKey.toLowerCase() == 'size' ||
                            item['size'] != null) {
                          return GestureDetector(
                            onTap: null,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFEEEEEE)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFF3F4F6)
                                      : const Color(0xFF9CA3AF),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  item['size'] ?? item['name'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                          );
                        }

                        // 2. COLORS LOGIC
                        if (variantKey.toLowerCase() == 'colors' ||
                            variantKey.toLowerCase() == 'color') {
                          final colorValue =
                              item['color_code'] ?? item['color'] ?? '#ccc';
                          final colorName = item['color'] ?? 'Color';
                          final isGradient =
                              colorValue.toString().contains('linear-gradient');
                          final isSelectedColor = isSelected;

                          return GestureDetector(
                            onTap: null,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelectedColor
                                    ? const Color(0xFFFEF6F1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelectedColor
                                      ? const Color(0xFFFB5404)
                                      : const Color(0xFFD1D5DB),
                                  width: isSelectedColor ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: const Color(0xFFE5E7EB),
                                          width: 2),
                                      gradient: isGradient
                                          ? LinearGradient(
                                              colors: _parseGradient(
                                                  colorValue.toString()),
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            )
                                          : null,
                                      color: !isGradient
                                          ? _colorFromHex(colorValue.toString())
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    colorName,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        // 3. IMAGE THUMBNAILS
                        if (item['thumb'] != null) {
                          return GestureDetector(
                            onTap: null,
                            child: Container(
                              width: 44,
                              height: 44,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFFB5404)
                                      : const Color(0xFF9CA3AF),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: Image.network(
                                  'https://d1f02fefkbso7w.cloudfront.net/${item['thumb']}',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.image, size: 20),
                                ),
                              ),
                            ),
                          );
                        }

                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }
}
