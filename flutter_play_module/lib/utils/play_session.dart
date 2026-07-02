import 'package:flutter/material.dart';

import '../models/play_launch_context.dart';
import '../models/search_result.dart';
import '../services/device_id_store.dart';
import '../services/reels_api.dart';
import 'my_profile_cache.dart';
import 'viewer_id_helper.dart';

/// Global handle so pushed routes (profile, edit, search) can access the active session.
/// Flutter Navigator pushes routes as siblings — they are NOT under the root PlaySessionScope.
class PlaySessionRegistry {
  static PlaySessionScopeState? _scope;
  static final Set<String> blockedUserIds = {};

  static bool _hasLoaded = false;
  static String? _loadedForViewer;
  static String? _loadingForViewer;
  static Future<void>? _loadFuture;

  static void register(PlaySessionScopeState scope) => _scope = scope;

  static void unregister(PlaySessionScopeState scope) {
    if (_scope == scope) _scope = null;
  }

  static PlaySessionScopeState? get scope => _scope;

  static void resetBlockedListCache() {
    _hasLoaded = false;
    _loadedForViewer = null;
    _loadFuture = null;
  }

  /// Loads blocked users from API once per viewer session, merges with local marks.
  static Future<void> ensureBlockedListLoaded(ReelsApi api) async {
    final viewer = api.viewerId.trim();
    if (viewer.isEmpty) return;

    if (_hasLoaded && _loadedForViewer == viewer) return;

    if (_loadFuture != null && _loadingForViewer == viewer) {
      return _loadFuture!;
    }

    _loadingForViewer = viewer;
    _loadFuture = () async {
      try {
        final serverIds = await api.fetchBlockedUserIds();
        blockedUserIds.addAll(serverIds);
        _loadedForViewer = viewer;
        _hasLoaded = true;
      } catch (_) {
        // Keep any locally marked ids if API fails.
      } finally {
        _loadFuture = null;
      }
    }();
    return _loadFuture!;
  }

  /// Called when a user is blocked from their profile screen.
  static void markUserBlocked(String userId) {
    final id = userId.trim();
    if (id.isNotEmpty) blockedUserIds.add(id);
  }

  static void markUserUnblocked(String userId) {
    final id = userId.trim();
    if (id.isNotEmpty) blockedUserIds.remove(id);
  }

  static bool isUserBlocked(String userId) {
    final id = userId.trim();
    return id.isNotEmpty && blockedUserIds.contains(id);
  }

  static bool isAnyIdBlocked(Iterable<String> ids) {
    for (final raw in ids) {
      if (isUserBlocked(raw)) return true;
    }
    return false;
  }

  static void markProfileBlocked({required String id, String? userid}) {
    markUserBlocked(id);
    final uid = userid?.trim();
    if (uid != null && uid.isNotEmpty) markUserBlocked(uid);
  }

  static void markProfileUnblocked({required String id, String? userid}) {
    markUserUnblocked(id);
    final uid = userid?.trim();
    if (uid != null && uid.isNotEmpty) markUserUnblocked(uid);
  }

  static bool isProfileBlocked({
    required String profileId,
    String? profileUserid,
    String? routeUserId,
  }) {
    return isAnyIdBlocked([
      if (routeUserId != null) routeUserId,
      profileId,
      if (profileUserid != null) profileUserid,
    ]);
  }

  static bool isSearchUserBlocked(SearchUserHit user) {
    return isAnyIdBlocked([user.id, if (user.userid != null) user.userid!]);
  }

  static bool isSearchVideoBlocked(SearchVideoHit video) {
    return isAnyIdBlocked([
      if (video.userId != null) video.userId!,
      if (video.ownerUserid != null) video.ownerUserid!,
    ]);
  }

  static final Map<String, bool> _followOverrides = {};

  /// Persists follow/unfollow across reel ↔ profile navigation within one session.
  static void setFollowState({
    required bool following,
    required String id,
    String? userid,
  }) {
    final trimmed = id.trim();
    if (trimmed.isNotEmpty) _followOverrides[trimmed] = following;
    final uid = userid?.trim();
    if (uid != null && uid.isNotEmpty) _followOverrides[uid] = following;
  }

  static bool resolveFollowState({
    required String userId,
    String? alternateId,
    required bool fallback,
  }) {
    for (final raw in [userId, if (alternateId != null) alternateId]) {
      final id = raw.trim();
      if (id.isEmpty) continue;
      if (_followOverrides.containsKey(id)) return _followOverrides[id]!;
    }
    return fallback;
  }

  static final Map<String, bool> _likeOverrides = {};
  static final Map<String, int> _likeCountOverrides = {};

  /// Persists reel like state across scroll / route changes within one session.
  static void setLikeState({
    required String reelId,
    required bool liked,
    required int likeCount,
  }) {
    final id = reelId.trim();
    if (id.isEmpty) return;
    _likeOverrides[id] = liked;
    _likeCountOverrides[id] = likeCount < 0 ? 0 : likeCount;
  }

