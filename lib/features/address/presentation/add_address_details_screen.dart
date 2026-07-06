import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class AddAddressDetailsScreen extends StatefulWidget {
  final String mode; // 'add' or 'edit'

  // Arguments for 'edit' mode
  final String editAddressId;
  final String editLatitude;
  final String editLongitude;
  final String editName;
  final String editPhone;
  final String editAddressDetails;

  // Arguments for 'add' mode
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String country;

  const AddAddressDetailsScreen({
    super.key,
    required this.mode,
    this.editAddressId = '',
    this.editLatitude = '',
    this.editLongitude = '',
    this.editName = '',
    this.editPhone = '',
    this.editAddressDetails = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.country = '',
  });

  @override
  State<AddAddressDetailsScreen> createState() =>
      _AddAddressDetailsScreenState();
}

class _AddAddressDetailsScreenState extends State<AddAddressDetailsScreen> {
  final _addressDetailsController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  String _addressText = '';
  String _cityText = '';
  String _stateText = '';
  String _pincodeText = '';
  String _countryText = '';
  String _latitudeText = '';
  String _longitudeText = '';

  bool _isSaving = false;
  String? _addressError;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    final prefs = await SharedPreferences.getInstance();

    _addressText = widget.address;
    _cityText = widget.city;
    _stateText = widget.state;
    _pincodeText = widget.pincode;
    _countryText = widget.country;

    _latitudeText = prefs.getString('latitude') ?? '0';
    _longitudeText = prefs.getString('longitude') ?? '0';

    if (widget.mode == 'edit') {
      _nameController.text = widget.editName;
      _phoneController.text = widget.editPhone;
      _addressDetailsController.text = widget.editAddressDetails;
    } else {
      // Create mode
      final localName = prefs.getString('user_name') ?? '';
      final localLoginUser = prefs.getString('loginuser') ?? '';
      final defaultName = localName.isNotEmpty ? localName : localLoginUser;
      if (defaultName.isNotEmpty && defaultName.toLowerCase() != 'user') {
        _nameController.text = defaultName;
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _addressDetailsController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    setState(() {
      _addressError = null;
      _phoneError = null;
    });

    final details = _addressDetailsController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    bool hasError = false;

    if (details.isEmpty) {
      setState(() => _addressError = 'Address details are required*');
      hasError = true;
    }

    if (phone.isEmpty) {
      setState(() => _phoneError = 'Phone number is required*');
      hasError = true;
    } else if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      setState(() => _phoneError = 'Number must be exactly 10 digits');
      hasError = true;
    } else if (RegExp(r'^(\d)\1{9}$').hasMatch(phone)) {
      setState(() => _phoneError = 'Please enter a valid mobile number');
      hasError = true;
    }

    if (hasError) return;

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final accessToken = prefs.getString('access_token');
      final tempUserId = prefs.getString('temp_user_id') ?? '';

      if (userId == null || accessToken == null) {
        setState(() => _isSaving = false);
        return;
      }

      final payload = {
        'user_id': userId,
        'mapData': [
          'Latitude: $_latitudeText',
          'Longitude: $_longitudeText',
          'City: $_cityText',
          'State: $_stateText',
          'Country: $_countryText',
          'Pincode: $_pincodeText',
          'Address: $_addressText',
        ],
        'addressDetails': details,
        'address_id_edit': widget.mode == 'edit' ? widget.editAddressId : '',
        'accessToken': accessToken,
        'temp_user_id': tempUserId,
        'addressname': name,
        'addressphone': phone,
      };

      final uri = Uri.parse('https://welfogapi.welfog.com/api/v2/mapAddress');
      debugPrint('Save address payload: ${jsonEncode(payload)}');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(payload),
      );
      debugPrint('Save address response code: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200) {
        // Run serviceability check
        await _checkProductPincode(_pincodeText);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Address saved successfully'),
              backgroundColor: Color(0xFF0F766E),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save address: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving address: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _checkProductPincode(String pincode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final accessToken = prefs.getString('access_token');
      if (userId == null || accessToken == null) return;

      final userUri = Uri.parse(
          'https://welfogapi.welfog.com/api/v2/get-user-by-access_token');
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
        }
      }
    } catch (e) {
      debugPrint('Error syncing pincode serviceability: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.mode == 'edit' ? 'Edit Address Details' : 'Enter Address Details',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Address Details Field
            const Text(
              'Address Details',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addressDetailsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Eg: Plot No., Street, Colony',
                errorText: _addressError,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),

            // Name Field
            const Text(
              'Full Name',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter your name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),

            // Phone Field
            const Text(
              'Phone Number',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                hintText: 'Enter phone number',
                errorText: _phoneError,
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 24),

            const Divider(),
            const SizedBox(height: 12),
            _buildReadOnlyField('Address', _addressText),
            _buildReadOnlyField('City', _cityText),
            _buildReadOnlyField('State', _stateText),
            _buildReadOnlyField('Pincode', _pincodeText),
            _buildReadOnlyField('Country', _countryText),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSaving ? null : _saveAddress,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Save Address',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              value,
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
