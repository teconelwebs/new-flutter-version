import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:welfog_flutter_play/welfog_flutter_play.dart' as play;

class SessionStore {
  static const _kIsLoggedIn = 'is_logged_in';
  static const _kAccessToken = 'access_token';
  static const _kUserId = 'user_id';
  static const _kLoginUser = 'loginuser';
  static const _kMobile = 'mobile';
  static const _kAccount = 'account';
  static const _kPostLoginCheck = 'post_login_check';
  static const _kUserName = 'user_name';

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool(_kIsLoggedIn) ?? false;
    final token = prefs.getString(_kAccessToken);
    final userId = prefs.getString(_kUserId);
    return loggedIn && (token?.isNotEmpty ?? false) && (userId?.isNotEmpty ?? false);
  }

  static Future<void> saveLogin({
    required String accessToken,
    required String userId,
    required String userName,
    String mobile = '',
    String account = 'login',
    bool postLoginCheck = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await play.PlayProfileHelper.clearPlayProfileCache();
    await prefs.setBool(_kIsLoggedIn, true);
    await prefs.setString(_kAccessToken, accessToken);
    await prefs.setString(_kUserId, userId);
    await prefs.setString(_kLoginUser, userName);
    await prefs.setString(_kUserName, userName);
    await prefs.setString(_kAccount, account);
    if (postLoginCheck) {
      await prefs.setBool(_kPostLoginCheck, true);
    } else {
      await prefs.remove(_kPostLoginCheck);
    }
    if (mobile.isNotEmpty) {
      await prefs.setString(_kMobile, mobile);
      
      // Auto-create or fetch Play Profile from MongoDB during login
      try {
        final uri = Uri.parse('https://api.welfog.com/api/users/');
        final res = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'userid': userId,
            'username': userId,
            'mobile': mobile,
          }),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final data = jsonDecode(res.body);
          if (data is Map<String, dynamic> && data['_id'] != null) {
            final id = data['_id'].toString();
            final uname = (data['username'] ?? '').toString();
            final name = (data['name'] ?? uname).toString();
            
            await prefs.setString('loginid', id);
            await prefs.setString('cached_user_id', id);
            await prefs.setString('play_profile_id', id);
            await prefs.setString('play_profile_user_name', uname);
            await prefs.setString('play_profile_name', name);
            await prefs.setString('fourth_userid', (data['userid'] ?? id).toString());
          }
        }
      } catch (_) {}
    }
  }

  static Future<void> clearLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await play.PlayProfileHelper.clearPlayProfileCache();
    await prefs.remove(_kIsLoggedIn);
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kUserId);
    await prefs.remove(_kLoginUser);
    await prefs.remove(_kUserName);
    await prefs.remove(_kAccount);
    await prefs.remove(_kPostLoginCheck);
    await prefs.remove(_kMobile);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserId);
  }
}
