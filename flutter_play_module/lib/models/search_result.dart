class SearchUserHit {
  final String id;
  final String? userid;
  final String username;
  final String? profilePicture;
  final String? bio;
  final int followersCount;
  final bool isBlocked;

  SearchUserHit({
    required this.id,
    this.userid,
    this.username = '',
    this.profilePicture,
    this.bio,
    this.followersCount = 0,
    this.isBlocked = false,
  });

  String get targetUserId => userid?.isNotEmpty == true ? userid! : id;

  factory SearchUserHit.fromJson(Map<String, dynamic> json) {
    return SearchUserHit(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      userid: json['userid']?.toString(),
      username: json['username']?.toString() ?? json['name']?.toString() ?? '',
      profilePicture: json['profilePicture']?.toString(),
      bio: json['bio']?.toString(),
      followersCount: (json['followersCount'] as num?)?.toInt() ??
          (json['followers'] is List ? (json['followers'] as List).length : 0),
      isBlocked: json['isBlocked'] == true || json['blocked'] == true,
    );
  }

  Map<String, dynamic> toRecentJson() => {
        'userid': targetUserId,
        'username': username,
        'profilePicture': profilePicture,
        'bio': bio,
      };

  factory SearchUserHit.fromRecentJson(Map<String, dynamic> json) {
    return SearchUserHit(
      id: json['userid']?.toString() ?? '',
      userid: json['userid']?.toString(),
      username: json['username']?.toString() ?? '',
      profilePicture: json['profilePicture']?.toString(),
      bio: json['bio']?.toString(),
    );
  }
}

class SearchVideoHit {
  final String id;
  final String? thumbnailUrl;
  final String? userId;
  final String? ownerUserid;
  final bool isBlocked;

  SearchVideoHit({
    required this.id,
    this.thumbnailUrl,
    this.userId,
    this.ownerUserid,
    this.isBlocked = false,
  });

  factory SearchVideoHit.fromJson(Map<String, dynamic> json) {
    return SearchVideoHit(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString() ??
          json['thumbnail']?.toString() ??
          json['posterUrl']?.toString(),
      userId: json['user']?.toString(),
      ownerUserid: json['userid']?.toString(),
      isBlocked: json['isBlocked'] == true || json['blocked'] == true,
    );
  }
}

class SearchPopularResult {
  final List<SearchUserHit> users;
  final List<SearchVideoHit> videos;
  final bool hasMoreVideos;

  const SearchPopularResult({
    this.users = const [],
    this.videos = const [],
    this.hasMoreVideos = false,
  });
}
