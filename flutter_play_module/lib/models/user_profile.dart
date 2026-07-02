class UserProfile {
  final String id;
  final String? userid;
  final String username;
  final String name;
  final String? email;
  final String? mobile;
  final String? bio;
  final String? profilePicture;
  final int postCount;
  final int followersCount;
  final int followingCount;
  final bool isDeleted;
  final bool isConnected;
  final String? sellerId;
  final List<String> followers;
  final List<String> following;

  UserProfile({
    required this.id,
    this.userid,
    this.username = '',
    this.name = '',
    this.email,
    this.mobile,
    this.bio,
    this.profilePicture,
    this.postCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isDeleted = false,
    this.isConnected = false,
    this.sellerId,
    this.followers = const [],
    this.following = const [],
  });

  String get displayName {
    final n = name.trim();
    if (n.isNotEmpty && n.toLowerCase() != 'user') return n;
    final u = username.trim();
    if (u.isNotEmpty && u.toLowerCase() != 'user') return u;
    return 'User';
  }

  bool isFollowedBy(String viewerId) {
    if (viewerId.isEmpty) return false;
    return followers.any((f) => f == viewerId);
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final followersRaw = json['followers'];
    final followingRaw = json['following'];
    final followers = followersRaw is List
        ? followersRaw.map((e) => e.toString()).toList()
        : <String>[];
    final following = followingRaw is List
        ? followingRaw.map((e) => e.toString()).toList()
        : <String>[];

    // Compute isConnected — same logic as RN Play Profile
    final rawSellerId = json['seller_id']?.toString() ?? json['sellerId']?.toString();
    final sellerIdValid = rawSellerId != null &&
        rawSellerId.isNotEmpty &&
        rawSellerId != 'null' &&
        rawSellerId != 'undefined';
    final apiConnected = json['isConnected'] == true ||
        json['isConnected'] == 'true' ||
        json['is_connected'] == true ||
        json['is_connected'] == 'true';

    return UserProfile(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      userid: json['userid']?.toString(),
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString(),
      mobile: json['mobile']?.toString() ?? json['phone']?.toString(),
      bio: json['bio']?.toString(),
      profilePicture: json['profilePicture']?.toString(),
      postCount: _readCount(json, ['postCount', 'postno', 'posts'], fallback: 0),
      followersCount: _readCount(
        json,
        ['followerno', 'followersCount', 'followerCount'],
        fallback: followers.length,
      ),
      followingCount: _readFollowingCount(json, following),
      isDeleted: json['isDeleted'] == true,
      isConnected: apiConnected || sellerIdValid,
      sellerId: sellerIdValid ? rawSellerId : null,
      followers: followers,
      following: following,
    );
  }

  static int _readCount(Map<String, dynamic> json, List<String> keys, {required int fallback}) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  static int _readFollowingCount(Map<String, dynamic> json, List<String> following) {
    final raw = json['following'];
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return _readCount(json, ['followingCount', 'followingno'], fallback: following.length);
  }
}

class FollowUser {
  final String id;
  final String? userid;
  final String username;
  final String? profilePicture;

  FollowUser({
    required this.id,
    this.userid,
    this.username = '',
    this.profilePicture,
  });

  factory FollowUser.fromJson(Map<String, dynamic> json) {
    final nested = json['user'];
    final src = nested is Map<String, dynamic>
        ? nested
        : nested is Map
            ? Map<String, dynamic>.from(nested)
            : json;

    return FollowUser(
      id: src['_id']?.toString() ?? src['id']?.toString() ?? json['_id']?.toString() ?? '',
      userid: src['userid']?.toString() ?? json['userid']?.toString(),
      username: src['username']?.toString() ?? src['name']?.toString() ?? 'User',
      profilePicture: src['profilePicture']?.toString() ??
          src['avatar']?.toString() ??
          json['profilePicture']?.toString(),
    );
  }
}
