// lib/features/checkout/presentation/widgets/checkout_address_widget.dart
// Converted from: component/sections/Address.tsx

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class CheckoutAddressWidget extends StatefulWidget {
  final int refreshing;
  final ValueChanged<String>? onAddressChange;
  final ValueChanged<String>? onAddressIdChange;
  final ValueChanged<Map<String, dynamic>>? onAddressDataChange;

  // ignore: use_super_parameters
  const CheckoutAddressWidget({
    Key? key,
    required this.refreshing,
    this.onAddressChange,
    this.onAddressIdChange,
    this.onAddressDataChange,
  }) : super(key: key);

  @override
  State<CheckoutAddressWidget> createState() => _CheckoutAddressWidgetState();
}

class _CheckoutAddressWidgetState extends State<CheckoutAddressWidget> {
  String _selectedAddress = '';
  List<dynamic> _addresses = [];
  bool _loading = false;
  String _realName = '';

  @override
  void initState() {
    super.initState();
    _getRealName();
    _fetchAddresses(showShimmer: true);
  }

  @override
  void didUpdateWidget(CheckoutAddressWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshing != widget.refreshing) {
      _fetchAddresses(showShimmer: _addresses.isEmpty);
    }
  }

  Future<void> _getRealName() async {
    final prefs = await SharedPreferences.getInstance();
    final name1 = prefs.getString('user_name');
    final name2 = prefs.getString('loginuser');
    final actual = name1 ?? name2 ?? '';

    if (actual.isNotEmpty &&
        actual.toLowerCase() != 'user' &&
        actual.toLowerCase() != 'null') {
      if (mounted) setState(() => _realName = actual);
    }
  }

  Future<void> _fetchAddresses({bool showShimmer = true}) async {
    if (showShimmer) {
      setState(() => _loading = true);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) return;

      final uri = Uri.parse('https://welfogapi.welfog.com/api/allAddress/$userId?id=$userId');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == true) {
          final addData = data['addData'] as List? ?? [];
          if (mounted) {
            setState(() {
              _addresses = addData;
            });
          }

          final defaultAddress = addData.firstWhere(
            (addr) => addr['using_this'] == 1,
            orElse: () => null,
          );

          if (defaultAddress != null) {
            final postalCode = defaultAddress['postal_code']?.toString() ?? '';
            final addrId = defaultAddress['id']?.toString() ?? '';

            if (mounted) {
              setState(() {
                _selectedAddress = addrId;
              });
            }

            _checkProductPincode(postalCode);

            if (widget.onAddressChange != null) widget.onAddressChange!(postalCode);
            if (widget.onAddressIdChange != null) widget.onAddressIdChange!(addrId);
            if (widget.onAddressDataChange != null) {
              widget.onAddressDataChange!(Map<String, dynamic>.from(defaultAddress));
            }
          } else if (addData.isNotEmpty) {
            final firstAddr = addData[0];
            final postalCode = firstAddr['postal_code']?.toString() ?? '';
            final addrId = firstAddr['id']?.toString() ?? '';

            if (mounted) {
              setState(() {
                _selectedAddress = addrId;
              });
            }

            if (widget.onAddressChange != null) widget.onAddressChange!(postalCode);
            if (widget.onAddressIdChange != null) widget.onAddressIdChange!(addrId);
            if (widget.onAddressDataChange != null) {
              widget.onAddressDataChange!(Map<String, dynamic>.from(firstAddr));
            }
          }
        }
      }
    } catch (error) {
      debugPrint('Error fetching addresses: $error');
    } finally {
      if (showShimmer && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<bool> _checkProductPincode(String pincode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final accessToken = prefs.getString('access_token');

      if (userId == null || accessToken == null) return false;

      final uri = Uri.parse('https://welfogapi.welfog.com/api/pincode/check');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'user_id': userId,
          'pincode': pincode,
          'shop_latitude': '',
          'shop_longitude': '',
          'shop_location_id': '',
          'shop_product_id': '',
        }),
      );

      if (response.statusCode == 200) {
        final pincodeResult = jsonDecode(response.body);
        final status = pincodeResult['result'] == true ? 'true' : 'false';
        await prefs.setString('pincodestatus', status);
        return status == 'true';
      }
      return false;
    } catch (error) {
      debugPrint('Error checking pincode: $error');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF008083))),
      );
    }

    final currentAddress = _addresses.firstWhere(
      (item) => item['id']?.toString() == _selectedAddress,
      orElse: () => null,
    );

    if (currentAddress == null) {
      return const SizedBox(height: 10);
    }

    final String addrName = currentAddress['name'] ?? '';
    final String displayName = (addrName.toLowerCase() == 'user' || addrName.isEmpty) && _realName.isNotEmpty
        ? _realName
        : addrName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            // Top borderline replacement
            Container(
              height: 1,
              color: const Color(0xFFF6F6F6),
            ),

            // DEFAULT tag
            if (currentAddress['using_this'] == 1)
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFEF4),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'DEFAULT',
                    style: TextStyle(
                      color: Color(0xFF16A34A),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),

            // Address Details Content
            Padding(
              padding: const EdgeInsets.only(right: 82, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${currentAddress['address_details'] ?? ''}, ${currentAddress['address'] ?? ''}, ${currentAddress['city_name'] ?? ''}, ${currentAddress['state_name'] ?? ''} - ${currentAddress['postal_code'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF374151),
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mobile: ${currentAddress['phone'] != null && currentAddress['phone'] != 'null' ? currentAddress['phone'] : 'Not Found'}',
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const Divider(color: Color(0xFFF9FAFB), height: 30, thickness: 1),

        // Edit Address button
        GestureDetector(
          onTap: () {
            Navigator.of(context).pushNamed(
              '/page/EditLocation',
              arguments: {
                'id': currentAddress['id'],
                'latitude': currentAddress['latitude'],
                'longitude': currentAddress['longitude'],
                'phone': currentAddress['phone'] != 'null' ? currentAddress['phone'] : '',
                'name': currentAddress['name'] != 'null' ? currentAddress['name'] : '',
                'addressDetails': currentAddress['address_details'] != 'null' ? currentAddress['address_details'] : '',
              },
            );
          },
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_outlined, size: 15, color: Color(0xFF0F172A)),
                SizedBox(width: 6),
                Text(
                  'Edit Address',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
