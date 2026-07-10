import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

import '../models/comment.dart';
import '../models/live_product.dart';
import '../models/music_track.dart';
import '../models/profile_post.dart';
import '../models/reel.dart';
import '../models/search_result.dart';
import '../models/user_profile.dart';
import '../utils/share_links.dart';
import 'device_id_store.dart';

// const _baseUrl = 'https://api.welfog.com/api';
const  _baseUrl = 'https://unnecessitous-domitila-unbudging.ngrok-free.dev/api';
const _secondBaseUrl = 'https://welfogapi.welfog.com/api';
const _prefetchLimit = 50;

class UploadReelResult {
  final String message;
  final String status;
  final String? reelId;
  final String? caption;
  final String? thumbnailUrl;
  final List<String> qualityVariants;

  const UploadReelResult({
    required this.message,
    this.status = 'processing',
    this.reelId,
    this.caption,
    this.thumbnailUrl,
    this.qualityVariants = const [],
  });

  factory UploadReelResult.fromResponseBody(Map<String, dynamic> body) {
    final reel = body['reel'];
    Map<String, dynamic>? reelMap;
    if (reel is Map) {
      reelMap = Map<String, dynamic>.from(reel);
    }

    final variantsRaw = reelMap?['qualityVariants'];
    final variants = variantsRaw is List
        ? variantsRaw.map((e) => e.toString()).toList()
        : <String>[];

    return UploadReelResult(
      message: body['message']?.toString() ??
          'Upload received. Your video is being prepared.',
      status: body['status']?.toString() ?? 'processing',
      reelId: reelMap?['id']?.toString() ?? reelMap?['_id']?.toString(),
      caption: reelMap?['caption']?.toString(),
      thumbnailUrl: reelMap?['thumbnailUrl']?.toString(),
      qualityVariants: variants,
    );
  }
}

class ReelUploadStatus {
  final String status;
  final String videoUrl;
  final List<String> qualityVariants;
  final String? thumbnailUrl;

  const ReelUploadStatus({
    required this.status,
    this.videoUrl = '',
    this.qualityVariants = const [],
    this.thumbnailUrl,
  });

  bool get hasHdQuality => qualityVariants.contains('720p');

  bool get isReady =>
      status.toLowerCase() == 'published' &&
      videoUrl.trim().isNotEmpty &&
      hasHdQuality;

  factory ReelUploadStatus.fromJson(Map<String, dynamic> json) {
    final variantsRaw = json['qualityVariants'];
    return ReelUploadStatus(
      status: json['status']?.toString() ?? 'processing',
      videoUrl: json['videoUrl']?.toString() ?? '',
      qualityVariants: variantsRaw is List
          ? variantsRaw.map((e) => e.toString()).toList()
          : const [],
      thumbnailUrl: json['thumbnailUrl']?.toString(),
    );
  }
}

class ReelsApi {
  final String viewerId;
  final String deviceId;

  /// Main app user id (numeric) from RN — used when generating share links.
  final String shareUserId;

  /// Fallback main user id when play profile is being set up.
  final String mainUserId;

  ReelsApi({
    required this.viewerId,
    required this.deviceId,
    this.shareUserId = '',
    this.mainUserId = '',
  });

  /// Numeric userid for `/plays/reel/:id/share/:userid` — never the play mongo id.
  String get _shareAuthorUserId {
    if (shareUserId.isNotEmpty) return shareUserId;
    if (mainUserId.isNotEmpty) return mainUserId;
    return '';
  }

  Map<String, String> get _headers {
    final resolvedDeviceId = deviceId.trim().isNotEmpty
        ? deviceId.trim()
        : DeviceIdStore.peekOrGenerate();
    return {
      'Accept': 'application/json',
      'x-android-id': resolvedDeviceId,
    };
  }

  Map<String, String> get _jsonHeaders => {
        ..._headers,
        'Content-Type': 'application/json',
      };

  Future<({List<Reel> reels, bool hasMore})> fetchReelsPage(
      {String exclude = ''}) async {
    final trimmedExclude = _trimExcludeIds(exclude);
    Object? lastError;

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await _fetchReelsOnce(
          exclude:
              attempt == 2 && trimmedExclude.isNotEmpty ? '' : trimmedExclude,
        );
      } catch (e) {
        lastError = e;
        final msg = e.toString();
        final retryable = msg.contains('(403)') ||
            msg.contains('(429)') ||
            msg.contains('(502)') ||
            msg.contains('(503)') ||
            msg.contains('(504)');
        if (!retryable || attempt == 2) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }

