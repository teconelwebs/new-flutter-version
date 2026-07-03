import 'package:shared_preferences/shared_preferences.dart';
import 'package:welfog_flutter_play/welfog_flutter_play.dart' as play;

class SessionStore {
  static const _kIsLoggedIn = 'is_logged_in';
  static const _kAccessToken = 'access_token';
  static const _kUserId = 'user_id';
  static const _kLoginUser = 'loginuser';
  static const _kMobile = 'mobile';

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
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await play.PlayProfileHelper.clearPlayProfileCache();
    await prefs.setBool(_kIsLoggedIn, true);
    await prefs.setString(_kAccessToken, accessToken);
    await prefs.setString(_kUserId, userId);
    await prefs.setString(_kLoginUser, userName);
    if (mobile.isNotEmpty) {
      await prefs.setString(_kMobile, mobile);
    }
  }

  static Future<void> clearLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await play.PlayProfileHelper.clearPlayProfileCache();
    await prefs.remove(_kIsLoggedIn);
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kUserId);
    await prefs.remove(_kLoginUser);
    await prefs.remove(_kMobile);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserId);
  }
}
