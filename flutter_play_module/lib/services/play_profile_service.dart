import 'dart:convert';

import 'package:http/http.dart' as http;

const _fourthBaseUrl = 'https://api.welfog.com/api';

class PlayProfileService {
  const PlayProfileService({required this.deviceId});

  final String deviceId;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (deviceId.isNotEmpty) 'x-android-id': deviceId,
      };

  Future<String> createPlayProfile({
    required String mainUserId,
    required String mobile,
    required String username,
    String name = '',
  }) async {
    final trimmed = username.trim();
    try {
      return await _postCreate(mainUserId, mobile, trimmed, name: name);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('(409)') || msg.contains('(400)')) {
        return _createWithExistingMobile(mainUserId, mobile, trimmed, name: name);
      }
      rethrow;
    }
  }

  Future<String> _postCreate(
    String mainUserId,
    String mobile,
    String username, {
    String name = '',
  }) async {
    final response = await http.post(
      Uri.parse('$_fourthBaseUrl/users/'),
      headers: _headers,
      body: jsonEncode({
        'userid': mainUserId,
        'username': username,
        'mobile': mobile,
        'name': name.isNotEmpty ? name : username,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to create profile (${response.statusCode})');
    }

    final body = jsonDecode(response.body);
    if (body is! Map) throw Exception('Invalid create profile response');
    final id = body['_id']?.toString();
    if (id == null || id.isEmpty) {
      throw Exception('Failed to create profile: missing id');
    }
    return id;
  }

  Future<String> _createWithExistingMobile(
    String mainUserId,
    String mobile,
    String username, {
    String name = '',
  }) async {
    final lookup = await http.get(
      Uri.parse('$_fourthBaseUrl/users/bymobile/$mobile'),
      headers: _headers,
    );
    if (lookup.statusCode < 200 || lookup.statusCode >= 300) {
      throw Exception('Failed to resolve existing profile (${lookup.statusCode})');
    }

    final existing = jsonDecode(lookup.body);
    if (existing is! Map) throw Exception('Invalid profile lookup response');
    final existingId = existing['_id']?.toString();
    if (existingId == null || existingId.isEmpty) {
      throw Exception('Profile not found for this mobile');
    }

    try {
      await http.put(
        Uri.parse('$_fourthBaseUrl/users/$existingId'),
        headers: _headers,
        body: jsonEncode({
          'name': name.isNotEmpty ? name : (existing['name'] ?? ''),
          'username': username,
          'email': existing['email'] ?? '',
          'mobile': existing['mobile'] ?? mobile,
          'bio': existing['bio'] ?? '',
          'profilePicture': existing['profilePicture'] ?? '',
        }),
      );
    } catch (_) {
      // Continue with existing user id if update fails.
    }

    return existingId;
  }
}
