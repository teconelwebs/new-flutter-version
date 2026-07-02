import '../utils/cdn_url.dart';

class ReelProduct {
  final String id;
  final String name;
  final dynamic price;
  final String? imageUrl;
  final String? slug;

  ReelProduct({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.slug,
  });

  factory ReelProduct.fromJson(Map<String, dynamic> json) {
    // Try multiple common image field names
    String? rawImg = json['imageUrl']?.toString() ??
        json['thumbnail_img']?.toString() ??
        json['image']?.toString() ??
        json['img']?.toString() ??
        json['thumbnail']?.toString();
    String? finalImg;
    if (rawImg != null && rawImg.isNotEmpty) {
      finalImg = cdnImageUrl(rawImg);
    }
    return ReelProduct(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: json['price'] ?? json['active_price'],
      imageUrl: finalImg,
      slug: json['slug']?.toString(),
    );
  }
}

class ReelUser {
  final String id;
  final String? username;
  final String? avatar;

  ReelUser({required this.id, this.username, this.avatar});

  String get displayName {
    final name = username?.trim();
    if (name != null && name.isNotEmpty && name.toLowerCase() != 'user') return name;
    return 'User';
  }

  factory ReelUser.fromDynamic(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return ReelUser(
        id: raw['_id']?.toString() ?? raw['id']?.toString() ?? '',
        username: raw['username']?.toString() ?? raw['name']?.toString(),
        avatar: raw['profilePicture']?.toString() ??
            raw['avatar']?.toString() ??
            raw['profilePic']?.toString(),
      );
    }
    if (raw != null) {
      return ReelUser(id: raw.toString());
    }
    return ReelUser(id: '');
  }

  /// Match Play tab: item.user?.username ?? item.username
  static ReelUser fromReelJson(Map<String, dynamic> json) {
    final base = ReelUser.fromDynamic(json['user']);
    final id = base.id.isNotEmpty
        ? base.id
        : (json['userId']?.toString() ?? json['userid']?.toString() ?? '');

    final username = _firstNonEmpty([
      base.username,
      json['username']?.toString(),
      json['reelUsername']?.toString(),
      json['name']?.toString(),
    ]);

    final avatar = _firstNonEmpty([
      base.avatar,
      json['reelUserProfilePic']?.toString(),
      json['profilePicture']?.toString(),
      json['avatar']?.toString(),
      json['user'] is Map ? (json['user'] as Map)['profilePicture']?.toString() : null,
    ]);

    return ReelUser(id: id, username: username, avatar: avatar);
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }
}

class Reel {
  final String id;
  final String videoUrl;
  final String? hlsUrl;
  final String? masterHlsUrl;
  final ReelUser user;
  final List<String> likes;
  final bool isFollowing;
  final int likeCount;
  final int commentCount;
  final int viewCount;
  final String caption;
  final String? music;
  final String? musicId;
  final String? thumbnailUrl;
  final List<ReelProduct> products;
  final DateTime? createdAt;
  final List<String> qualityVariants;

  Reel({
    required this.id,
    required this.videoUrl,
    this.hlsUrl,
    this.masterHlsUrl,
    required this.user,
    this.likes = const [],
    this.isFollowing = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.viewCount = 0,
    this.caption = '',
    this.music,
    this.musicId,
    this.thumbnailUrl,
    this.products = const [],
    this.createdAt,
    this.qualityVariants = const [],
  });

  bool isLikedBy(String viewerId) {
    if (viewerId.isEmpty) return false;
    return likes.any((id) => id == viewerId);
  }

  factory Reel.fromJson(Map<String, dynamic> json) {
    final likesRaw = json['likes'];
    final likes = likesRaw is List
        ? likesRaw.map((e) => e.toString()).toList()
        : <String>[];

    final productsRaw = json['products'];
    final products = productsRaw is List
        ? productsRaw
            .whereType<Map<String, dynamic>>()
            .map(ReelProduct.fromJson)
            .toList()
        : <ReelProduct>[];

    final musicParsed = _parseMusic(json);
    final variantsRaw = json['qualityVariants'];
    final variants = variantsRaw is List
        ? variantsRaw.map((e) => e.toString()).toList()
        : <String>[];

    return Reel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      videoUrl: ReelUser._firstNonEmpty([
        json['videoUrl']?.toString(),
        json['video_link']?.toString(),
        json['url']?.toString(),
        json['playbackUrl']?.toString(),
      ]) ?? '',
      hlsUrl: json['hlsUrl']?.toString(),
      masterHlsUrl: json['masterHlsUrl']?.toString(),
      user: ReelUser.fromReelJson(json),
      likes: likes,
      isFollowing: json['isFollowing'] == true,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? likes.length,
      commentCount: (json['totalCommentsCount'] as num?)?.toInt() ??
          (json['commentsCount'] as num?)?.toInt() ??
          (json['comments'] is List ? (json['comments'] as List).length : 0),
      viewCount: (json['views'] as num?)?.toInt() ?? 0,
      caption: json['caption']?.toString() ?? '',
      music: musicParsed.$1,
      musicId: musicParsed.$2,
      thumbnailUrl: json['thumbnailUrl']?.toString() ??
          json['thumbnail']?.toString() ??
          json['posterUrl']?.toString(),
      products: products,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      qualityVariants: variants,
    );
  }

  static (String?, String?) _parseMusic(Map<String, dynamic> json) {
    final raw = json['music'];
    if (raw is Map) {
      final id = raw['_id']?.toString();
      final title = raw['title']?.toString() ?? raw['name']?.toString();
      return (title, id);
    }
    if (raw is String && raw.isNotEmpty) {
      final isObjectId = RegExp(r'^[a-f0-9]{24}$', caseSensitive: false).hasMatch(raw);
      if (isObjectId) {
        final title = json['musicTitle']?.toString() ?? json['musicName']?.toString();
        return (title, raw);
      }
      return (raw, null);
    }
    return (null, null);
  }

  String get _masterHlsUrl {
    if (masterHlsUrl != null && masterHlsUrl!.isNotEmpty) return masterHlsUrl!;
    if (hlsUrl != null && hlsUrl!.isNotEmpty) return hlsUrl!;
    return videoUrl;
  }

  /// Prefer 720p HLS when available — master.m3u8 often starts playback at 240p.
  String get playbackUrl {
    final master = _masterHlsUrl;
    if (qualityVariants.contains('720p') && master.contains('master.m3u8')) {
      return master.replaceFirst('master.m3u8', '720p/index.m3u8');
    }
    if (qualityVariants.contains('480p') && master.contains('master.m3u8')) {
      return master.replaceFirst('master.m3u8', '480p/index.m3u8');
    }
    return master;
  }

  /// Adaptive ladder for slow networks (optional fallback).
  String get adaptivePlaybackUrl => _masterHlsUrl;

  /// Direct MP4 / master fallback when variant playlist fails.
  String? get mp4FallbackUrl {
    final master = _masterHlsUrl;
    if (master.isEmpty) return null;
    if (playbackUrl == master) return null;
    if (master.contains('master.m3u8')) return master;
    return null;
  }
}
