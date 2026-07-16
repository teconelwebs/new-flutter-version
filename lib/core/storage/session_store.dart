import 'package:shared_preferences/shared_preferences.dart';
import 'package:welfog_flutter_play/welfog_flutter_play.dart' as play;
import '../services/push_notification_service.dart';

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
    return loggedIn &&
        (token?.isNotEmpty ?? false) &&
        (userId?.isNotEmpty ?? false);
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

      // Create or fetch Play profile on api.welfog.com (same as RN flow).
      try {
        final deviceId = await play.DeviceIdStore.getOrCreate();
        final service = play.PlayProfileService(deviceId: deviceId);
        final playUserId = await service.createPlayProfile(
          mainUserId: userId,
          mobile: mobile,
          username: userId,
          name: userName,
        );
        await play.PlayProfileHelper.cachePlayProfileCreated(
          playUserId: playUserId,
          username: userName,
        );
      } catch (_) {
        // Fallback: resolve existing profile by mobile after prefs are saved.
        try {
          final resolved =
              await play.PlayProfileHelper.resolvePlayUserIdFromSession();
          if (resolved != null && resolved.isNotEmpty) {
            await play.PlayProfileHelper.cachePlayProfileCreated(
              playUserId: resolved,
              username: userName,
            );
          }
        } catch (_) {}
      }
    }

    // Sync FCM Token with backend immediately on login
    try {
      await PushNotificationService.instance.syncTokenWithBackend();
    } catch (_) {}
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