  static bool resolveLikeState({
    required String reelId,
    required bool fallback,
  }) {
    final id = reelId.trim();
    if (id.isEmpty) return fallback;
    return _likeOverrides[id] ?? fallback;
  }

  static int resolveLikeCount({
    required String reelId,
    required int fallback,
  }) {
    final id = reelId.trim();
    if (id.isEmpty) return fallback;
    return _likeCountOverrides[id] ?? fallback;
  }
}

class PlaySession extends InheritedWidget {
  final ReelsApi api;
  final PlayLaunchContext launchContext;

  const PlaySession({
    super.key,
    required this.api,
    required this.launchContext,
    required super.child,
  });

  static PlaySession of(BuildContext context) {
    final session = context.getInheritedWidgetOfExactType<PlaySession>();
    assert(session != null, 'PlaySession not found in widget tree');
    return session!;
  }

  static ReelsApi apiOf(BuildContext context) => of(context).api;
  static PlayLaunchContext launchContextOf(BuildContext context) => of(context).launchContext;

  @override
  bool updateShouldNotify(PlaySession oldWidget) =>
      api.viewerId != oldWidget.api.viewerId ||
      launchContext.playProfileReady != oldWidget.launchContext.playProfileReady;
}

/// Holds mutable play session state (viewer id + profile setup flags).
class PlaySessionScope extends StatefulWidget {
  final String initialViewerId;
  final String deviceId;
  final String shareUserId;
  final PlayLaunchContext launchContext;
  final Widget child;

  const PlaySessionScope({
    super.key,
    required this.initialViewerId,
    required this.deviceId,
    required this.shareUserId,
    required this.launchContext,
    required this.child,
  });

  @override
  State<PlaySessionScope> createState() => PlaySessionScopeState();
}

class PlaySessionScopeState extends State<PlaySessionScope> {
  late String _viewerId;
  late PlayLaunchContext _launchContext;
  late String _deviceId;
  bool _setupDismissed = false;
  bool _sessionReady = false;

  @override
  void initState() {
    super.initState();
    _viewerId = widget.initialViewerId;
    _launchContext = widget.launchContext;
    _deviceId = widget.deviceId;
    _bootstrapSession();
  }

  Future<void> _bootstrapSession() async {
    if (_deviceId.trim().isEmpty) {
      // Sync fallback so the first API call never goes out without x-android-id.
      _deviceId = DeviceIdStore.peekOrGenerate();
      final persisted = await DeviceIdStore.getOrCreate();
      if (persisted.isNotEmpty) _deviceId = persisted;
    }
    if (!mounted) return;
    setState(() => _sessionReady = true);
    PlaySessionRegistry.register(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PlaySessionRegistry.ensureBlockedListLoaded(api);
    });
  }

  @override
  void dispose() {
    if (_sessionReady) PlaySessionRegistry.unregister(this);
    super.dispose();
  }

  bool get shouldOfferProfileSetup =>
      _launchContext.needsSetup && !_setupDismissed && !_launchContext.playProfileReady;

  void dismissProfileSetup() {
    if (_setupDismissed) return;
    setState(() => _setupDismissed = true);
  }

  void onProfileCreated(String playUserId) {
    PlaySessionRegistry.resetBlockedListCache();
    MyProfileCache.clear();
    setState(() {
      _viewerId = playUserId;
      _launchContext = PlayLaunchContext(
        mainUserId: _launchContext.mainUserId,
        mobile: _launchContext.mobile,
        playProfileReady: true,
      );
      _setupDismissed = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PlaySessionRegistry.ensureBlockedListLoaded(api);
    });
  }

  ReelsApi get api => ReelsApi(
        viewerId: resolveViewerIdForFeed(_viewerId, _deviceId),
        deviceId: _deviceId,
        shareUserId: widget.shareUserId,
        mainUserId: _launchContext.mainUserId,
      );

  PlayLaunchContext get launchContext => _launchContext;

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFfb5404)),
        ),
      );
    }
    return PlaySession(
      api: api,
      launchContext: _launchContext,
      child: widget.child,
    );
  }
}

PlaySessionScopeState? playSessionScopeOf(BuildContext context) {
  return context.findAncestorStateOfType<PlaySessionScopeState>() ??
      PlaySessionRegistry.scope;
}

/// Wraps a pushed route with the active [PlaySession] from the registry.
Widget wrapWithActivePlaySession(Widget child) {
  final scope = PlaySessionRegistry.scope;
  if (scope != null) {
    return PlaySession(
      api: scope.api,
      launchContext: scope.launchContext,
      child: child,
    );
  }
  // Share-link cold start — no RN session params; bootstrap a local guest session.
  return PlaySessionScope(
    initialViewerId: 'guest',
    deviceId: '',
    shareUserId: '',
    launchContext: const PlayLaunchContext(playProfileReady: true),
    child: child,
  );
}
