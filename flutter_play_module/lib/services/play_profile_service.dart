// ignore_for_file: prefer_const_declarations

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'play_api_config.dart';

const _fourthBaseUrl = kPlayApiBaseUrl;

class PlayProfileService {
  const PlayProfileService({required this.deviceId});

  final String deviceId;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (deviceId.isNotEmpty) 'x-android-id': deviceId,
      };

  void _log(String msg) =>
      debugPrint('🎮 [PlayProfile] baseUrl=$_fourthBaseUrl | $msg');

  /// Shop login ids are numeric (e.g. "1773"). Server often ignores string-only
  /// `{userid}` PUTs, so send numeric when possible.
  static dynamic encodeUserId(String mainUserId) {
    final trimmed = mainUserId.trim();
    return int.tryParse(trimmed) ?? trimmed;
  }

  static bool isUuidLike(String? value) {
    final v = (value ?? '').trim();
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(v);
  }

  /// Provisional username used until the user picks a real one in Play setup.
  static String pendingUsernameFor(String mainUserId) =>
      'pending_${mainUserId.trim()}';

  static bool isPlaceholderUsername(String? username, String mainUserId) {
    final u = (username ?? '').trim();
    final id = mainUserId.trim();
    if (u.isEmpty) return true;
    if (id.isNotEmpty && u == id) return true;
    if (RegExp(r'^user\d+$', caseSensitive: false).hasMatch(u)) return true;
    if (u.toLowerCase().startsWith('pending_')) return true;
    if (u.toLowerCase().startsWith('temp_')) return true;
    return false;
  }

  /// Called after home name dialog — stores name + login user_id only.
  /// Username stays provisional so Play still shows the username sheet.
  Future<String> bootstrapWithName({
    required String mainUserId,
    required String mobile,
    required String name,
  }) async {
    final pending = pendingUsernameFor(mainUserId);
    _log(
      'bootstrapWithName '
      'userid=$mainUserId name=$name mobile=$mobile pendingUsername=$pending',
    );
    return upsertPlayProfile(
      mainUserId: mainUserId,
      mobile: mobile,
      username: pending,
      name: name,
    );
  }

  Future<String> createPlayProfile({
    required String mainUserId,
    required String mobile,
    required String username,
    String name = '',
  }) async {
    final trimmed = username.trim();
    _log(
      'createPlayProfile start '
      'mainUserId=$mainUserId mobile=$mobile username=$trimmed name=$name',
    );
    return upsertPlayProfile(
      mainUserId: mainUserId,
      mobile: mobile,
      username: trimmed,
      name: name,
    );
  }

  /// Prefer update of an existing profile — never mint a duplicate for the
  /// same shop userid / mobile (that orphaned posts on older mongo ids).
  Future<String> upsertPlayProfile({
    required String mainUserId,
    required String mobile,
    required String username,
    String name = '',
  }) async {
    // 1) Shop userid first (canonical), then mobile.
    final byUserId = await _lookupByShopUserId(mainUserId);
    final byMobile = await _lookupByMobile(mobile);
    final existing = _preferExistingProfile(byUserId, byMobile);

    if (existing != null) {
      final existingId = (existing['_id'] ?? '').toString();
      if (existingId.isNotEmpty) {
        final existingUsername = (existing['username'] ?? '').toString();
        // Never overwrite a real username with a provisional one.
        final nextUsername =
            isPlaceholderUsername(username, mainUserId) &&
                    !isPlaceholderUsername(existingUsername, mainUserId)
                ? existingUsername
                : username;

        _log(
          'existing profile mongoId=$existingId — '
          'updating instead of create (username=$nextUsername)',
        );
        await _putFullProfile(
          playMongoId: existingId,
          mainUserId: mainUserId,
          username: nextUsername,
          name: name.isNotEmpty
              ? name
              : (existing['name'] ?? '').toString(),
          existing: existing,
          mobile: mobile,
        );
        await syncMainUserId(playMongoId: existingId, mainUserId: mainUserId);
        return existingId;
      }
    }

    final createdId = await _postCreate(
      mainUserId,
      mobile,
      username,
      name: name,
    );
    await syncMainUserId(playMongoId: createdId, mainUserId: mainUserId);
    return createdId;
  }

  /// When duplicates exist, keep the older mongo ObjectId (original account).
  static Map<String, dynamic>? _preferExistingProfile(
    Map<String, dynamic>? a,
    Map<String, dynamic>? b,
  ) {
    if (a == null) return b;
    if (b == null) return a;
    final idA = (a['_id'] ?? '').toString();
    final idB = (b['_id'] ?? '').toString();
    if (idA.isEmpty) return b;
    if (idB.isEmpty) return a;
    if (idA == idB) return a;
    // ObjectId hex is time-sortable — smaller = older = original profile.
    return idA.compareTo(idB) <= 0 ? a : b;
  }

  Future<Map<String, dynamic>?> _lookupByShopUserId(String mainUserId) async {
    final id = mainUserId.trim();
    if (id.isEmpty) return null;
    try {
      final url = '$_fourthBaseUrl/users/$id';
      _log('GET $url (shop userid lookup)');
      final res = await http.get(Uri.parse(url), headers: _headers);
      _log('GET users/$id status=${res.statusCode} body=${res.body}');
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final body = jsonDecode(res.body);
      if (body is Map) {
        if (body['data'] is List && (body['data'] as List).isNotEmpty) {
          final first = (body['data'] as List).first;
          if (first is Map && (first['_id'] ?? '').toString().isNotEmpty) {
            return Map<String, dynamic>.from(first);
          }
        }
        if ((body['_id'] ?? '').toString().isNotEmpty) {
          return Map<String, dynamic>.from(body);
        }
      }
    } catch (e) {
      _log('lookupByShopUserId error: $e');
    }
    return null;
  }

  /// Sets the real username on an already-bootstrapped play profile.
  Future<void> updateUsername({
    required String playMongoId,
    required String username,
    required String mainUserId,
    String name = '',
    String mobile = '',
  }) async {
    final existing = await _fetchUserMap(playMongoId) ??
        (mobile.isNotEmpty ? await _lookupByMobile(mobile) : null) ??
        <String, dynamic>{};

    await _putFullProfile(
      playMongoId: playMongoId,
      mainUserId: mainUserId,
      username: username.trim(),
      name: name.trim().isNotEmpty
          ? name.trim()
          : (existing['name'] ?? '').toString(),
      existing: existing,
      mobile: mobile.isNotEmpty
          ? mobile
          : (existing['mobile'] ?? '').toString(),
    );
  }

  Future<String> _postCreate(
    String mainUserId,
    String mobile,
    String username, {
    String name = '',
  }) async {
    final payload = {
      'userid': encodeUserId(mainUserId),
      'username': username,
      'mobile': mobile,
      'name': name.isNotEmpty ? name : username,
    };
    final url = '$_fourthBaseUrl/users/';
    _log('POST $url payload=$payload');

    final response = await http.post(
      Uri.parse(url),
      headers: _headers,
      body: jsonEncode(payload),
    );

    _log(
      'POST /users/ status=${response.statusCode} body=${response.body}',
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
    _log(
      'created mongoId=$id '
      'userid=${body['userid']} username=${body['username']} name=${body['name']}',
    );
    return id;
  }

  Future<Map<String, dynamic>?> _lookupByMobile(String mobile) async {
    final m = mobile.trim();
    if (m.isEmpty) return null;
    final candidates = <String>{
      m,
      if (m.startsWith('+')) m.substring(1),
      if (m.startsWith('91') && m.length > 10) m.substring(2),
      if (!m.startsWith('+') && !m.startsWith('91') && m.length == 10) '91$m',
    };

    for (final candidate in candidates) {
      try {
        final url = '$_fourthBaseUrl/users/bymobile/$candidate';
        _log('GET $url');
        final lookup = await http.get(
          Uri.parse(url),
          headers: _headers,
        );
        _log(
          'GET bymobile/$candidate status=${lookup.statusCode} '
          'body=${lookup.body}',
        );
        if (lookup.statusCode < 200 || lookup.statusCode >= 300) continue;
        final body = jsonDecode(lookup.body);
        if (body is Map && (body['_id'] ?? '').toString().isNotEmpty) {
          return Map<String, dynamic>.from(body);
        }
      } catch (e) {
        _log('GET bymobile/$candidate error: $e');
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchUserMap(String playMongoId) async {
    final mongoId = playMongoId.trim();
    if (mongoId.isEmpty) return null;

    try {
      final lookup = await http.get(
        Uri.parse('$_fourthBaseUrl/users/userpost/$mongoId'),
        headers: _headers,
      );
      if (lookup.statusCode >= 200 && lookup.statusCode < 300) {
        final body = jsonDecode(lookup.body);
        if (body is Map && body['user'] is Map) {
          return Map<String, dynamic>.from(body['user'] as Map);
        }
      }

      final direct = await http.get(
        Uri.parse('$_fourthBaseUrl/users/$mongoId'),
        headers: _headers,
      );
      if (direct.statusCode >= 200 && direct.statusCode < 300) {
        final body = jsonDecode(direct.body);
        if (body is Map) return Map<String, dynamic>.from(body);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _putFullProfile({
    required String playMongoId,
    required String mainUserId,
    required String username,
    required String name,
    required Map<String, dynamic> existing,
    required String mobile,
  }) async {
    final encodedId = encodeUserId(mainUserId);
    final payload = <String, dynamic>{
      // Server has been ignoring partial `{userid}` PUTs — send full doc.
      'userid': encodedId,
      'user_id': encodedId,
      'name': name.isNotEmpty ? name : (existing['name'] ?? username),
      'username': username,
      'email': existing['email'] ?? '',
      'mobile': mobile.isNotEmpty ? mobile : (existing['mobile'] ?? ''),
      'bio': existing['bio'] ?? '',
      'profilePicture': existing['profilePicture'] ?? '',
    };

    final url = '$_fourthBaseUrl/users/$playMongoId';
    _log('PUT $url payload=$payload');
    final response = await http.put(
      Uri.parse(url),
      headers: _headers,
      body: jsonEncode(payload),
    );
    _log(
      'PUT full status=${response.statusCode} body=${response.body}',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to update profile (${response.statusCode})');
    }
  }

  Future<bool> syncMainUserId({
    required String playMongoId,
    required String mainUserId,
  }) async {
    final mongoId = playMongoId.trim();
    final userId = mainUserId.trim();
    if (mongoId.isEmpty || userId.isEmpty) {
      _log(
        'syncMainUserId skipped — '
        'mongoId="$mongoId" mainUserId="$userId"',
      );
      return false;
    }

    try {
      final userMap = await _fetchUserMap(mongoId);
      if (userMap == null) {
        _log('syncMainUserId — profile not found mongoId=$mongoId');
        return false;
      }

      final current = (userMap['userid'] ?? userMap['user_id'] ?? '')
          .toString()
          .trim();
      if (current == userId) {
        _log('userid already set on play profile: $userId');
        return true;
      }

      _log(
        'backfilling userid — '
        'mongoId=$mongoId current="$current" → "$userId"',
      );

      await _putFullProfile(
        playMongoId: mongoId,
        mainUserId: userId,
        username: (userMap['username'] ?? '').toString(),
        name: (userMap['name'] ?? '').toString(),
        existing: userMap,
        mobile: (userMap['mobile'] ?? '').toString(),
      );

      // Verify — partial PUTs used to return 200 without actually saving.
      final verified = await _fetchUserMap(mongoId);
      final saved = (verified?['userid'] ?? verified?['user_id'] ?? '')
          .toString()
          .trim();
      final ok = saved == userId;
      _log(
        'userid verify after PUT — '
        'wanted="$userId" got="$saved" ok=$ok',
      );
      if (!ok && isUuidLike(saved)) {
        _log(
          'WARNING: server still stores UUID in userid. '
          'Backend may be overwriting/ignoring shop user_id on /users PUT.',
        );
      }
      return ok;
    } catch (e) {
      _log('syncMainUserId error: $e');
      return false;
    }
  }
}
