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
    for (final key in [
      'cached_user_id',
      'loginid',
      'play_profile_id',
    ]) {
      final value = prefs.getString(key);
      if (isValidObjectId(value)) return value;
    }
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

  static Future<String?> _mobileFromSession() async {
    final prefs = await SharedPreferences.getInstance();
    final fromPrefs = (prefs.getString('mobile') ?? '').trim();
    if (fromPrefs.isNotEmpty) return fromPrefs;

    final mainUserId = prefs.getString('user_id') ?? '';
    final accessToken = prefs.getString('access_token') ?? '';
    if (mainUserId.isEmpty || accessToken.isEmpty) return null;

    final data = await _getSessionUserData(accessToken, mainUserId);
    final phone = (data?['phone'] ?? data?['mobile'] ?? '').toString().trim();
    return phone.isEmpty ? null : phone;
  }

  static Future<PlayProfileUserData?> getPlayProfileUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final mainUserId = prefs.getString('user_id') ?? '';
    final accessToken = prefs.getString('access_token') ?? '';
    if (mainUserId.isEmpty || accessToken.isEmpty) return null;

    final mobile = await _mobileFromSession();
    if (mobile == null || mobile.isEmpty) return null;

    final data = await _getSessionUserData(accessToken, mainUserId);
    final name =
        (data?['name'] ?? prefs.getString('user_name') ?? '').toString().trim();

    return PlayProfileUserData(
        mainUserId: mainUserId, mobile: mobile, name: name);
  }

  /// Looks up Play Mongo `_id` by mobile (ignores stale guest cache).
  static Future<String?> resolvePlayUserIdByMobile() async {
    final mobile = await _mobileFromSession();
    if (mobile == null || mobile.isEmpty) return null;

    try {
      final headers = await _playHeaders();
      final candidates = <String>{
        mobile,
        if (mobile.startsWith('+')) mobile.substring(1),
        if (mobile.startsWith('91') && mobile.length > 10) mobile.substring(2),
        if (!mobile.startsWith('+') && !mobile.startsWith('91')) '91$mobile',
      };

      for (final m in candidates) {
        final mobileRes = await http.get(
          Uri.parse('$_playApi/users/bymobile/$m'),
          headers: headers,
        );
        if (mobileRes.statusCode < 200 || mobileRes.statusCode >= 300) {
          continue;
        }
        final body = jsonDecode(mobileRes.body);
        if (body is! Map) continue;
        final finalUserId = (body['_id'] ?? '').toString();
        if (!isValidObjectId(finalUserId)) continue;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_user_id', finalUserId);
        await prefs.setString('loginid', finalUserId);
        await prefs.setString('play_profile_id', finalUserId);
        await prefs.setString(
          'fourth_userid',
          (body['userid'] ?? finalUserId).toString(),
        );
        return finalUserId;
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> resolvePlayUserIdFromSession() async {
    final stored = await getStoredPlayUserId();
    if (stored != null) return stored;
    return resolvePlayUserIdByMobile();
  }

  /// Confirms a mongo id is a real Play user (not a guest hash).
  ///
  /// Note: GET `/users/:id` often expects numeric `userid`, so we also try
  /// `/users/userpost/:mongoId` which accepts the profile `_id`.
  static Future<bool> _isRealPlayProfile(String id) async {
    if (!isValidObjectId(id)) return false;
    try {
      final headers = await _playHeaders();

      final userpost = await http.get(
        Uri.parse('$_playApi/users/userpost/$id'),
        headers: headers,
      );
      if (userpost.statusCode >= 200 && userpost.statusCode < 300) {
        final body = jsonDecode(userpost.body);
        if (body is Map && body['user'] is Map) return true;
      }

      final direct = await http.get(
        Uri.parse('$_playApi/users/$id'),
        headers: headers,
      );
      if (direct.statusCode >= 200 && direct.statusCode < 300) {
        final body = jsonDecode(direct.body);
        if (body is Map && (body['_id'] != null || body['userid'] != null)) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Returns a verified Play Mongo `_id` for api.welfog.com actions (block, etc.).
  static Future<String?> ensurePlayProfileMongoId({String? preferredId}) async {
    final prefs = await SharedPreferences.getInstance();
    final candidates = <String>[];

    void addCandidate(String? raw) {
      final id = raw?.trim() ?? '';
      if (!isValidObjectId(id)) return;
      if (!candidates.contains(id)) candidates.add(id);
    }

    addCandidate(preferredId);
    addCandidate(await getStoredPlayUserId());
    addCandidate(prefs.getString('play_profile_id'));
    addCandidate(prefs.getString('loginid'));
    addCandidate(prefs.getString('cached_user_id'));

    for (final id in candidates) {
      if (await _isRealPlayProfile(id)) {
        await prefs.setString('cached_user_id', id);
        await prefs.setString('loginid', id);
        await prefs.setString('play_profile_id', id);
        return id;
      }
    }

    // Cached guest ObjectIds look valid but aren't in DB — resolve by mobile.
    final fromMobile = await resolvePlayUserIdByMobile();
    if (fromMobile != null && await _isRealPlayProfile(fromMobile)) {
      return fromMobile;
    }
    if (fromMobile != null) return fromMobile;

    return null;
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

    final loginid = prefs.getString('loginid') ??
        prefs.getString('play_profile_id') ??
        prefs.getString('cached_user_id');
    if (loginid != null &&
        loginid.isNotEmpty &&
        loginid != mainUserId &&
        isValidObjectId(loginid)) {
      try {
        final headers = await _playHeaders();
        final res = await http.get(
          Uri.parse('$_playApi/users/userpost/$loginid'),
          headers: headers,
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final body = jsonDecode(res.body);
          if (body is Map && body['user'] is Map) return true;
        }
        final direct = await http.get(
          Uri.parse('$_playApi/users/$loginid'),
          headers: headers,
        );
        if (direct.statusCode >= 200 && direct.statusCode < 300) {
          final body = jsonDecode(direct.body);
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
      name: userData?.name ?? '',
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
      if (!launch.playProfileReady && launch.name.isNotEmpty)
        'name': launch.name,
      'playProfileReady': launch.playProfileReady ? '1' : '0',
    };

    return Uri(path: routeName, queryParameters: query).toString();
  }
}

class PlayProfileUserData {
  const PlayProfileUserData({
    required this.mainUserId,
    required this.mobile,
    required this.name,
  });

  final String mainUserId;
  final String mobile;
  final String name;
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
