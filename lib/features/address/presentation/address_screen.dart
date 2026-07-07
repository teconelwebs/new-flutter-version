import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_routes.dart';

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  static const routeName = AppRoutes.address;

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  List<dynamic> _addresses = [];
  bool _loading = true;
  String _realName = '';

  @override
  void initState() {
    super.initState();
    _getRealName();
    _fetchAddresses();
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

  Future<void> _fetchAddresses() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) {
        setState(() => _loading = false);
        return;
      }

      final uri = Uri.parse(
        'https://welfogapi.welfog.com/api/v2/allAddress/$userId?id=$userId',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == true) {
          final addData = data['addData'] as List? ?? [];
          if (mounted) {
            setState(() {
              _addresses = addData;
              // Address was fetched successfully
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching addresses: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSelectAddress(String id) async {
    final previousAddresses = List.from(_addresses);
    Map<String, dynamic>? selectedAddr;

    // Update local state instantly (Optimistic UI)
    if (mounted) {
      setState(() {
        _addresses = _addresses.map((addr) {
          final addrId = addr['id']?.toString();
          final mutableAddr = Map<String, dynamic>.from(addr as Map);
          if (addrId == id) {
            mutableAddr['using_this'] = 1;
            selectedAddr = mutableAddr;
          } else {
            mutableAddr['using_this'] = 0;
          }
          return mutableAddr;
        }).toList();
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) return;

      // Instantly save coordinate changes locally so subsequent screens use them immediately
      if (selectedAddr != null) {
        await prefs.setString(
          'latitude',
          selectedAddr!['latitude']?.toString() ?? '0',
        );
        await prefs.setString(
          'longitude',
          selectedAddr!['longitude']?.toString() ?? '0',
        );
        await prefs.setString(
          'city_name',
          selectedAddr!['city_name']?.toString() ?? '',
        );
        await prefs.setString(
          'postal_code',
          selectedAddr!['postal_code']?.toString() ?? '',
        );
      }

      final uri = Uri.parse(
        'https://welfogapi.welfog.com/api/v2/selectAnAddress/$id?id=$id&user_id=$userId',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == true) {
          if (selectedAddr != null) {
            await _checkProductPincode(
              selectedAddr!['postal_code']?.toString() ?? '',
            );
          }
          return; // Success
        }
      }

      // If server failed or responded incorrectly, rollback
      _rollbackAddressSelection(previousAddresses);
    } catch (e) {
      debugPrint('Error selecting address: $e');
      _rollbackAddressSelection(previousAddresses);
    }
  }

  void _rollbackAddressSelection(List<dynamic> previous) {
    if (mounted) {
      setState(() {
        _addresses = previous;
      });
      _showCustomPopup('Failed to select address. Please try again.');
    }
  }

  Future<bool> _checkProductPincode(String pincode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final accessToken = prefs.getString('access_token');
      if (userId == null || accessToken == null) return false;

      final userUri = Uri.parse(
        'https://welfogapi.welfog.com/api/v2/get-user-by-access_token',
      );
      final response = await http.post(
        userUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'access_token': accessToken, 'userId': userId}),
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        final addressData = userData['addressData'];
        if (addressData != null && addressData['isService'] != null) {
          final isService = addressData['isService'];
          final status = isService == 1 ? 'true' : 'false';
          await prefs.setString('pincodestatus', status);
          return isService == 1;
        }
      }
      await prefs.setString('pincodestatus', 'false');
      return false;
    } catch (e) {
      debugPrint('Error checking product pincode: $e');
      return false;
    }
  }

  void _showCustomPopup(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 14,
            letterSpacing: 0.3,
          ),
        ),
        // ignore: deprecated_member_use
        backgroundColor: const Color(0xFF1F2937).withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        margin: const EdgeInsets.only(bottom: 12, left: 24, right: 24),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _handleDeleteAddress(String addressId) async {
    Map<String, dynamic>? activeAddress;
    for (var addr in _addresses) {
      if (addr is Map && addr['id']?.toString() == addressId) {
        activeAddress = Map<String, dynamic>.from(addr);
        break;
      }
    }

    if (activeAddress != null && activeAddress['using_this'] == 1) {
      _showCustomPopup('Default address cannot be deleted.');
      return;
    }

    // Start delete transaction

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) return;

      final uri = Uri.parse(
        'https://welfogapi.welfog.com/api/v2/DeleteAddress/$addressId?id=$addressId&user_id=$userId',
      );
      final response = await http.delete(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == true) {
          setState(() {
            _addresses = _addresses
                .where((addr) => addr['id']?.toString() != addressId)
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error deleting address: $e');
    }
  }

  void _showAddressActions(BuildContext context, Map<String, dynamic> address) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        final String addrName = address['name'] ?? '';
        final String displayName =
            (addrName.toLowerCase() == 'user' || addrName.isEmpty) &&
                _realName.isNotEmpty
            ? _realName
            : addrName;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${address['address_details'] ?? ''}, ${address['address'] ?? ''}, ${address['city_name'] ?? ''}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFF0F766E),
                  ),
                  title: const Text('Edit Address'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context)
                        .pushNamed(
                          AppRoutes.editLocation,
                          arguments: {
                            'id': address['id']?.toString(),
                            'latitude': address['latitude']?.toString(),
                            'longitude': address['longitude']?.toString(),
                            'phone': address['phone'] != 'null'
                                ? address['phone']
                                : '',
                            'name': address['name'] != 'null'
                                ? address['name']
                                : '',
                            'addressDetails':
                                address['address_details'] != 'null'
                                ? address['address_details']
                                : '',
                          },
                        )
                        .then((_) => _fetchAddresses());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Delete Address',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleDeleteAddress(address['id']?.toString() ?? '');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Addresses',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F766E)),
            )
          : _addresses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No addresses found.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _addresses.length,
              itemBuilder: (ctx, index) {
                final item = _addresses[index];
                final String addrName = item['name'] ?? '';
                final String displayName =
                    (addrName.toLowerCase() == 'user' || addrName.isEmpty) &&
                        _realName.isNotEmpty
                    ? _realName
                    : addrName;
                final bool isDefault = item['using_this'] == 1;

                return Card(
                  color: Colors.white,
                  elevation: isDefault ? 2 : 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDefault
                          ? const Color(0xFF0F766E)
                          : const Color(0xFFE5E7EB),
                      width: isDefault ? 1.5 : 1,
                    ),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        _handleSelectAddress(item['id']?.toString() ?? ''),
                    child: Stack(
                      children: [
                        if (isDefault)
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFF0F766E),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomRight: Radius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Selected',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.only(
                            left: 16,
                            right: 48,
                            top: isDefault ? 28 : 16,
                            bottom: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${item['address'] ?? ''}${item['city_name'] != null && item['city_name'].toString().isNotEmpty ? ', ${item['city_name']}' : ''}',
                                style: const TextStyle(
                                  color: Color(0xFF4B5563),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                              if (item['address_details'] != null &&
                                  item['address_details'].toString().trim().isNotEmpty &&
                                  item['address_details'].toString().toLowerCase() != 'null') ...[
                                const SizedBox(height: 4),
                                Text(
                                  item['address_details'].toString(),
                                  style: const TextStyle(
                                    color: Color(0xFF4B5563),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                'Phone: ${item['phone'] ?? ''}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.grey,
                            ),
                            onPressed: () => _showAddressActions(context, item),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                // ignore: deprecated_member_use
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.of(context)
                        .pushNamed(AppRoutes.locationPicker)
                        .then((_) => _fetchAddresses());
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9), // Slate 100
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: Color(0xFF475569),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Search Location',
                          style: TextStyle(
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.of(context)
                        .pushNamed(
                          AppRoutes.locationPicker,
                          arguments: {'forceGPS': true},
                        )
                        .then((_) => _fetchAddresses());
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          // ignore: deprecated_member_use
                          color: const Color(0xFF0F766E).withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.my_location_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Detect Location',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
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
