import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/play_launch_context.dart';
import '../services/device_id_store.dart';
import 'viewer_id_helper.dart';

const _mainApi = 'https://welfogapi.welfog.com/api/v2';
const _playApi = 'https://api.welfog.com/api';
const _guestViewerKey = 'guest_viewer_id';

/// Mirrors RN `playProfileHelper.ts` — resolves play profile ids and launch params
/// from the same SharedPreferences keys the main app writes on login.
class PlayProfileHelper {
  static Future<Map<String, String>> _playHeaders() async {
    final deviceId = await DeviceIdStore.getOrCreate();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (deviceId.isNotEmpty) 'x-android-id': deviceId,
    };
  }

  static Future<void> clearPlayProfileCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('play_profile_id');
    await prefs.remove('play_profile_user_name');
    await prefs.remove('play_profile_name');
    await prefs.remove('cached_user_id');
    await prefs.remove('fourth_userid');
    await prefs.remove('loginid');
  }

  static Future<String?> getStoredPlayUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_user_id');
    if (isValidObjectId(cached)) return cached;

    final loginid = prefs.getString('loginid');
    if (isValidObjectId(loginid)) return loginid;

    return null;
  }

  static Future<Map<String, dynamic>?> _getSessionUserData(
    String accessToken,
    String mainUserId,
  ) async {
    final response = await http.post(
      Uri.parse('$_mainApi/get-user-by-access_token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'access_token': accessToken, 'userId': mainUserId}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final body = jsonDecode(response.body);
    return body is Map<String, dynamic> ? body : null;
  }

  static Future<PlayProfileUserData?> getPlayProfileUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final mainUserId = prefs.getString('user_id') ?? '';
    final accessToken = prefs.getString('access_token') ?? '';
    if (mainUserId.isEmpty || accessToken.isEmpty) return null;

    final data = await _getSessionUserData(accessToken, mainUserId);
    final mobile = (data?['phone'] ?? '').toString().trim();
    if (mobile.isEmpty) return null;

    return PlayProfileUserData(mainUserId: mainUserId, mobile: mobile);
  }

  static Future<String?> resolvePlayUserIdFromSession() async {
    final stored = await getStoredPlayUserId();
    if (stored != null) return stored;

    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token') ?? '';
    final mainUserId = prefs.getString('user_id') ?? '';
    if (accessToken.isEmpty || mainUserId.isEmpty) return null;

    try {
      final userData = await _getSessionUserData(accessToken, mainUserId);
      final mobile = (userData?['phone'] ?? '').toString().trim();
      if (mobile.isEmpty) return null;

      final headers = await _playHeaders();
      final mobileRes = await http.get(
        Uri.parse('$_playApi/users/bymobile/$mobile'),
        headers: headers,
      );
      if (mobileRes.statusCode == 404) {
        final createRes = await http.post(
          Uri.parse('$_playApi/users/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'userid': mainUserId,
            'username': mainUserId,
            'mobile': mobile,
          }),
        );
        if (createRes.statusCode >= 200 && createRes.statusCode < 300) {
          final body = jsonDecode(createRes.body);
          if (body is Map<String, dynamic> && body['_id'] != null) {
            final finalUserId = body['_id'].toString();
            await prefs.setString('cached_user_id', finalUserId);
            await prefs.setString('loginid', finalUserId);
            await prefs.setString('play_profile_id', finalUserId);
            await prefs.setString('play_profile_user_name', (body['username'] ?? '').toString());
            await prefs.setString('play_profile_name', (body['name'] ?? body['username'] ?? '').toString());
            await prefs.setString('fourth_userid', (body['userid'] ?? finalUserId).toString());
            return finalUserId;
          }
        }
      }
      if (mobileRes.statusCode == 429 || mobileRes.statusCode < 200 || mobileRes.statusCode >= 300) {
        return null;
      }

      final body = jsonDecode(mobileRes.body);
      if (body is! Map<String, dynamic>) return null;
      final finalUserId = (body['_id'] ?? '').toString();
      if (!isValidObjectId(finalUserId)) return null;

      await prefs.setString('cached_user_id', finalUserId);
      return finalUserId;
    } catch (_) {
      return null;
    }
  }

  static Future<String> getOrCreateGuestViewerId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_guestViewerKey);
    if (isValidObjectId(existing)) return existing!;

    final deviceId = await DeviceIdStore.getOrCreate();
    final guestId = stableGuestIdFromDevice(deviceId);
    await prefs.setString(_guestViewerKey, guestId);
    return guestId;
  }

  static Future<String> resolveReelsViewerId() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_user_id');
    if (isValidObjectId(cached)) return cached!;

    if (cached != null && cached.isNotEmpty) {
      await prefs.remove('cached_user_id');
    }

    final playUserId = await resolvePlayUserIdFromSession();
    if (playUserId != null) return playUserId;

    return getOrCreateGuestViewerId();
  }

  static Future<bool> hasPlayProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final mainUserId = prefs.getString('user_id') ?? '';
    final accessToken = prefs.getString('access_token') ?? '';
    if (mainUserId.isEmpty || accessToken.isEmpty) return true;

    final isGuest = prefs.getString('is_guest') == 'true';
    if (isGuest) return true;

    final loginid = prefs.getString('loginid');
    if (loginid != null && loginid.isNotEmpty && loginid != mainUserId) {
      try {
        final headers = await _playHeaders();
        final res = await http.get(
          Uri.parse('$_playApi/users/$loginid'),
          headers: headers,
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final body = jsonDecode(res.body);
          if (body is Map && body['_id'] != null) return true;
        }
      } catch (_) {}
    }

    final userData = await getPlayProfileUserData();
    if (userData == null) return false;

    try {
      final headers = await _playHeaders();
      final mobileRes = await http.get(
        Uri.parse('$_playApi/users/bymobile/${userData.mobile}'),
        headers: headers,
      );
      if (mobileRes.statusCode >= 200 && mobileRes.statusCode < 300) {
        final body = jsonDecode(mobileRes.body);
        if (body is Map && body['_id'] != null) {
          final id = body['_id'].toString();
          await prefs.setString('loginid', id);
          await prefs.setString('cached_user_id', id);
          await prefs.setString(
            'fourth_userid',
            (body['userid'] ?? id).toString(),
          );
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  static Future<PlayLaunchContext> resolveFlutterLaunchContext() async {
    final profileExists = await hasPlayProfile();
    if (profileExists) {
      return const PlayLaunchContext(playProfileReady: true);
    }

    final userData = await getPlayProfileUserData();
    return PlayLaunchContext(
      mainUserId: userData?.mainUserId ?? '',
      mobile: userData?.mobile ?? '',
      playProfileReady: false,
    );
  }

  static Future<PlayRouteSession> resolvePlayRouteSession() async {
    final launchContext = await resolveFlutterLaunchContext();
    final viewerId = await resolveReelsViewerId();
    final deviceId = await DeviceIdStore.getOrCreate();
    final prefs = await SharedPreferences.getInstance();
    final shareUserId = prefs.getString('user_id') ?? '';

    return PlayRouteSession(
      viewerId: viewerId,
      deviceId: deviceId,
      shareUserId: shareUserId,
      launchContext: launchContext,
    );
  }

  static Future<void> cachePlayProfileCreated({
    required String playUserId,
    String username = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('loginid', playUserId);
    await prefs.setString('cached_user_id', playUserId);
    await prefs.setString('play_profile_id', playUserId);
    await prefs.setString('play_profile_user_name', username);
    await prefs.setString('play_profile_name', username);
  }

  /// Build a play route URI with RN-equivalent session query params.
  static Future<String> buildAuthenticatedRoute(String routeName) async {
    final session = await resolvePlayRouteSession();
    final launch = session.launchContext;

    final query = <String, String>{
      if (session.viewerId.isNotEmpty) 'userId': session.viewerId,
      if (session.deviceId.isNotEmpty) 'deviceId': session.deviceId,
      if (session.shareUserId.isNotEmpty) 'shareUserId': session.shareUserId,
      if (!launch.playProfileReady && launch.mainUserId.isNotEmpty)
        'mainUserId': launch.mainUserId,
      if (!launch.playProfileReady && launch.mobile.isNotEmpty)
        'mobile': launch.mobile,
      'playProfileReady': launch.playProfileReady ? '1' : '0',
    };

    return Uri(path: routeName, queryParameters: query).toString();
  }
}

class PlayProfileUserData {
  const PlayProfileUserData({required this.mainUserId, required this.mobile});

  final String mainUserId;
  final String mobile;
}

class PlayRouteSession {
  const PlayRouteSession({
    required this.viewerId,
    required this.deviceId,
    required this.shareUserId,
    required this.launchContext,
  });

  final String viewerId;
  final String deviceId;
  final String shareUserId;
  final PlayLaunchContext launchContext;
}
