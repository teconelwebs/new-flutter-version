import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProfileApiService {
  static const _baseUrl = 'https://welfogapi.welfog.com/api/v2';

  Future<ShopProfile?> fetchProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    final userId = prefs.getString('user_id') ?? '';
    if (token.isEmpty || userId.isEmpty) return null;

    final response = await http.post(
      Uri.parse('$_baseUrl/get-user-by-access_token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'access_token': token, 'userId': userId}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> || body['result'] != true) return null;

    final localName = prefs.getString('user_name') ?? '';
    final apiName = (body['name'] ?? '').toString();
    final name = (apiName.toLowerCase() == 'user' || apiName.isEmpty) &&
            localName.isNotEmpty
        ? localName
        : apiName;

    return ShopProfile(
      userId: userId,
      name: name,
      phone: (body['phone'] ?? '').toString(),
      email: (body['email'] ?? '').toString(),
      dob: _formatDobForDisplay((body['dob'] ?? '').toString()),
      gender: (body['gender'] ?? '').toString(),
      maritalStatus: (body['marital_status'] ?? '').toString(),
    );
  }

  Future<String?> updateProfile({
    required String userId,
    required String accessToken,
    required String name,
    required String email,
    required String dobDisplay,
    required String gender,
    required String maritalStatus,
  }) async {
    final apiDate = _formatDobForApi(dobDisplay);

    final response = await http.post(
      Uri.parse('$_baseUrl/profile/update'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'id': userId,
        'name': name,
        'email': email,
        'dob': apiDate,
        'gender': gender,
        'marital_status': maritalStatus,
      }),
    );

    if (response.statusCode == 200) return null;
    return 'Profile update failed (${response.statusCode})';
  }

  String _formatDobForDisplay(String raw) {
    if (raw.isEmpty) return '';
    final datePart = raw.split('T').first;
    final parts = datePart.split('-');
    if (parts.length == 3) {
      return '${parts[2]}-${parts[1]}-${parts[0]}';
    }
    return raw;
  }

  String _formatDobForApi(String display) {
    if (display.isEmpty) return '';
    final parts = display.split('-');
    if (parts.length == 3) {
      return '${parts[2]}-${parts[1]}-${parts[0]}';
    }
    return display;
  }
}

class ShopProfile {
  const ShopProfile({
    required this.userId,
    required this.name,
    required this.phone,
    required this.email,
    required this.dob,
    required this.gender,
    required this.maritalStatus,
  });

  final String userId;
  final String name;
  final String phone;
  final String email;
  final String dob;
  final String gender;
  final String maritalStatus;
}
