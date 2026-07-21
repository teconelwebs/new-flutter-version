import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_routes.dart';

class SupplierInfoScreen extends StatefulWidget {
  const SupplierInfoScreen({super.key});

  @override
  State<SupplierInfoScreen> createState() => _SupplierInfoScreenState();
}

class _SupplierInfoScreenState extends State<SupplierInfoScreen> {
  bool _loading = true;
  bool _isConnected = false;
  Map<String, dynamic>? _supplierProfile;

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
  }

  Future<void> _checkConnectionStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var profileId = prefs.getString('play_profile_id') ?? '';
      var loginId = prefs.getString('loginid') ?? '';

      if (profileId == 'null') profileId = '';
      if (loginId == 'null') loginId = '';

      var idToCheck = profileId.isNotEmpty ? profileId : loginId;
      var deviceId = prefs.getString('x-device-id') ?? '';
      if (deviceId.isEmpty) {
        deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('x-device-id', deviceId);
      }

      final headers = {
        'Content-Type': 'application/json',
        'x-device-id': deviceId,
        'x-android-id': deviceId,
        'x-ios-idfv': deviceId,
      };

      // 1. Resolve user profile if local cache was cleared or is missing
      if (idToCheck.isEmpty) {
        final currentUserId = prefs.getString('user_id') ?? '';
        final token = prefs.getString('access_token') ?? '';

        if (currentUserId.isNotEmpty && token.isNotEmpty) {
          final userRes = await http.post(
            Uri.parse('https://welfogapi.welfog.com/api/v2/get-user-by-access_token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'access_token': token, 'userId': currentUserId}),
          ).timeout(const Duration(seconds: 4));

          if (userRes.statusCode == 200) {
            final userData = jsonDecode(userRes.body);
            final mobile = userData['phone'] ?? userData['mobile'] ?? '';
            if (mobile != null && mobile.toString().isNotEmpty) {
              final mobileRes = await http.get(
                Uri.parse('https://api.welfog.com/api/users/bymobile/$mobile'),
                headers: headers,
              ).timeout(const Duration(seconds: 4));

              if (mobileRes.statusCode == 200) {
                final data = jsonDecode(mobileRes.body);
                if (data != null && (data['_id'] != null || data['id'] != null)) {
                  idToCheck = (data['_id'] ?? data['id']).toString();
                  await prefs.setString('play_profile_id', idToCheck);
                }
              }
            }
          }
        }
      }

      // 2. Fetch profile from the backend server directly to verify linked supplier status
      if (idToCheck.isNotEmpty) {
        Map<String, dynamic>? userData;

        try {
          final res = await http.get(
            Uri.parse('https://api.welfog.com/api/users/$idToCheck'),
            headers: headers,
          ).timeout(const Duration(seconds: 4));

          if (res.statusCode == 200) {
            final decoded = jsonDecode(res.body);
            if (decoded is Map<String, dynamic> && decoded['message'] != 'User not found') {
              userData = decoded;
            }
          }
        } catch (_) {}

        // Try userpost endpoint as a fallback if direct lookup is not successful (e.g. when idToCheck is a Mongo ObjectId)
        if (userData == null) {
          try {
            final userpostRes = await http.get(
              Uri.parse('https://api.welfog.com/api/users/userpost/$idToCheck'),
              headers: headers,
            ).timeout(const Duration(seconds: 4));

            if (userpostRes.statusCode == 200) {
              final decoded = jsonDecode(userpostRes.body);
              if (decoded is Map<String, dynamic> && decoded['user'] is Map<String, dynamic>) {
                userData = decoded['user'] as Map<String, dynamic>;
              }
            }
          } catch (_) {}
        }

        if (userData != null) {
          final rawSellerId = userData['seller_id']?.toString() ?? userData['sellerId']?.toString();
          final rawUserSellerId = userData['userseller_id']?.toString() ?? userData['usersellerId']?.toString();
          
          final sellerIdValid = rawSellerId != null &&
              rawSellerId.isNotEmpty &&
              rawSellerId != 'null' &&
              rawSellerId != 'undefined';
              
          final userSellerIdValid = rawUserSellerId != null &&
              rawUserSellerId.isNotEmpty &&
              rawUserSellerId != 'null' &&
              rawUserSellerId != 'undefined';

          final isConnected = userData['isConnected'] == true ||
              userData['isConnected'] == 'true' ||
              userData['is_connected'] == true ||
              userData['is_connected'] == 'true' ||
              sellerIdValid ||
              userSellerIdValid;

          if (isConnected) {
            // Prioritize userseller_id since it points directly to the seller user ID (e.g. 1116)
            final targetSellerUserId = userSellerIdValid ? rawUserSellerId : rawSellerId;
            if (targetSellerUserId != null && targetSellerUserId.isNotEmpty) {
              await _fetchSupplierDetails(targetSellerUserId);
              return;
            }
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _loading = false;
        _isConnected = false;
      });
    }
  }

  Future<void> _fetchSupplierDetails(String sellerUserId) async {
    try {
      final res = await http.get(
        Uri.parse('https://welfogapi.welfog.com/api/v2/supplier/$sellerUserId'),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(res.body);
        if (decoded['result'] == true && decoded['data'] != null) {
          if (mounted) {
            setState(() {
              _supplierProfile = Map<String, dynamic>.from(decoded['data']);
              _isConnected = true;
              _loading = false;
            });
          }
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isConnected = false;
        _loading = false;
      });
    }
  }

  String _resolveImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return 'https://d1f02fefkbso7w.cloudfront.net/$path';
  }

  void _requestCameraAndNavigate(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.connectSupplier);
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF6A00),
          ),
        ),
      );
    }

    final size = MediaQuery.sizeOf(context);

    // Connected Supplier data extraction
    final profile = _supplierProfile;
    final user = profile?['user'] as Map<String, dynamic>? ?? {};
    final supplier = profile?['supplier'] as Map<String, dynamic>? ?? {};
    final shop = profile?['shop'] as Map<String, dynamic>? ?? {};

    final shopId = (shop['id'] ?? '').toString();
    final slug = (shop['slug'] ?? '').toString();
    final shopName = shop['name']?.toString() ?? supplier['shop_name']?.toString() ?? 'Supplier Shop';
    final sellerName = user['name']?.toString() ?? 'Seller';
    final supplierId = (supplier['id'] ?? '').toString();
    final logoPath = shop['logo']?.toString() ?? '';
    final logoUrl = _resolveImageUrl(logoPath);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Custom Header Back Button
              Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 24),
                ),
              ),

              // Main content area - scrollable so it works on all screen sizes and sits at the top (container upar)
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        // Shop logo / graphic
                        _isConnected && profile != null
                            ? GestureDetector(
                                onTap: () {
                                  if (shopId.isNotEmpty && slug.isNotEmpty) {
                                    Navigator.of(context).pushNamed(
                                      AppRoutes.shop,
                                      arguments: {
                                        'id': shopId,
                                        'slug': slug,
                                        'shop_id': shopId,
                                      },
                                    );
                                  }
                                },
                                  child: Hero(
                                  tag: 'shop_logo_hero',
                                  child: Container(
                                    width: size.width * 0.48,
                                    height: size.width * 0.48,
                                    decoration: BoxDecoration(
                                      color: Colors.white, // Keep background color white
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFFF6A00), width: 3),
                                      boxShadow: [
                                        BoxShadow(
                                          // ignore: deprecated_member_use
                                          color: const Color(0xFFFF6A00).withOpacity(0.15),
                                          blurRadius: 15,
                                          spreadRadius: 2,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: logoUrl.isNotEmpty
                                          ? Image.network(
                                              logoUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Image.asset(
                                                'assets/images/shop_default_logo.png',
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : Image.asset(
                                              'assets/images/shop_default_logo.png',
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                  ),
                                ),
                              )
                            : Image.asset(
                                'assets/images/IMG.png',
                                width: size.width * 0.65,
                                height: size.width * 0.65,
                                fit: BoxFit.contain,
                              ),
                        
                        const SizedBox(height: 24),

                        // Title and Description / Connected Details
                        _isConnected && profile != null
                            ? Column(
                                children: [
                                  Text(
                                    shopName,
                                    style: TextStyle(
                                      fontSize: size.width * 0.06,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF111111),
                                      height: 1.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE5E7EB)),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildDetailRow('Supplier ID', supplierId),
                                        const SizedBox(height: 10),
                                        _buildDetailRow('Shop Name', shopName),
                                        const SizedBox(height: 10),
                                        _buildDetailRow('Supplier Name', sellerName),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  Text(
                                    'Connect with Supplier',
                                    style: TextStyle(
                                      fontSize: size.width * 0.06,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF111111),
                                      height: 1.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Scan the supplier\u2019s QR code to sync videos and easily use them in your product listings.',
                                    style: TextStyle(
                                      fontSize: size.width * 0.04,
                                      color: const Color(0xFF555555),
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                // ignore: deprecated_member_use
                                color: const Color(0xFFFF6A00).withOpacity(0.3),
                                offset: const Offset(0, 8),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (_isConnected && profile != null) {
                                if (shopId.isNotEmpty && slug.isNotEmpty) {
                                  Navigator.of(context).pushNamed(
                                    AppRoutes.shop,
                                    arguments: {
                                      'id': shopId,
                                      'slug': slug,
                                      'shop_id': shopId,
                                    },
                                  );
                                }
                              } else {
                                _requestCameraAndNavigate(context);
                              }
                            },
                            icon: Icon(
                              _isConnected ? Icons.storefront_rounded : Icons.qr_code_scanner_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            label: Text(
                              _isConnected ? 'Go to Seller Shop' : 'Continue to Scan',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6A00),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
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
}
