import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/play_launch_context.dart';
import '../services/device_id_store.dart';
import '../services/play_api_config.dart';
import '../services/play_profile_service.dart';
import 'viewer_id_helper.dart';

const _mainApi = 'https://welfogapi.welfog.com/api/v2';
const _playApi = kPlayApiBaseUrl;
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
    await prefs.remove('play_username_ready');
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
    final mainUserId = (prefs.getString('user_id') ?? '').trim();
    final accessToken = prefs.getString('access_token') ?? '';
    if (mainUserId.isEmpty || accessToken.isEmpty) return null;

    // Prefer prefs mobile; don't hard-fail if API name lookup is slow/offline.
    var mobile = (prefs.getString('mobile') ?? '').trim();
    if (mobile.isEmpty) {
      mobile = (await _mobileFromSession() ?? '').trim();
    }

    var name = (prefs.getString('user_name') ?? '').trim();
    try {
      final data = await _getSessionUserData(accessToken, mainUserId);
      final apiName = (data?['name'] ?? '').toString().trim();
      if (apiName.isNotEmpty) name = apiName;
      if (mobile.isEmpty) {
        mobile = (data?['phone'] ?? data?['mobile'] ?? '').toString().trim();
      }
    } catch (_) {}

    return PlayProfileUserData(
      mainUserId: mainUserId,
      mobile: mobile,
      name: name,
    );
  }

  static Set<String> _mobileCandidates(String mobile) {
    final m = mobile.trim();
    if (m.isEmpty) return {};
    return {
      m,
      if (m.startsWith('+')) m.substring(1),
      if (m.startsWith('91') && m.length > 10) m.substring(2),
      if (!m.startsWith('+') && !m.startsWith('91') && m.length == 10) '91$m',
    };
  }

  /// Fetch play user map by mongo id, shop userid, or mobile.
  static Future<Map<String, dynamic>?> _fetchPlayUserMap({
    String? mongoId,
    String? mainUserId,
    String? mobile,
  }) async {
    final headers = await _playHeaders();

    Future<Map<String, dynamic>?> tryUserpost(String id) async {
      if (!isValidObjectId(id)) return null;
      try {
        final res = await http.get(
          Uri.parse('$_playApi/users/userpost/$id'),
          headers: headers,
        );
        if (res.statusCode < 200 || res.statusCode >= 300) return null;
        final body = jsonDecode(res.body);
        if (body is Map && body['user'] is Map) {
          return Map<String, dynamic>.from(body['user'] as Map);
        }
      } catch (_) {}
      return null;
    }

    Future<Map<String, dynamic>?> tryDirect(String id) async {
      final key = id.trim();
      if (key.isEmpty) return null;
      try {
        final res = await http.get(
          Uri.parse('$_playApi/users/$key'),
          headers: headers,
        );
        if (res.statusCode < 200 || res.statusCode >= 300) return null;
        final body = jsonDecode(res.body);

        final maps = <Map<String, dynamic>>[];
        void addMap(dynamic raw) {
          if (raw is Map &&
              ((raw['_id'] ?? '').toString().isNotEmpty ||
                  (raw['username'] ?? '').toString().isNotEmpty)) {
            maps.add(Map<String, dynamic>.from(raw));
          }
        }

        if (body is List) {
          for (final item in body) {
            addMap(item);
          }
        } else if (body is Map) {
          if (body['data'] is List) {
            for (final item in body['data'] as List) {
              addMap(item);
            }
          } else {
            addMap(body);
          }
        }

        if (maps.isEmpty) return null;
        if (maps.length == 1) return maps.first;

        final bestId = await _pickCanonicalPlayMongoId(
          maps.map((m) => (m['_id'] ?? '').toString()),
        );
        for (final m in maps) {
          if ((m['_id'] ?? '').toString() == bestId) return m;
        }
        return maps.first;
      } catch (_) {}
      return null;
    }

    Future<Map<String, dynamic>?> tryMobile(String raw) async {
      for (final candidate in _mobileCandidates(raw)) {
        try {
          final res = await http.get(
            Uri.parse('$_playApi/users/bymobile/$candidate'),
            headers: headers,
          );
          if (res.statusCode < 200 || res.statusCode >= 300) continue;
          final body = jsonDecode(res.body);
          if (body is Map &&
              ((body['_id'] ?? '').toString().isNotEmpty ||
                  (body['username'] ?? '').toString().isNotEmpty)) {
            return Map<String, dynamic>.from(body);
          }
        } catch (_) {}
      }
      return null;
    }

    final mongo = (mongoId ?? '').trim();
    if (mongo.isNotEmpty) {
      final fromPost = await tryUserpost(mongo);
      if (fromPost != null) return fromPost;
      final fromDirect = await tryDirect(mongo);
      if (fromDirect != null) return fromDirect;
    }

    final shopId = (mainUserId ?? '').trim();
    if (shopId.isNotEmpty) {
      final fromShop = await tryDirect(shopId);
      if (fromShop != null) return fromShop;
    }

    final mob = (mobile ?? '').trim();
    if (mob.isNotEmpty) {
      final fromMobile = await tryMobile(mob);
      if (fromMobile != null) return fromMobile;
    }

    return null;
  }

  /// Looks up Play Mongo `_id` by mobile (ignores stale guest cache).
  static Future<String?> resolvePlayUserIdByMobile() async {
    final mobile = await _mobileFromSession();
    if (mobile == null || mobile.isEmpty) return null;

    try {
      final userMap = await _fetchPlayUserMap(mobile: mobile);
      if (userMap == null) return null;
      final finalUserId = (userMap['_id'] ?? '').toString();
      if (!isValidObjectId(finalUserId)) return null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_id', finalUserId);
      await prefs.setString('loginid', finalUserId);
      await prefs.setString('play_profile_id', finalUserId);
      await prefs.setString(
        'fourth_userid',
        (userMap['userid'] ?? finalUserId).toString(),
      );
      return finalUserId;
    } catch (_) {}
    return null;
  }

  static Future<int> _postCountForMongoId(String mongoId) async {
    final id = mongoId.trim();
    if (!isValidObjectId(id)) return 0;
    try {
      final headers = await _playHeaders();
      final uri = Uri.parse('$_playApi/reels/others/$id').replace(
        queryParameters: {'limit': '1', 'skip': '0'},
      );
      final res = await http.get(uri, headers: headers);
      if (res.statusCode < 200 || res.statusCode >= 300) return 0;
      final body = jsonDecode(res.body);
      if (body is List) return body.isEmpty ? 0 : 1;
      if (body is Map) {
        final raw = body['reels'] ?? body['data'] ?? body['total'];
        if (raw is List) return raw.isEmpty ? 0 : raw.length;
        if (raw is num) return raw.toInt();
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// When duplicate play profiles exist for one shop user, prefer the one that
  /// still owns posts; otherwise the older ObjectId (original account).
  static Future<String?> _pickCanonicalPlayMongoId(
    Iterable<String?> candidates,
  ) async {
    final ids = <String>[];
    for (final raw in candidates) {
      final id = (raw ?? '').trim();
      if (!isValidObjectId(id)) continue;
      if (!ids.contains(id)) ids.add(id);
    }
    if (ids.isEmpty) return null;
    if (ids.length == 1) return ids.first;

    String? best;
    var bestPosts = -1;
    for (final id in ids) {
      final posts = await _postCountForMongoId(id);
      debugPrint('🎮 [PlayProfile] candidate mongoId=$id postHint=$posts');
      if (posts > bestPosts ||
          (posts == bestPosts &&
              best != null &&
              id.compareTo(best) < 0) ||
          (posts == bestPosts && best == null)) {
        bestPosts = posts;
        best = id;
      }
    }

    // All empty → oldest ObjectId (original profile before accidental recreate).
    if (bestPosts <= 0) {
      ids.sort();
      best = ids.first;
      debugPrint(
        '🎮 [PlayProfile] no posts on candidates — preferring oldest $best',
      );
    } else {
      debugPrint(
        '🎮 [PlayProfile] canonical mongoId=$best (postsHint=$bestPosts)',
      );
    }
    return best;
  }

  /// Resolves the real Play mongo id for the logged-in shop user.
  /// Prefer shop userid + mobile, and never stick to a stale empty duplicate.
  static Future<String?> resolveCanonicalPlayMongoId() async {
    final prefs = await SharedPreferences.getInstance();
    final mainUserId = (prefs.getString('user_id') ?? '').trim();
    final mobile = await _mobileFromSession();

    final byShop = mainUserId.isEmpty
        ? null
        : await _fetchPlayUserMap(mainUserId: mainUserId);
    final byMobile = (mobile == null || mobile.isEmpty)
        ? null
        : await _fetchPlayUserMap(mobile: mobile);

    final chosen = await _pickCanonicalPlayMongoId([
      (byShop?['_id'] ?? '').toString(),
      (byMobile?['_id'] ?? '').toString(),
      prefs.getString('play_profile_id'),
      prefs.getString('cached_user_id'),
      prefs.getString('loginid'),
    ]);

    if (chosen == null || chosen.isEmpty) return null;

    // If we chose the older profile, make sure mobile + userid stay linked.
    final map = byShop?['_id']?.toString() == chosen
        ? byShop
        : byMobile?['_id']?.toString() == chosen
            ? byMobile
            : await _fetchPlayUserMap(mongoId: chosen);

    await prefs.setString('cached_user_id', chosen);
    await prefs.setString('loginid', chosen);
    await prefs.setString('play_profile_id', chosen);
    if (mainUserId.isNotEmpty) {
      await prefs.setString('fourth_userid', mainUserId);
    } else if (map != null) {
      await prefs.setString(
        'fourth_userid',
        (map['userid'] ?? chosen).toString(),
      );
    }

    debugPrint(
      '🎮 [PlayProfile] resolveCanonical → mongoId=$chosen '
      'shopUserId=$mainUserId mobile=$mobile',
    );
    return chosen;
  }

  static Future<String?> resolvePlayUserIdFromSession() async {
    // Always re-resolve for logged-in users so a mistaken duplicate profile
    // (empty, created after wrong username sheet) does not stick forever.
    final prefs = await SharedPreferences.getInstance();
    final mainUserId = (prefs.getString('user_id') ?? '').trim();
    if (mainUserId.isNotEmpty) {
      final canonical = await resolveCanonicalPlayMongoId();
      if (canonical != null) return canonical;
    }

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

  /// Returns a verified Play Mongo `_id` for play API actions (block, etc.).
  static Future<String?> ensurePlayProfileMongoId({String? preferredId}) async {
    final prefs = await SharedPreferences.getInstance();
    final mainUserId = (prefs.getString('user_id') ?? '').trim();

    // Logged-in: always prefer canonical (posts / oldest) over stale cache.
    if (mainUserId.isNotEmpty) {
      final canonical = await resolveCanonicalPlayMongoId();
      if (canonical != null && canonical.isNotEmpty) {
        if (preferredId != null &&
            isValidObjectId(preferredId) &&
            preferredId != canonical) {
          debugPrint(
            '🎮 [PlayProfile] preferredId=$preferredId ignored — '
            'canonical=$canonical',
          );
        }
        return canonical;
      }
    }

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
    final userData = await getPlayProfileUserData();
    final usernameReady = await isPlayUsernameReady();
    if (usernameReady) {
      return const PlayLaunchContext(playProfileReady: true);
    }

    return PlayLaunchContext(
      mainUserId: userData?.mainUserId ?? '',
      mobile: userData?.mobile ?? '',
      name: userData?.name ?? '',
      playProfileReady: false,
    );
  }

  /// True only when the user has chosen a real Play username (not pending_/userId).
  static Future<bool> isPlayUsernameReady() async {
    final prefs = await SharedPreferences.getInstance();
    final mainUserId = (prefs.getString('user_id') ?? '').trim();

    if (prefs.getString('play_username_ready') == '1') {
      final cached = prefs.getString('play_profile_user_name') ?? '';
      if (!PlayProfileService.isPlaceholderUsername(cached, mainUserId)) {
        debugPrint('🎮 [PlayProfile] username ready (cache): @$cached');
        return true;
      }
    }

    try {
      final mongoId = await getStoredPlayUserId();
      final mobile = await _mobileFromSession();
      final userMap = await _fetchPlayUserMap(
        mongoId: mongoId,
        mainUserId: mainUserId,
        mobile: mobile,
      );

      if (userMap == null) {
        debugPrint(
          '🎮 [PlayProfile] username NOT ready — no play profile found '
          '(mainUserId=$mainUserId mobile=$mobile)',
        );
        await prefs.setString('play_username_ready', '0');
        return false;
      }

      final username = (userMap['username'] ?? '').toString();
      final id = (userMap['_id'] ?? '').toString();
      if (isValidObjectId(id)) {
        await prefs.setString('loginid', id);
        await prefs.setString('cached_user_id', id);
        await prefs.setString('play_profile_id', id);
      }

      final ready =
          !PlayProfileService.isPlaceholderUsername(username, mainUserId);
      if (ready) {
        await prefs.setString('play_username_ready', '1');
        await prefs.setString('play_profile_user_name', username);
        debugPrint('🎮 [PlayProfile] username ready: @$username');
      } else {
        await prefs.setString('play_username_ready', '0');
        debugPrint(
          '🎮 [PlayProfile] username NOT ready (placeholder): "$username"',
        );
      }
      return ready;
    } catch (e) {
      debugPrint('🎮 [PlayProfile] isPlayUsernameReady error: $e');
      return false;
    }
  }

  /// After home name dialog — create/update Play profile with name + userid only.
  static Future<void> bootstrapAfterNameSave({required String name}) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = (prefs.getString('user_id') ?? '').trim();
    final mobile = (prefs.getString('mobile') ?? '').trim();
    final trimmedName = name.trim();
    debugPrint(
      '🎮 [PlayProfile] bootstrapAfterNameSave START '
      'baseUrl=$_playApi userId=$userId mobile=$mobile name=$trimmedName',
    );
    if (userId.isEmpty || mobile.isEmpty || trimmedName.isEmpty) {
      debugPrint(
        '🎮 [PlayProfile] bootstrapAfterNameSave skipped — '
        'userId=$userId mobile=$mobile name=$trimmedName',
      );
      return;
    }

    try {
      final deviceId = await DeviceIdStore.getOrCreate();
      final service = PlayProfileService(deviceId: deviceId);
      final playUserId = await service.bootstrapWithName(
        mainUserId: userId,
        mobile: mobile,
        name: trimmedName,
      );

      await prefs.setString('loginid', playUserId);
      await prefs.setString('cached_user_id', playUserId);
      await prefs.setString('play_profile_id', playUserId);
      await prefs.setString('play_profile_name', trimmedName);
      await prefs.setString('play_username_ready', '0');
      await prefs.setString('fourth_userid', userId);

      await service.syncMainUserId(
        playMongoId: playUserId,
        mainUserId: userId,
      );

      debugPrint(
        '🎮 [PlayProfile] bootstrapAfterNameSave done — '
        'baseUrl=$_playApi mongoId=$playUserId userid=$userId '
        'name=$trimmedName (username sheet still required)',
      );
    } catch (e) {
      debugPrint(
        '🎮 [PlayProfile] bootstrapAfterNameSave failed baseUrl=$_playApi: $e',
      );
    }
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
    String? mainUserId,
    bool usernameReady = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('loginid', playUserId);
    await prefs.setString('cached_user_id', playUserId);
    await prefs.setString('play_profile_id', playUserId);
    if (username.trim().isNotEmpty) {
      await prefs.setString('play_profile_user_name', username.trim());
      // Display name may already be set from home dialog — don't clobber with username
      // unless we have no name yet.
      final existingName = (prefs.getString('play_profile_name') ?? '').trim();
      if (existingName.isEmpty) {
        await prefs.setString('play_profile_name', username.trim());
      }
    }
    await prefs.setString(
      'play_username_ready',
      usernameReady ? '1' : '0',
    );
    final uid = (mainUserId ?? prefs.getString('user_id') ?? '').trim();
    if (uid.isNotEmpty && usernameReady) {
      await prefs.setString('fourth_userid', uid);
    }
  }

  /// Ensures Play profile `userid` matches main-app login `user_id`.
  /// New users get this on create; old users get it when opening Play tab.
  static Future<void> ensureMainUserIdOnPlayProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final mainUserId = (prefs.getString('user_id') ?? '').trim();
    if (mainUserId.isEmpty) {
      debugPrint('🎮 [PlayProfile] ensureMainUserId skipped — no login user_id');
      return;
    }

    final playMongoId = await ensurePlayProfileMongoId();
    if (playMongoId == null || playMongoId.isEmpty) {
      debugPrint(
        '🎮 [PlayProfile] ensureMainUserId skipped — no play mongo profile yet',
      );
      return;
    }

    final deviceId = await DeviceIdStore.getOrCreate();
    final service = PlayProfileService(deviceId: deviceId);
    final ok = await service.syncMainUserId(
      playMongoId: playMongoId,
      mainUserId: mainUserId,
    );
    if (ok) {
      await prefs.setString('fourth_userid', mainUserId);
      debugPrint(
        '🎮 [PlayProfile] ensureMainUserId done — '
        'playMongoId=$playMongoId userid=$mainUserId',
      );
    }
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
