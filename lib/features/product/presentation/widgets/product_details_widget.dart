// lib/features/product/presentation/widgets/product_details_widget.dart
// Converted from: component/ProductDetails.tsx

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_routes.dart';

class ProductDetailsWidget extends StatefulWidget {
  final Map<String, dynamic> data;
  final String pincode;
  final VoidCallback? onRatingTap;
  final Future<void> Function(String slug)? onVariantSelected;

  // ignore: use_super_parameters
  const ProductDetailsWidget({
    Key? key,
    required this.data,
    required this.pincode,
    this.onRatingTap,
    this.onVariantSelected,
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
  bool _showPincodeInput = false;

  int _apiTotalReviews = 0;
  double _apiRating = 0.0;
  int _totalRatings = 0;
  String? _loadingVariantSlug;

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
      final dynamic userId =
          int.tryParse(userIdStr) ?? (userIdStr.isEmpty ? null : userIdStr);

      final shopLocationIdStr = (dynamicShopLocationId ?? '').toString();
      final dynamic shopLocationId = int.tryParse(shopLocationIdStr) ??
          (shopLocationIdStr.isEmpty ? null : shopLocationIdStr);

      final productIdStr = (widget.data['id'] ??
              widget.data['product']?['id'] ??
              widget.data['product_id'] ??
              '')
          .toString();
      final dynamic shopProductId = int.tryParse(productIdStr) ??
          (productIdStr.isEmpty ? null : productIdStr);

      // Parse coordinates to numbers (double) if possible
      final latVal = widget.data['shop_location']?['shop_latitude'] ??
          widget.data['product']?['shop_location']?['shop_latitude'];
      final lngVal = widget.data['shop_location']?['shop_longitude'] ??
          widget.data['product']?['shop_location']?['shop_longitude'];
      final dynamic shopLatitude =
          double.tryParse(latVal?.toString() ?? '') ?? latVal;
      final dynamic shopLongitude =
          double.tryParse(lngVal?.toString() ?? '') ?? lngVal;

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

      final uri =
          Uri.parse('https://welfogapi.welfog.com/api/v2/pincode/check');

      // debugPrint('🔍 Outgoing Pincode Check Payload: ${jsonEncode(payload)}');
      // debugPrint('🔍 Outgoing Headers: $headers');

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(payload),
      );

      // debugPrint('🔍 Response Status Code: ${response.statusCode}');
      // debugPrint('🔍 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == true && mounted) {
          setState(() {
            _deliveryMessage =
                data['message'] ?? 'Product available for delivery';
            _errorMessage = '';
            _checkedPincodeDuration =
                data['duration'] ?? data['data']?['duration'];
            _showPincodeInput = false;
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
      result +=
          '${result.isNotEmpty ? ' ' : ''}$mins min${mins > 1 ? 's' : ''}';
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

  Widget _buildStockBadge(String statusText, Color bgColor, Color borderColor,
      Color textColor, bool isOutOfStock) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isOutOfStock
                  ? Colors.red
                  : (statusText.toLowerCase().contains('only')
                      ? const Color(0xFFEA580C)
                      : const Color(0xFF16A34A)),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
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

    String brandName = '';
    if (rawBrand is String) {
      final trimmed = rawBrand.trim();
      final lower = trimmed.toLowerCase().replaceAll(' ', '');
      if (lower != 'nobrand' && lower != 'non-brand' && lower != 'nonbrand') {
        brandName = trimmed;
      }
    }

    final int stock;
    final stocksList = widget.data['stocks'];
    if (stocksList is List && stocksList.isNotEmpty) {
      final currentId = widget.data['id']?.toString();
      final matchingStock = stocksList.firstWhere(
        (s) => s is Map && s['product_id']?.toString() == currentId,
        orElse: () => null,
      );
      if (matchingStock != null) {
        stock = int.tryParse(matchingStock['qty']?.toString() ?? '0') ?? 0;
      } else {
        stock = int.tryParse(stocksList[0]?['qty']?.toString() ?? '0') ?? 0;
      }
    } else {
      final rawStock =
          widget.data['stock'] ?? widget.data['product']?['stock'] ?? 0;
      stock = int.tryParse(rawStock.toString()) ?? 0;
    }
    final bool isOutOfStock = stock <= 0;

    final String stockStatusText;
    final Color stockBgColor;
    final Color stockBorderColor;
    final Color stockTextColor;

    if (isOutOfStock) {
      stockStatusText = 'Out of Stock';
      stockBgColor = Colors.red.shade50;
      stockBorderColor = Colors.red.shade300;
      stockTextColor = Colors.red.shade600;
    } else if (stock <= 5) {
      stockStatusText = 'Only $stock Left';
      stockBgColor = const Color(0xFFFFF7ED); // amber 50
      stockBorderColor = const Color(0xFFFDBA74); // amber 300
      stockTextColor = const Color(0xFFEA580C); // amber 600
    } else {
      stockStatusText = 'In Stock';
      stockBgColor = const Color(0xFFF0FDF4); // green 50
      stockBorderColor = const Color(0xFF86EFAC); // green 300
      stockTextColor = const Color(0xFF16A34A); // green 600
    }

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
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Brand: $brandName',
                style: const TextStyle(
                  color: Color(0xFF71717A),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // Title
          Padding(
            padding: EdgeInsets.only(top: brandName.isNotEmpty ? 1 : 2),
            child: Text(
              widget.data['name'] ?? widget.data['product']?['name'] ?? '',
              style: const TextStyle(
                color: Color(0xFF2B2B2B),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                height: 1.15,
              ),
            ),
          ),

          // Star rating reviews summary
          if (_apiTotalReviews > 0)
            GestureDetector(
              onTap: widget.onRatingTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Row(
                  children: [
                    Row(
                      children: List.generate(5, (idx) {
                        return Icon(
                          _apiRating >= idx + 1
                              ? Icons.star
                              : (_apiRating > idx
                                  ? Icons.star_half_rounded
                                  : Icons.star_border),
                          color: const Color(0xFFFFB800),
                          size: 14,
                        );
                      }),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_apiRating.toStringAsFixed(1)} · $_totalRatings Ratings & Reviews',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Price info
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '₹$sellPrice',
                            style: const TextStyle(
                              color: Color(0xFF1F2937),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (mrpPrice > sellPrice)
                            Flexible(
                              child: Text(
                                '₹$mrpPrice',
                                style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.lineThrough,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          const SizedBox(width: 8),
                          if (discountPercentage > 0)
                            Text(
                              '$discountPercentage% OFF',
                              style: const TextStyle(
                                color: Color(0xFFFB5404),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStockBadge(stockStatusText, stockBgColor,
                    stockBorderColor, stockTextColor, isOutOfStock),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Inclusive of all taxes',
              style: TextStyle(
                color: Color(0xFF16A34A),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),

          // Check Delivery
          if (_lastCheckedPin.isEmpty) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Check Delivery',
                  style: TextStyle(
                      color: Color(0xFF71717A), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                IntrinsicHeight(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFFB5404), width: 1.2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: TextField(
                              controller: _pincodeController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1F2937)),
                              onChanged: (value) {
                                setState(() {});
                              },
                              decoration: const InputDecoration(
                                hintText: 'Enter Pincode',
                                hintStyle: TextStyle(color: Colors.grey, fontWeight: FontWeight.normal),
                                counterText: '',
                                contentPadding: EdgeInsets.symmetric(vertical: 14),
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
                          onTap: isCheckDisabled || _checkingDelivery
                              ? null
                              : () => _checkDelivery(_pincodeController.text),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFEF2EB), // peach background
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(23),
                                bottomRight: Radius.circular(23),
                              ),
                              border: Border(
                                left: BorderSide(color: Color(0xFFE5E7EB), width: 1.2),
                              ),
                            ),
                            child: Text(
                              _checkingDelivery ? 'Checking...' : 'Apply',
                              style: const TextStyle(
                                color: Color(0xFFFB5404),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
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
          ] else ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Divider stretched edge-to-edge
                Builder(
                  builder: (context) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    return Transform.scale(
                      scaleX: screenWidth / (screenWidth - 40),
                      child: const Divider(
                          color: Color(0xFFE5E7EB), height: 1, thickness: 1),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2EB), // peach background
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Color(0xFFFB5404),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Deliver to',
                              style: TextStyle(
                                color: Color(0xFF71717A),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _lastCheckedPin,
                              style: const TextStyle(
                                color: Color(0xFF1F2937),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showPincodeInput = !_showPincodeInput;
                            if (_showPincodeInput) {
                              _pincodeController.text = _lastCheckedPin;
                            } else {
                              _pincodeController.clear();
                            }
                          });
                        },
                        child: _showPincodeInput
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFB5404), // solid orange
                                  borderRadius: BorderRadius.circular(20), // pill shape
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFFB5404)),
                                ),
                                child: const Text(
                                  'Change',
                                  style: TextStyle(
                                    color: Color(0xFFFB5404),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                if (_showPincodeInput) ...[
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFFB5404), width: 1.2),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 20),
                              child: TextField(
                                controller: _pincodeController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1F2937)),
                                onChanged: (value) {
                                  setState(() {});
                                },
                                decoration: const InputDecoration(
                                  hintText: 'Enter Pincode',
                                  hintStyle: TextStyle(color: Colors.grey, fontWeight: FontWeight.normal),
                                  counterText: '',
                                  contentPadding: EdgeInsets.symmetric(vertical: 14),
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
                            onTap: isCheckDisabled || _checkingDelivery
                                ? null
                                : () => _checkDelivery(_pincodeController.text),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 28),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFEF2EB), // peach background
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(23),
                                  bottomRight: Radius.circular(23),
                                ),
                                border: Border(
                                  left: BorderSide(color: Color(0xFFE5E7EB), width: 1.2),
                                ),
                              ),
                              child: Text(
                                _checkingDelivery ? 'Checking...' : 'Apply',
                                style: const TextStyle(
                                  color: Color(0xFFFB5404),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_deliveryMessage.isNotEmpty) ...[
                  const SizedBox(
                      height: 6), // slightly increased vertical space
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 6), // slightly increased vertical padding
                    color: Colors.transparent,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_shipping_outlined,
                          color: Color(0xFFFB5404),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Estimated Delivery ${_formatDeliveryTime(_checkedPincodeDuration ?? widget.data['shop_location']?['duration'] ?? widget.data['duration'] ?? widget.data['data']?['duration'] ?? widget.data['product']?['shop_location']?['duration'] ?? widget.data['product']?['duration'])}',
                            style: const TextStyle(
                              color: Color(0xFF15803D), // green color
                              fontWeight: FontWeight.w500, // less bold
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                // Bottom Divider stretched edge-to-edge
                Builder(
                  builder: (context) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    return Transform.scale(
                      scaleX: screenWidth / (screenWidth - 40),
                      child: const Divider(
                          color: Color(0xFFE5E7EB), height: 1, thickness: 1),
                    );
                  },
                ),
              ],
            ),
          ],

          // Pincode check responses (outside)
          if (_checkingDelivery ||
              (_errorMessage.isNotEmpty && _lastCheckedPin.isEmpty))
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
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
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
            ),

