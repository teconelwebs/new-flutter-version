import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AccountApiService {
  static const String _mainApi = 'https://welfogapi.welfog.com/api/v2';

  Future<AccountUser?> fetchUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    final userId = prefs.getString('user_id') ?? '';
    if (token.isEmpty || userId.isEmpty) return null;

    final uri = Uri.parse('$_mainApi/get-user-by-access_token');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'access_token': token, 'userId': userId}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    final ok = decoded['result'] == true;
    if (!ok) return null;
    return AccountUser(
      userId: userId,
      name: (decoded['name'] ?? '').toString(),
      phone: (decoded['phone'] ?? '').toString(),
      email: (decoded['email'] ?? '').toString(),
    );
  }
}

class AccountUser {
  const AccountUser({
    required this.userId,
    required this.name,
    required this.phone,
    required this.email,
  });

  final String userId;
  final String name;
  final String phone;
  final String email;
}
