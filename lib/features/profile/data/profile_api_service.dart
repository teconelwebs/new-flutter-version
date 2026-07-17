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

  Future<String?> updateProfileName({
    required String userId,
    required String accessToken,
    required String name,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/profile/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'id': userId,
          'name': name,
        }),
      );

      if (response.statusCode == 200) return null;
      return 'Profile update failed (${response.statusCode})';
    } catch (e) {
      return 'Profile update failed: $e';
    }
  }

  String _formatDobForDisplay(String raw) {
    if (raw.isEmpty) return '';

    // Check if it's an ISO timestamp with timezone information (contains T and Z/+/offset)
    if (raw.contains('T') && (raw.contains('Z') || raw.contains('+') || raw.contains('-'))) {
      try {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) {
          final localDate = parsed.toLocal();
          final day = localDate.day.toString().padLeft(2, '0');
          final month = localDate.month.toString().padLeft(2, '0');
          return '$day-$month-${localDate.year}';
        }
      } catch (_) {}
    }

    // Fallback: extract date part and format without shifting timezones
    final datePart = raw.split('T').first.split(' ').first;
    final parts = datePart.split('-');
    if (parts.length == 3) {
      if (parts[0].length == 4) {
        return '${parts[2]}-${parts[1]}-${parts[0]}';
      }
      if (parts[2].length == 4) {
        return '${parts[0]}-${parts[1]}-${parts[2]}';
      }
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