    throw lastError ?? Exception('Failed to load play');
  }

  Future<List<Reel>> fetchReels({String exclude = ''}) async {
    final page = await fetchReelsPage(exclude: exclude);
    return page.reels;
  }

  String _trimExcludeIds(String exclude) {
    if (exclude.isEmpty) return exclude;
    final ids = exclude.split(',').where((id) => id.trim().isNotEmpty).toList();
    if (ids.length <= 120) return ids.join(',');
    return ids.sublist(ids.length - 120).join(',');
  }

  Future<({List<Reel> reels, bool hasMore})> _fetchReelsOnce(
      {required String exclude}) async {
    final uri = Uri.parse('$_baseUrl/reels/shownew').replace(
      queryParameters: {
        'limit': '$_prefetchLimit',
        if (exclude.isNotEmpty) 'exclude': exclude,
        'userId': viewerId,
        'direction': 'next',
      },
    );

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load play (${response.statusCode})');
    }

    final body = jsonDecode(response.body);
    final reelsRaw = body is Map ? body['reels'] : null;
    if (reelsRaw is! List) return (reels: <Reel>[], hasMore: false);

    final rawCount = reelsRaw.length;
    final reels = reelsRaw
        .whereType<Map<String, dynamic>>()
        .map(Reel.fromJson)
        .where((r) => r.id.isNotEmpty && r.playbackUrl.isNotEmpty)
        .toList();
    return (reels: reels, hasMore: rawCount >= _prefetchLimit);
  }

  Future<void> toggleLike(String reelId) async {
    await http.put(
      Uri.parse('$_baseUrl/reels/like/$reelId'),
      headers: _jsonHeaders,
      body: jsonEncode({'userId': viewerId}),
    );
  }

  Future<void> toggleFollow(String targetUserId, {required bool follow}) async {
    final action = follow ? 'follow' : 'unfollow';
    await http.put(
      Uri.parse('$_baseUrl/users/$targetUserId/$action'),
      headers: _jsonHeaders,
      body: jsonEncode({'userId': viewerId, 'userid': viewerId}),
    );
  }

  Future<void> removeFollower(String followerUserId) async {
    await http.put(
      Uri.parse('$_baseUrl/users/$viewerId/remove-follower'),
      headers: _jsonHeaders,
      body: jsonEncode({'userId': followerUserId}),
    );
  }

  Future<List<ReelComment>> fetchComments(String reelId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/comment/reel/$reelId'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return [];
    final body = jsonDecode(response.body);
    if (body is! List) return [];
    return body
        .whereType<Map<String, dynamic>>()
        .map(ReelComment.fromJson)
        .toList();
  }

  Future<ReelComment?> addComment(String reelId, String text,
      {String? parentId}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/comment/new'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'user': viewerId,
        'reel': reelId,
        'text': text.trim(),
        'parentComment': parentId,
      }),
    );
    if (response.statusCode != 201) return null;
    final body = jsonDecode(response.body);
    if (body is Map<String, dynamic>) return ReelComment.fromJson(body);
    return null;
  }

  Future<void> likeComment(String commentId) async {
    await http.put(
      Uri.parse('$_baseUrl/comment/like/$commentId'),
      headers: _jsonHeaders,
      body: jsonEncode({'userId': viewerId}),
    );
  }

  Future<void> deleteComment(String commentId) async {
    await http.delete(
      Uri.parse('$_baseUrl/comment/delete/$commentId/$viewerId'),
      headers: _headers,
    );
  }

  Future<({bool success, String message})> deleteReel(String reelId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/reels/delete/$reelId/$viewerId'),
      headers: _headers,
    );
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    String msg = '';
    try {
      final body = jsonDecode(response.body);
      msg = (body is Map ? body['message']?.toString() : null) ?? '';
    } catch (_) {}
    return (success: ok, message: msg);
  }

  Future<({bool success, String message})> markInterest(
    String reelId,
    String action,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/userblocks/mark-interest'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'userId': viewerId,
        'reelId': reelId,
        'action': action,
      }),
    );
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    final ok = response.statusCode >= 200 &&
        response.statusCode < 300 &&
        body is Map &&
        body['success'] == true;
    return (
      success: ok,
      message: body is Map ? (body['message']?.toString() ?? '') : '',
    );
  }

  Future<List<LiveProduct>> fetchProductsForReel(String reelId) async {
    final uri =
        Uri.parse('$_secondBaseUrl/opensearch/products-by-video-link').replace(
      queryParameters: {'video_link': reelId, 'page': '1', 'size': '20'},
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) return [];
    final body = jsonDecode(response.body);
    if (body is! Map || body['success'] != true) return [];
    final products = body['products'];
    if (products is! List) return [];
    return products
        .whereType<Map<String, dynamic>>()
        .map(LiveProduct.fromJson)
        .toList();
  }

  Future<String> getShareMessage(String reelId) async {
    final uid = _shareAuthorUserId;
    if (uid.isEmpty) {
      return 'Check out this play on WELFOG!';
    }
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/plays/reel/$reelId/share/$uid'),
        headers: _headers,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        final link = body is Map ? body['shortLink']?.toString() : null;
        if (link != null && link.isNotEmpty) {
          return 'Check out this play on WELFOG!\n$link';
        }
      }
    } catch (_) {}
    return 'Check out this play on WELFOG!\n${ShareLinks.playReelUrl(reelId, uid)}';
  }

  Future<void> trackView(String reelId) async {
    await http.post(
      Uri.parse('$_baseUrl/reels/view'),
      headers: _jsonHeaders,
      body: jsonEncode({'reelId': reelId, 'userId': viewerId}),
    );
  }

  static final _mongoIdPattern = RegExp(r'^[0-9a-fA-F]{24}$');
  static final _numericIdPattern = RegExp(r'^\d+$');

  static bool isPlayProfileMongoId(String? value) {
    final id = value?.trim() ?? '';
    return id.isNotEmpty && _mongoIdPattern.hasMatch(id);
  }

  static bool _isDirectProfileLookupId(String id) {
    return _mongoIdPattern.hasMatch(id) || _numericIdPattern.hasMatch(id);
  }

  /// Resolves `/api/plays/p/{slug}` short links to a numeric play userid.
  Future<String?> resolveProfileShareSlug(String slug) async {
    final trimmed = slug.trim();
    if (trimmed.isEmpty || _isDirectProfileLookupId(trimmed)) return trimmed;

    final fromRedirect = await _profileIdFromShareRedirect(
      Uri.parse('$_baseUrl/plays/p/${Uri.encodeComponent(trimmed)}'),
    );
    return fromRedirect;
  }

  Future<String?> _profileIdFromShareRedirect(Uri uri) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', uri)
        ..headers.addAll(_headers)
        ..followRedirects = false;
      final response =
          await client.send(request).timeout(const Duration(seconds: 8));
      final location =
          response.headers['location'] ?? response.headers['Location'];
      final parsed = _parseProfileIdFromShareLocation(location);
      if (parsed != null) return parsed;

      if (response.statusCode >= 300 && response.statusCode < 400) return null;

      // Some environments may follow redirects before we see the header.
      final effective = response.request?.url.toString();
      if (effective != null && effective != uri.toString()) {
        return _parseProfileIdFromShareLocation(effective);
      }
    } catch (_) {
    } finally {
      client.close();
    }
    return null;
  }

  String? _parseProfileIdFromShareLocation(String? location) {
    if (location == null || location.isEmpty) return null;
    final dlMatch = RegExp(r'/plays/dl/profile/(\d+)').firstMatch(location);
    if (dlMatch != null) return dlMatch.group(1);
    final pMatch = RegExp(r'/plays/p/([^/?#]+)').firstMatch(location);
    final slug = pMatch?.group(1);
    if (slug != null && _isDirectProfileLookupId(slug)) return slug;
    return null;
  }

  Future<String?> resolveProfileUserId(String userId) async {
    if (userId.isEmpty) return null;
    final isMongoId = _mongoIdPattern.hasMatch(userId);
    if (isMongoId) {
      try {
        final res = await http.get(
          Uri.parse('$_baseUrl/users/userpost/$userId'),
          headers: _headers,
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final body = jsonDecode(res.body);
          if (body is Map && body['user'] is Map) {
            final uid = (body['user'] as Map)['userid']?.toString();
            if (uid != null && uid.isNotEmpty) return uid;
          }
        }
      } catch (_) {}
    }
    return userId;
  }

  Future<UserProfile> fetchUserProfile(String userId) async {
    var lookupId = userId.trim();
    if (lookupId.isEmpty) throw Exception('Profile id required');

    if (!_isDirectProfileLookupId(lookupId)) {
      final resolvedSlug = await resolveProfileShareSlug(lookupId);
      if (resolvedSlug != null && resolvedSlug.isNotEmpty) {
        lookupId = resolvedSlug;
      }
    }

    final profileUserId = await resolveProfileUserId(lookupId) ?? lookupId;
    http.Response response;
    try {
      response = await http.get(
        Uri.parse('$_baseUrl/users/$profileUserId'),
        headers: _headers,
      );
    } catch (e) {
      rethrow;
    }
    if (response.statusCode == 404 && profileUserId != lookupId) {
      response = await http.get(
        Uri.parse('$_baseUrl/users/$lookupId'),
        headers: _headers,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load profile (${response.statusCode})');
    }
    final body = jsonDecode(response.body);
    Map<String, dynamic>? data;
    if (body is Map<String, dynamic>) {
      if (body['data'] is List && (body['data'] as List).isNotEmpty) {
        data = (body['data'] as List).first as Map<String, dynamic>;
      } else {
        data = body;
      }
    } else if (body is List && body.isNotEmpty) {
      data = body.first as Map<String, dynamic>;
    }
    if (data == null) throw Exception('Invalid profile response');
    return UserProfile.fromJson(data);
  }

  Future<({List<ProfilePost> posts, bool hasMore})> fetchUserPosts(
    String profileMongoId, {
    int skip = 0,
    int limit = 9,
    bool playableOnly = false,
  }) async {
    final uri = Uri.parse('$_baseUrl/reels/others/$profileMongoId').replace(
      queryParameters: {
        'limit': '$limit',
        'skip': '$skip',
        if (viewerId.isNotEmpty) 'currentUserId': viewerId,
        if (playableOnly) 'playableOnly': '1',
      },
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load posts');
    }
    final body = jsonDecode(response.body);
    final List raw = body is List
        ? body
        : (body is Map ? (body['reels'] ?? body['data'] ?? []) as List : []);
    final posts = raw
        .whereType<Map<String, dynamic>>()
        .map(ProfilePost.fromJson)
        .toList();
    final hasMore =
        body is Map ? (body['hasMore'] == true) : posts.length >= limit;
    return (posts: posts, hasMore: hasMore && posts.isNotEmpty);
  }

  Future<({List<Reel> reels, bool hasMore, int rawCount})> fetchUserReelsPage(
    String profileMongoId, {
    int skip = 0,
    int limit = 50,
    String? excludeId,
    bool playableOnly = true,
  }) async {
    final uri = Uri.parse('$_baseUrl/reels/others/$profileMongoId').replace(
      queryParameters: {
        'limit': '$limit',
        'skip': '$skip',
        if (viewerId.isNotEmpty) 'currentUserId': viewerId,
        if (excludeId != null && excludeId.isNotEmpty) 'excludeId': excludeId,
        if (playableOnly) 'playableOnly': '1',
      },
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return (reels: <Reel>[], hasMore: false, rawCount: 0);
    }
    final body = jsonDecode(response.body);
    final reelsRaw = body is List
        ? body
        : (body is Map ? body['reels'] ?? body['data'] : null);
    if (reelsRaw is! List)
      return (reels: <Reel>[], hasMore: false, rawCount: 0);
    final rawCount = reelsRaw.length;
    final reels = reelsRaw
        .whereType<Map<String, dynamic>>()
        .map(Reel.fromJson)
        .where((r) => r.id.isNotEmpty && r.playbackUrl.isNotEmpty)
        .toList();
    final hasMore = body is Map ? (body['hasMore'] == true) : rawCount >= limit;
    return (reels: reels, hasMore: hasMore, rawCount: rawCount);
  }

  Future<List<Reel>> fetchUserReels(String profileMongoId) async {
    final result = await fetchUserReelsPage(profileMongoId);
    return result.reels;
  }

  Future<String> resolveFollowListUserId(String userId) async {
    if (userId.isEmpty) return userId;
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/$userId'),
        headers: _headers,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        Map<String, dynamic>? data;
        if (body is Map<String, dynamic>) {
          if (body['data'] is List && (body['data'] as List).isNotEmpty) {
            data = (body['data'] as List).first as Map<String, dynamic>;
          } else {
            data = body;
          }
        }
        if (data != null) {
          final uid = data['userid']?.toString();
          if (uid != null && uid.isNotEmpty) return uid;
          final id = data['_id']?.toString();
          if (id != null && id.isNotEmpty) return id;
        }
      }
    } catch (_) {}
    return userId;
  }

  Future<List<FollowUser>> fetchFollowList(
      String profileUserId, String type) async {
    if (profileUserId.isEmpty) return [];
    final queryType = type == 'following' ? 'following' : 'followers';
    final resolved = await resolveFollowListUserId(profileUserId);
    final response = await http.get(
      Uri.parse('$_baseUrl/users/userfollowing/$resolved').replace(
        queryParameters: {'type': queryType},
      ),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return [];
    final body = jsonDecode(response.body);
    if (body is! Map) return [];

    final raw = body[queryType];
    if (raw is! List) return [];

    final users = <FollowUser>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        users.add(FollowUser.fromJson(item));
      } else if (item is Map) {
        users.add(FollowUser.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return users;
  }

  /// List lengths include blocked users — matches Instagram-style profile counts.
  Future<({int followers, int following})> fetchFollowCounts(
      String profileUserId) async {
    if (profileUserId.isEmpty) return (followers: 0, following: 0);
    final results = await Future.wait([
      fetchFollowList(profileUserId, 'followers'),
      fetchFollowList(profileUserId, 'following'),
    ]);
    return (followers: results[0].length, following: results[1].length);
  }

  Future<UserProfile> updateUserProfile(
      String profileId, Map<String, dynamic> payload) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/users/$profileId'),
      headers: _jsonHeaders,
      body: jsonEncode(payload),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      final msg = body is Map
          ? (body['message']?.toString() ?? 'Update failed')
          : 'Update failed';
      throw Exception(msg);
    }
    final body = jsonDecode(response.body);
    if (body is Map<String, dynamic>) {
      if (body['success'] == false) {
        throw Exception(body['message']?.toString() ?? 'Update failed');
      }
      if (body['_id'] != null) return UserProfile.fromJson(body);
    }
    return fetchUserProfile(profileId);
  }

  Future<String> uploadProfilePicture(String profileId, File file) async {
    if (profileId.isEmpty) {
      throw Exception('Profile id missing');
    }
    if (!await file.exists()) {
      throw Exception('Image file not found');
    }

    final ext = p.extension(file.path).toLowerCase();
    final isPng = ext == '.png';
    final fileName =
        'profile_${DateTime.now().millisecondsSinceEpoch}${isPng ? '.png' : '.jpg'}';
    final contentType = isPng ? 'image/png' : 'image/jpeg';

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/uploads/upload-profile-pic/$profileId'),
    );
    request.headers.addAll(_headers);
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: fileName,
        contentType: MediaType.parse(contentType),
      ),
    );
    request.fields['folder'] = 'thumbnails';

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String msg = 'Failed to upload profile picture';
      if (response.body.isNotEmpty) {
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['message'] != null) {
            msg = body['message'].toString();
          }
        } catch (_) {}
      }
      throw Exception('$msg (${response.statusCode})');
    }

    if (response.body.isEmpty) {
      throw Exception('Upload succeeded but server returned empty response');
    }

    final body = jsonDecode(response.body);
    if (body is Map) {
      if (body['success'] == false) {
        throw Exception(body['message']?.toString() ?? 'Upload failed');
      }
      final url = body['profilePicture']?.toString() ??
          body['url']?.toString() ??
          body['imageUrl']?.toString();
      if (url != null && url.isNotEmpty) return url;
    }

    throw Exception('Upload succeeded but no image URL returned');
  }

  Future<void> removeProfilePicture(String profileId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/uploads/remove-profile-pic/$profileId'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to remove profile picture');
    }
  }

  Future<bool> blockUser(String targetUserId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/userblocks/block-user'),
      headers: _jsonHeaders,
      body: jsonEncode({'blockerId': viewerId, 'targetUserId': targetUserId}),
    );
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    return response.statusCode >= 200 &&
        response.statusCode < 300 &&
        (body is! Map || body['success'] != false);
  }

  Future<bool> unblockUser(String targetUserId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/userblocks/unblock-user'),
      headers: _jsonHeaders,
      body: jsonEncode({'unblockerId': viewerId, 'targetUserId': targetUserId}),
    );
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    return response.statusCode >= 200 &&
        response.statusCode < 300 &&
        (body is! Map || body['success'] != false);
  }

  /// GET /userblocks/blocked-users/{viewerId} — all ids the viewer has blocked.
  Future<Set<String>> fetchBlockedUserIds() async {
    if (viewerId.isEmpty) return {};
    final response = await http.get(
      Uri.parse('$_baseUrl/userblocks/blocked-users/$viewerId'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return {};

    final body = jsonDecode(response.body);
    if (body is! Map || body['success'] != true) return {};

    final raw = body['blockedUsers'];
    if (raw is! List) return {};

    final ids = <String>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final map =
          item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);
      for (final key in ['_id', 'id', 'userid', 'userId']) {
        final value = map[key]?.toString().trim();
        if (value != null && value.isNotEmpty) ids.add(value);
      }
    }
    return ids;
  }

  /// GET /plays/profile/{mongoProfileId}/share → { "shortLink": "https://api.welfog.com/api/plays/p/..." }
  Future<String> getProfileShareMessage(
    String profileMongoId, {
    bool isOwnProfile = false,
  }) async {
    final id = profileMongoId.trim();
    final headline = isOwnProfile
        ? 'Check out my profile on WELFOG!'
        : "Check out this user's profile on WELFOG!";
    if (!isPlayProfileMongoId(id)) return '';

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/plays/profile/$id/share'),
        headers: _headers,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        if (body is Map) {
          final link = body['shortLink']?.toString().trim();
          if (link != null && link.isNotEmpty) {
            return '$headline\n$link';
          }
        }
      }
    } catch (_) {}
    return '';
  }

  /// Returns only the short link from GET /plays/profile/{mongoId}/share.
  Future<String> getProfileShareUrl(String profileMongoId) async {
    final msg =
        await getProfileShareMessage(profileMongoId, isOwnProfile: true);
    if (msg.isEmpty) return '';
    final lines = msg.split('\n');
    return lines.length > 1 ? lines.last.trim() : '';
  }

  Future<SearchPopularResult> searchPopular({
    required String query,
    int videoPage = 1,
    int videoLimit = 20,
    int userPage = 1,
    int userLimit = 10,
  }) async {
    final trimmed = query.trim();
    final isSearchMode = trimmed.isNotEmpty;

    final params = <String, String>{
      'query': trimmed,
      'videoPage': '$videoPage',
      'videoLimit': '$videoLimit',
      if (viewerId.isNotEmpty) 'currentUserId': viewerId,
      if (viewerId.isNotEmpty) 'viewerId': viewerId,
    };

    if (isSearchMode) {
      params['userPage'] = '$userPage';
      params['userLimit'] = '$userLimit';
    }

    final uri = Uri.parse('$_baseUrl/users/search_populer')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Search failed (${response.statusCode})');
    }

    final body = jsonDecode(response.body);
    if (body is! Map) return const SearchPopularResult();

    final usersRaw = body['users'];
    final videosRaw = body['videos'];
    final users = usersRaw is List
        ? usersRaw
            .whereType<Map<String, dynamic>>()
            .map(SearchUserHit.fromJson)
            .where((u) => !u.isBlocked && u.username.isNotEmpty)
            .toList()
        : <SearchUserHit>[];

    final videos = videosRaw is List
        ? videosRaw
            .whereType<Map<String, dynamic>>()
            .map(SearchVideoHit.fromJson)
            .where((v) => !v.isBlocked && v.id.isNotEmpty)
            .toList()
        : <SearchVideoHit>[];

    return SearchPopularResult(
      users: isSearchMode ? users : const [],
      videos: videos,
      hasMoreVideos: body['hasMoreVideos'] == true,
    );
  }

  Future<Reel?> fetchReelById(String reelId) async {
    if (reelId.isEmpty) return null;

    final params = <String, String>{
      if (viewerId.isNotEmpty) 'currentUserId': viewerId,
    };

    final endpoints = [
      Uri.parse('$_baseUrl/reels/current/$reelId')
          .replace(queryParameters: params),
      Uri.parse('$_baseUrl/reels/reel/$reelId'),
    ];

    for (final uri in endpoints) {
      try {
        final response = await http.get(uri, headers: _headers);
        if (response.statusCode < 200 || response.statusCode >= 300) continue;
        final reel = _parseReelResponse(response.body);
        if (reel != null) return reel;
      } catch (_) {}
    }
    return null;
  }

  Reel? _parseReelResponse(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      final map = _extractReelMap(decoded);
      if (map == null) return null;
      final reel = Reel.fromJson(map);
      if (reel.id.isNotEmpty && reel.playbackUrl.isNotEmpty) return reel;
    } catch (_) {}
    return null;
  }

  static const _musicPageSize = 20;

  Future<MusicPageResult> fetchMusic({int page = 1, String query = ''}) async {
    final trimmed = query.trim();
    final isSearch = trimmed.isNotEmpty;
    final params = <String, String>{
      'page': '$page',
      'limit': '$_musicPageSize',
      if (isSearch) 'q': trimmed,
    };
    final endpoint = isSearch ? '$_baseUrl/music/search' : '$_baseUrl/music';
    final uri = Uri.parse(endpoint).replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load music (${response.statusCode})');
    }
    final body = jsonDecode(response.body);
    final items = _extractMusicItems(body, isSearch);
    final meta = body is Map ? body : <String, dynamic>{};
    final totalPages = meta['totalPages'] ?? meta['pagination']?['totalPages'];
    final explicitHasMore = meta['hasMore'] ??
        meta['hasNextPage'] ??
        meta['pagination']?['hasMore'];
    final hasMore = explicitHasMore is bool
        ? explicitHasMore
        : totalPages is num
            ? page < totalPages.toInt()
            : items.length >= _musicPageSize;
    return MusicPageResult(
      items: items.where((t) => t.id.isNotEmpty && t.url.isNotEmpty).toList(),
      hasMore: hasMore,
    );
  }

  List<MusicTrack> _extractMusicItems(dynamic body, bool isSearch) {
    List raw = [];
    if (body is List) {
      raw = body;
    } else if (body is Map) {
      if (isSearch) {
        if (body['data'] is List) {
          raw = body['data'] as List;
        } else if (body['songs'] is List) {
          raw = body['songs'] as List;
        } else if (body['results'] is List) {
          raw = body['results'] as List;
        }
      } else if (body['data'] is List) {
        raw = body['data'] as List;
      } else if (body['songs'] is List) {
        raw = body['songs'] as List;
      }
    }
    return raw
        .whereType<Map>()
        .map((e) => MusicTrack.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<UploadReelResult> uploadReelFull({
    required File videoFile,
    File? thumbnailFile,
    required String playUserId,
    required String mainUserId,
    required String username,
    required String caption,
    required int videoStartMs,
    required int videoEndMs,
    MusicTrack? music,
    String? musicId,
    int? musicStartMs,
    int? musicEndMs,
    double musicVolume = 1.0,
    double originalVolume = 1.0,
    void Function(double progress, String phase)? onProgress,
  }) async {
    if (!await videoFile.exists()) {
      throw Exception('Video file not found');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/reels/full-upload'),
    );
    request.headers.addAll(_headers);
    request.fields['user'] = playUserId;
    request.fields['userid'] = mainUserId;
    request.fields['username'] = username;
    request.fields['caption'] = caption;
    request.fields['videoStartTime'] = '${videoStartMs.round()}';
    request.fields['videoEndTime'] = '${videoEndMs.round()}';

    final track = music;
    final resolvedMusicId = (musicId ?? track?.id ?? '').trim();
    final hasMongoMusicId = MusicTrack.isMongoId(resolvedMusicId);

    final audioPayload = <String, dynamic>{
      'musicVolume': musicVolume.clamp(0.0, 1.0),
      'originalVolume': originalVolume.clamp(0.0, 1.0),
    };

    if (track != null && track.url.isNotEmpty && !hasMongoMusicId) {
      audioPayload['url'] = track.url;
      audioPayload['title'] = track.title;
      if (track.artist.isNotEmpty) audioPayload['artist'] = track.artist;
      final artwork = track.coverUrl;
      if (artwork != null && artwork.isNotEmpty) {
        audioPayload['artwork'] = artwork;
      }
    }

    if (hasMongoMusicId) {
      request.fields['musicId'] = resolvedMusicId;
    }
    if (track != null) {
      request.fields['musicStartTime'] = '${(musicStartMs ?? 0).round()}';
      request.fields['musicEndTime'] = '${(musicEndMs ?? 0).round()}';
    }
    request.fields['audioData'] = jsonEncode(audioPayload);

    request.files.add(
      await http.MultipartFile.fromPath(
        'video',
        videoFile.path,
        filename: 'video-${DateTime.now().millisecondsSinceEpoch}.mp4',
        contentType: MediaType.parse('video/mp4'),
      ),
    );

    if (thumbnailFile != null && await thumbnailFile.exists()) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'thumbnail',
          thumbnailFile.path,
          filename: 'thumb-${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: MediaType.parse('image/jpeg'),
        ),
      );
    }

    onProgress?.call(0.02, 'uploading');
    final streamed = await _sendMultipartWithProgress(request, onProgress);

    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200 && response.statusCode != 202) {
      String msg = 'Upload failed';
      if (response.body.isNotEmpty) {
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['message'] != null) {
            msg = body['message'].toString();
          }
        } catch (_) {}
      }
      throw Exception('$msg (${response.statusCode})');
    }

    var result = const UploadReelResult(
      message: 'Post shared. Preparing on your profile.',
    );
    if (response.body.isNotEmpty) {
      try {
        final body = jsonDecode(response.body);
        if (body is Map) {
          result = UploadReelResult.fromResponseBody(
            Map<String, dynamic>.from(body),
          );
        }
      } catch (_) {}
    }

    onProgress?.call(1.0, 'done');
    return UploadReelResult(
      message: 'Post shared. Preparing on your profile.',
      status: result.status,
      reelId: result.reelId,
      caption: result.caption,
      thumbnailUrl: result.thumbnailUrl,
      qualityVariants: result.qualityVariants,
    );
  }

  Future<ReelUploadStatus?> fetchReelUploadStatus(String reelId) async {
    if (reelId.isEmpty) return null;
    try {
      final uri = Uri.parse('$_baseUrl/reels/upload-status/$reelId');
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final body = jsonDecode(response.body);
      if (body is! Map) return null;
      return ReelUploadStatus.fromJson(Map<String, dynamic>.from(body));
    } catch (_) {
      return null;
    }
  }

  Future<http.StreamedResponse> _sendMultipartWithProgress(
    http.MultipartRequest request,
    void Function(double progress, String phase)? onProgress,
  ) async {
    final total = request.contentLength;
    final byteStream = request.finalize();
    var sent = 0;

    final trackedStream = byteStream.transform<List<int>>(
      StreamTransformer.fromHandlers(
        handleData: (chunk, sink) {
          sent += chunk.length;
          if (total > 0) {
            final fraction = (sent / total).clamp(0.0, 1.0);
            onProgress?.call(0.04 + (fraction * 0.94), 'uploading');
          }
          sink.add(chunk);
        },
      ),
    );

    final streamedRequest = http.StreamedRequest('POST', request.url)
      ..headers.addAll(request.headers)
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection;
    if (total >= 0) {
      streamedRequest.contentLength = total;
    }

    final client = http.Client();
    try {
      final responseFuture = client.send(streamedRequest);
      await trackedStream.pipe(streamedRequest.sink);
      return await responseFuture.timeout(const Duration(minutes: 5));
    } finally {
      client.close();
    }
  }

  Map<String, dynamic>? _extractReelMap(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body['reel'] is Map) {
        return Map<String, dynamic>.from(body['reel'] as Map);
      }
      if (body['data'] is Map) {
        return Map<String, dynamic>.from(body['data'] as Map);
      }
      return body;
    }
    if (body is Map) {
      final map = Map<String, dynamic>.from(body);
      if (map['reel'] is Map) {
        return Map<String, dynamic>.from(map['reel'] as Map);
      }
      if (map['data'] is Map) {
        return Map<String, dynamic>.from(map['data'] as Map);
      }
      return map;
    }
    return null;
  }
}