          // Variants Section
          if (variants != null)
            ...(() {
              final list = variants.entries.where((entry) {
                final key = entry.key
                    .toLowerCase()
                    .replaceAll(RegExp(r'[\s_-]'), '')
                    .replaceAll('colour', 'color');
                return key != 'colorsizes' && key != 'colorsize';
              }).toList();

              // Sort list: put color first, size second
              list.sort((a, b) {
                final aKey = a.key.toLowerCase();
                final bKey = b.key.toLowerCase();
                final aIsColor =
                    aKey.contains('color') || aKey.contains('colour');
                final bIsColor =
                    bKey.contains('color') || bKey.contains('colour');

                if (aIsColor && !bIsColor) return -1;
                if (!aIsColor && bIsColor) return 1;
                return 0;
              });

              return list;
            }())
                .map((entry) {
              final String variantKey = entry.key;
              final rawVal = entry.value;
              final List<dynamic> variantValues = [];
              if (rawVal is List) {
                variantValues.addAll(rawVal);
              } else if (rawVal is Map) {
                variantValues.addAll(rawVal.values);
              }
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
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: variantValues.length,
                      itemBuilder: (context, idx) {
                        final rawItem = variantValues[idx];
                        if (rawItem == null) return const SizedBox.shrink();
                        final Map<String, dynamic> item = rawItem is Map
                            ? Map<String, dynamic>.from(rawItem)
                            : {
                                'slug': rawItem.toString(),
                                'size': rawItem.toString(),
                                'color': rawItem.toString(),
                                'color_code': '#ccc',
                              };
                        final bool isSelected =
                            widget.data['slug'] == item['slug'];

                        // 1. SIZES LOGIC
                        if (variantKey.toLowerCase() == 'sizes' ||
                            variantKey.toLowerCase() == 'size' ||
                            item['size'] != null) {
                          return GestureDetector(
                            onTap: () async {
                              final targetSlug = item['slug']?.toString();
                              if (targetSlug != null &&
                                  targetSlug.isNotEmpty &&
                                  targetSlug != widget.data['slug']) {
                                if (widget.onVariantSelected != null) {
                                  setState(() {
                                    _loadingVariantSlug = targetSlug;
                                  });
                                  try {
                                    await widget.onVariantSelected!(targetSlug);
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _loadingVariantSlug = null;
                                      });
                                    }
                                  }
                                } else {
                                  Navigator.of(context).pushReplacementNamed(
                                    AppRoutes.product,
                                    arguments: targetSlug,
                                  );
                                }
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFEF6F1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFFB5404)
                                      : const Color(0xFFD1D5DB),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Center(
                                child: _loadingVariantSlug == item['slug']
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.0,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Color(0xFFFB5404)),
                                        ),
                                      )
                                    : Text(
                                        item['size'] ?? item['name'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? const Color(0xFFFB5404)
                                              : const Color(0xFF1F2937),
                                        ),
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
                            onTap: () async {
                              final targetSlug = item['slug']?.toString();
                              if (targetSlug != null &&
                                  targetSlug.isNotEmpty &&
                                  targetSlug != widget.data['slug']) {
                                if (widget.onVariantSelected != null) {
                                  setState(() {
                                    _loadingVariantSlug = targetSlug;
                                  });
                                  try {
                                    await widget.onVariantSelected!(targetSlug);
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _loadingVariantSlug = null;
                                      });
                                    }
                                  }
                                } else {
                                  Navigator.of(context).pushReplacementNamed(
                                    AppRoutes.product,
                                    arguments: targetSlug,
                                  );
                                }
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelectedColor
                                    ? const Color(0xFFFEF6F1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelectedColor
                                      ? const Color(0xFFFB5404)
                                      : const Color(0xFFD1D5DB),
                                  width: isSelectedColor ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (_loadingVariantSlug == item['slug']) ...[
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.0,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Color(0xFFFB5404)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ] else ...[
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
                                            ? _colorFromHex(
                                                colorValue.toString())
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
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
                            onTap: () async {
                              final targetSlug = item['slug']?.toString();
                              if (targetSlug != null &&
                                  targetSlug.isNotEmpty &&
                                  targetSlug != widget.data['slug']) {
                                if (widget.onVariantSelected != null) {
                                  setState(() {
                                    _loadingVariantSlug = targetSlug;
                                  });
                                  try {
                                    await widget.onVariantSelected!(targetSlug);
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _loadingVariantSlug = null;
                                      });
                                    }
                                  }
                                } else {
                                  Navigator.of(context).pushReplacementNamed(
                                    AppRoutes.product,
                                    arguments: targetSlug,
                                  );
                                }
                              }
                            },
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
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Image.network(
                                        'https://d1f02fefkbso7w.cloudfront.net/${item['thumb']}',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.image, size: 20),
                                      ),
                                    ),
                                    if (_loadingVariantSlug == item['slug'])
                                      Container(
                                        color: Colors.black38,
                                        child: const Center(
                                          child: SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.0,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Color(0xFFFB5404)),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
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
