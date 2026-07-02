import '../models/profile_post.dart';
import '../models/user_profile.dart';

/// In-memory cache for the signed-in user's profile screen.
/// Survives route push/pop within one app session; cleared on viewer change.
class MyProfileCacheEntry {
  final UserProfile profile;
  final List<ProfilePost> posts;
  final List<ProfilePost> pendingPosts;
  final int postsSkip;
  final bool hasMore;
  final int displayFollowersCount;
  final int displayFollowingCount;
  final int displayPostCount;

  const MyProfileCacheEntry({
    required this.profile,
    required this.posts,
    required this.pendingPosts,
    required this.postsSkip,
    required this.hasMore,
    required this.displayFollowersCount,
    required this.displayFollowingCount,
    required this.displayPostCount,
  });
}

class MyProfileCache {
  MyProfileCache._();

  static String? _viewerId;
  static MyProfileCacheEntry? _entry;

  static bool hasFor(String viewerId) {
    final id = viewerId.trim();
    return id.isNotEmpty && _viewerId == id && _entry != null;
  }

  static MyProfileCacheEntry? peek(String viewerId) {
    if (!hasFor(viewerId)) return null;
    final entry = _entry!;
    return MyProfileCacheEntry(
      profile: entry.profile,
      posts: List<ProfilePost>.of(entry.posts),
      pendingPosts: List<ProfilePost>.of(entry.pendingPosts),
      postsSkip: entry.postsSkip,
      hasMore: entry.hasMore,
      displayFollowersCount: entry.displayFollowersCount,
      displayFollowingCount: entry.displayFollowingCount,
      displayPostCount: entry.displayPostCount,
    );
  }

  static void put(String viewerId, MyProfileCacheEntry entry) {
    final id = viewerId.trim();
    if (id.isEmpty) return;
    _viewerId = id;
    _entry = MyProfileCacheEntry(
      profile: entry.profile,
      posts: List<ProfilePost>.of(entry.posts),
      pendingPosts: List<ProfilePost>.of(entry.pendingPosts),
      postsSkip: entry.postsSkip,
      hasMore: entry.hasMore,
      displayFollowersCount: entry.displayFollowersCount,
      displayFollowingCount: entry.displayFollowingCount,
      displayPostCount: entry.displayPostCount,
    );
  }

  static void clear({String? viewerId}) {
    if (viewerId == null || _viewerId == viewerId) {
      _viewerId = null;
      _entry = null;
    }
  }
}
