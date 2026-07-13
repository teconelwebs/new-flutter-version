import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/profile_post.dart';
import '../models/user_profile.dart';
import '../models/profile_reels_route_args.dart';
import '../services/reels_api.dart';
import '../utils/app_routes.dart';
import '../utils/format_count.dart';
import '../utils/format_time.dart';
import '../utils/flutter_nav.dart';
import '../utils/my_profile_cache.dart';
import '../utils/play_session.dart';
import '../utils/profile_theme.dart';
import '../utils/profile_thumbnail_cache.dart';
import '../widgets/play_profile_setup_sheet.dart';
import '../widgets/profile_widgets.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> with RouteAware {
  UserProfile? _profile;
  List<ProfilePost> _posts = [];
  List<ProfilePost> _pendingPosts = [];
  bool _loading = true;
  bool _loadingPosts = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _postsSkip = 0;
  bool _showFullBio = false;
  String? _error;
  bool _initialized = false;
  int? _displayFollowersCount;
  int? _displayFollowingCount;
  int? _displayPostCount;
  bool _needsProfileSetup = false;
  bool _setupOffered = false;
  final _usernameController = TextEditingController();
  bool _updatingUsername = false;
  bool _shareInProgress = false;
  Timer? _preparingPollTimer;
  final _scrollController = ScrollController();
  bool _routeSubscribed = false;

  @override
  void dispose() {
    _preparingPollTimer?.cancel();
    _scrollController.dispose();
    _usernameController.dispose();
    if (_routeSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    super.dispose();
  }

  String? _lastViewerId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_routeSubscribed) {
      final route = ModalRoute.of(context);
      if (route is PageRoute) {
        appRouteObserver.subscribe(this, route);
        _routeSubscribed = true;
      }
    }
    final currentViewerId = PlaySession.apiOf(context).viewerId;
    if (_lastViewerId != null && _lastViewerId != currentViewerId) {
      _lastViewerId = currentViewerId;
      _load(refresh: true);
    } else {
      _lastViewerId = currentViewerId;
      if (!_initialized) {
        _initialized = true;
        _load();
      }
    }
  }

  @override
  void didPopNext() {
    _load(refresh: true);
  }

  void _restoreFromCache(MyProfileCacheEntry cached) {
    setState(() {
      _profile = cached.profile;
      _posts = cached.posts;
      _pendingPosts = cached.pendingPosts;
      _postsSkip = cached.postsSkip;
      _hasMore = cached.hasMore;
      _displayFollowersCount = cached.displayFollowersCount;
      _displayFollowingCount = cached.displayFollowingCount;
      _displayPostCount = cached.displayPostCount;
      _loading = false;
      _loadingPosts = false;
      _loadingMore = false;
      _error = null;
      _needsProfileSetup = false;
    });
    _syncPreparingPoll();
  }

  void _persistCache() {
    final profile = _profile;
    if (profile == null) return;
    final api = PlaySession.apiOf(context);
    MyProfileCache.put(
      api.viewerId,
      MyProfileCacheEntry(
        profile: profile,
        posts: _posts,
        pendingPosts: _pendingPosts,
        postsSkip: _postsSkip,
        hasMore: _hasMore,
        displayFollowersCount: _displayFollowersCount ?? profile.followersCount,
        displayFollowingCount: _displayFollowingCount ?? profile.followingCount,
        displayPostCount: _displayPostCount ?? profile.postCount,
      ),
    );
  }

  Future<void> _load({bool refresh = false}) async {
    final api = PlaySession.apiOf(context);
    if (!refresh) {
      final cached = MyProfileCache.peek(api.viewerId);
      if (cached != null) {
        _restoreFromCache(cached);
        return;
      }
      setState(() => _loading = true);
    }
    final launchContext = PlaySession.launchContextOf(context);
    try {
      final profile = await api.fetchUserProfile(api.viewerId);
      final profileKey = profile.userid ?? profile.id;
      final counts = await api.fetchFollowCounts(profileKey);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _displayFollowersCount = counts.followers;
        _displayFollowingCount = counts.following;
        _displayPostCount = profile.postCount;
        _loading = false;
        _error = null;
        _needsProfileSetup = false;
      });
      await Future.wait([
        _fetchPosts(reset: true),
        _fetchPendingPosts(),
      ]);
      if (mounted) _persistCache();
    } catch (e) {
      if (!mounted) return;
      final needsSetup = launchContext.needsSetup;
      final is404 = e.toString().contains('404');
      final canCreateProfile = launchContext.mainUserId.isNotEmpty &&
          launchContext.mobile.isNotEmpty &&
          !launchContext.playProfileReady;
      final showSetup = needsSetup || (is404 && canCreateProfile);
      setState(() {
        _loading = false;
        _profile = null;
        _needsProfileSetup = showSetup;
        _error = showSetup ? null : e.toString();
      });
      if (showSetup) _maybeOfferProfileSetup();
    }
  }

  void _maybeOfferProfileSetup() {
    final scope = playSessionScopeOf(context);
    if (scope == null || !scope.shouldOfferProfileSetup || _setupOffered) return;
    _setupOffered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openProfileSetupSheet();
    });
  }

  void _openProfileSetupSheet() {
    final scope = playSessionScopeOf(context);
    if (scope == null) return;
    final launchContext = PlaySession.launchContextOf(context);
    final api = PlaySession.apiOf(context);
    PlayProfileSetupSheet.show(
      context,
      launchContext: launchContext,
      deviceId: api.deviceId,
      onCreated: (playUserId) {
        scope.onProfileCreated(playUserId);
        _load(refresh: true);
      },
      onDismissed: scope.dismissProfileSetup,
    );
  }

  Widget _buildCreateProfileState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFFFB5204), Color(0xFFFF8C00)]),
            ),
            child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 42),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Create Play Profile',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 10),
        const Text(
          'Create your Play profile to share videos, connect with others, and explore amazing content.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your Play profile is separate from your main account and lets you showcase your creative side.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _openProfileSetupSheet,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFB5204),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Create Play Profile', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Future<void> _fetchPosts({bool reset = false}) async {
    final profile = _profile;
    if (profile == null || _loadingPosts) return;
    setState(() => _loadingPosts = true);
    final api = PlaySession.apiOf(context);
    try {
      final skip = reset ? 0 : _postsSkip;
      final result = await api.fetchUserPosts(
        profile.id,
        skip: skip,
        playableOnly: true,
      );
      if (!mounted) return;
      final playable = result.posts.where((p) => p.isPlayable).toList();
      setState(() {
        if (reset) {
          _posts = playable;
          _postsSkip = playable.length;
        } else {
          _posts = [..._posts, ...playable];
          _postsSkip += playable.length;
        }
        _hasMore = result.hasMore;
        _loadingPosts = false;
        _loadingMore = false;
      });
      if (mounted && playable.isNotEmpty) {
        final tileW = (MediaQuery.sizeOf(context).width - 2) / 3;
        ProfileThumbnailCache.prefetchForGrid(
          context,
          urls: playable.map((p) => p.thumbnailUrl),
          tileWidth: tileW,
        );
      }
      if (mounted) _persistCache();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingPosts = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _fetchPendingPosts() async {
    final profile = _profile;
    if (profile == null) return;
    final api = PlaySession.apiOf(context);
    try {
      final result = await api.fetchUserPosts(profile.id, skip: 0, limit: 30);
      if (!mounted) return;
      setState(() {
        _pendingPosts = result.posts.where((p) => !p.isPlayable).toList();
      });
      _syncPreparingPoll();
      _persistCache();
    } catch (_) {}
  }

  Future<void> _syncPostCountFromServer() async {
    final profile = _profile;
    if (profile == null) return;
    final api = PlaySession.apiOf(context);
    try {
      final updated = await api.fetchUserProfile(profile.id);
      if (!mounted) return;
      setState(() => _displayPostCount = updated.postCount);
      _persistCache();
    } catch (_) {}
  }

  /// Poll only status fields for pending uploads — does not touch playable grid scroll.
  Future<void> _refreshPreparingStatuses() async {
    final profile = _profile;
    if (profile == null || _loadingPosts) return;
    if (_pendingPosts.isEmpty) return;

    final api = PlaySession.apiOf(context);
    try {
      final result = await api.fetchUserPosts(profile.id, skip: 0, limit: 30);
      if (!mounted) return;

      final byId = {for (final p in result.posts) p.id: p};
      var changed = false;
      var becamePlayable = false;
      var newlyPlayableCount = 0;
      final merged = _pendingPosts.map((existing) {
        final updated = byId[existing.id];
        if (updated == null) return existing;
        if (updated.isPlayable) {
          becamePlayable = true;
          newlyPlayableCount++;
          changed = true;
          return null;
        }
        if (updated.status != existing.status ||
            updated.videoUrl != existing.videoUrl ||
            updated.qualityVariants.length != existing.qualityVariants.length) {
          changed = true;
          return updated;
        }
        return existing;
      }).whereType<ProfilePost>().toList();

      if (changed) {
        setState(() {
          _pendingPosts = merged;
          if (newlyPlayableCount > 0) {
            final base = _displayPostCount ?? _profile?.postCount ?? 0;
            _displayPostCount = base + newlyPlayableCount;
          }
        });
        _persistCache();
      }
      if (becamePlayable) {
        await Future.wait([
          _fetchPosts(reset: true),
          _syncPostCountFromServer(),
        ]);
      }
      _syncPreparingPoll();
    } catch (_) {}
  }

  void _openFollowList(String type) async {
    final profile = _profile;
    if (profile == null) return;
    final userid = profile.userid ?? profile.id;
    await Navigator.pushNamed(
      context,
      '${AppRoutes.followList}?type=$type&userid=${Uri.encodeComponent(userid)}&own=1',
      arguments: PlaySession.apiOf(context),
    );
    if (!mounted) return;
    final api = PlaySession.apiOf(context);
    try {
      final counts = await api.fetchFollowCounts(userid);
      if (!mounted) return;
      setState(() {
        _displayFollowersCount = counts.followers;
        _displayFollowingCount = counts.following;
      });
      _persistCache();
    } catch (_) {}
  }

  // ignore: unused_element
  Future<void> _shareProfile() async {
    if (_shareInProgress) return;
    _shareInProgress = true;
    try {
      final profile = _profile;
      if (profile == null) return;
      final shareId = profile.id.trim();
      if (!ReelsApi.isPlayProfileMongoId(shareId)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile is not ready to share yet.')),
          );
        }
        return;
      }
      final msg = await PlaySession.apiOf(context).getProfileShareMessage(
        shareId,
        isOwnProfile: true,
      );
      if (msg.isEmpty || !msg.contains('api/plays/p/')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not generate profile share link.')),
          );
        }
        return;
      }
      await Share.share(msg);
    } finally {
      _shareInProgress = false;
    }
  }

  void _syncPreparingPoll() {
    final needsPoll = _pendingPosts.any((p) => p.isPreparing);
    if (needsPoll) {
      _preparingPollTimer ??= Timer.periodic(const Duration(seconds: 8), (_) {
        if (!mounted) return;
        if (_pendingPosts.any((p) => p.isPreparing)) {
          _refreshPreparingStatuses();
        } else {
          _preparingPollTimer?.cancel();
          _preparingPollTimer = null;
        }
      });
      return;
    }
    _preparingPollTimer?.cancel();
    _preparingPollTimer = null;
  }

  Future<void> _removePost(ProfilePost post, {bool showSnack = true, String? snackMessage}) async {
    final api = PlaySession.apiOf(context);
    final result = await api.deleteReel(post.id);
    if (!mounted) return;
    if (result.success) {
      final wasPlayable = _posts.any((p) => p.id == post.id);
      setState(() {
        _posts = _posts.where((p) => p.id != post.id).toList();
        _pendingPosts = _pendingPosts.where((p) => p.id != post.id).toList();
        if (wasPlayable) {
          final current = _displayPostCount ?? _profile?.postCount ?? 0;
          _displayPostCount = current > 0 ? current - 1 : 0;
        }
      });
      _syncPreparingPoll();
      _persistCache();
      if (showSnack) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(snackMessage ?? 'Post removed.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message.isEmpty ? 'Could not remove post.' : result.message)),
      );
    }
  }

  Future<void> _cancelFailedPost(ProfilePost post) => _removePost(post);

  Future<void> _cancelPreparingPost(ProfilePost post) =>
      _removePost(post, snackMessage: 'Preparing video removed.');

  Future<void> _retryFailedPost(ProfilePost post) async {
    await _removePost(post, showSnack: false);
    if (mounted) await _openCreatePost();
  }

  Future<void> _retryStalePost(ProfilePost post) async {
    await _removePost(post, showSnack: false);
    if (mounted) await _openCreatePost();
  }

  void _openPost(ProfilePost post, int index) {
    final profile = _profile;
    if (profile == null || !post.isPlayable) return;
    Navigator.pushNamed(
      context,
      '${AppRoutes.profileReels}?profileId=${Uri.encodeComponent(profile.id)}&reelId=${Uri.encodeComponent(post.id)}&gridIndex=$index',
      arguments: ProfileReelsRouteArgs(
        seedReelIds: _posts
            .where((p) => p.isPlayable)
            .map((p) => p.id)
            .where((id) => id.isNotEmpty)
            .toList(),
      ),
    );
  }

  bool get _standaloneProfile {
    final name = ModalRoute.of(context)?.settings.name ?? '';
    final uri = Uri.tryParse(name.startsWith('/') ? name : '/$name');
    return uri?.queryParameters['standalone'] == '1';
  }

  Future<void> _openCreatePost() async {
    final profile = _profile;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile not found. Please try again.')),
      );
      return;
    }

    if (isDefaultPlayUsername(profile.username)) {
      _usernameController.text = profile.username;
      final updated = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Update Username'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please set a custom username before posting videos.'),
              const SizedBox(height: 12),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: _updatingUsername ? null : () async {
                final newUsername = _usernameController.text.trim();
                if (newUsername.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please enter a username')),
                  );
                  return;
                }
                if (newUsername.toLowerCase() == profile.username.toLowerCase()) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please enter a different username')),
                  );
                  return;
                }
                if (isDefaultPlayUsername(newUsername)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Default usernames are not allowed')),
                  );
                  return;
                }
                setState(() => _updatingUsername = true);
                try {
                  final api = PlaySession.apiOf(context);
                  await api.updateUserProfile(profile.id, {
                    'name': profile.name,
                    'username': newUsername,
                    'email': profile.email ?? '',
                    'phone': profile.mobile ?? '',
                    'bio': profile.bio ?? '',
                    'profilePicture': profile.profilePicture ?? '',
                  });
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _updatingUsername = false);
                }
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFfb5204)),
              child: Text(_updatingUsername ? 'Saving...' : 'Save & Continue'),
            ),
          ],
        ),
      );
      if (updated == true) {
        await _load(refresh: true);
      } else {
        return;
      }
    }

    final refreshed = _profile ?? profile;
    if (!mounted) return;
    final uploaded = await Navigator.pushNamed<bool>(
      context,
      '${AppRoutes.createPost}?profileId=${Uri.encodeComponent(refreshed.id)}',
      arguments: PlaySession.apiOf(context),
    );
    if (uploaded == true && mounted) {
      await Future.wait([
        _fetchPosts(reset: true),
        _fetchPendingPosts(),
        _syncPostCountFromServer(),
      ]);
    }
  }

  void _handleBack() {
    if (_standaloneProfile || (ModalRoute.of(context)?.isFirst ?? false)) {
      closeFlutterPlay();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    closeFlutterPlay();
  }

  @override
  Widget build(BuildContext context) {
    final allowPop = !_standaloneProfile &&
        !(ModalRoute.of(context)?.isFirst ?? false) &&
        Navigator.canPop(context);
    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) closeFlutterPlay();
      },
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: ProfileColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A), fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1A1A1A)),
          onPressed: _handleBack,
        ),
        actions: [
          if (_profile?.isConnected == true)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC8E6C9)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.storefront_outlined, size: 14, color: Color(0xFFfb5204)),
                    SizedBox(width: 4),
                    Text(
                      'Connected',
                      style: TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: ProfileColors.divider),
        ),
      ),
      body: _loading
          ? const ProfileScreenSkeleton()
          : _needsProfileSetup
              ? _buildCreateProfileState()
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFfb5404)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollEndNotification &&
                        notification.metrics.extentAfter < 300 &&
                        _hasMore &&
                        !_loadingMore &&
                        !_loadingPosts) {
                      setState(() => _loadingMore = true);
                      _fetchPosts();
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    color: const Color(0xFFfb5404),
                    onRefresh: () => _load(refresh: true),
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        if (_profile != null)
                          SliverToBoxAdapter(child: _buildHeader(_profile!)),
                        if (_pendingPosts.isNotEmpty)
                          SliverToBoxAdapter(
                            child: ProfilePendingPostsSection(
                              posts: _pendingPosts,
                              onRetryFailed: _retryFailedPost,
                              onCancelFailed: _cancelFailedPost,
                              onCancelPreparing: _cancelPreparingPost,
                              onRetryStale: _retryStalePost,
                            ),
                          ),
                        ProfilePostsSliverGrid(
                          posts: _posts,
                          loadingMore: _loadingMore,
                          loadingInitial: _loadingPosts && _posts.isEmpty && _pendingPosts.isEmpty,
                          onPostTap: _openPost,
                          showOwnerActions: false,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: _profile != null && _error == null
          ? Padding(
              padding: const EdgeInsets.only(bottom: 8, right: 4),
              child: FloatingActionButton(
                onPressed: _openCreatePost,
                elevation: 4,
                backgroundColor: const Color(0xFFfb5204),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.add_rounded, size: 30, color: Colors.white),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildHeader(UserProfile profile) {
    return DefaultTextStyle(
      style: const TextStyle(color: ProfileColors.textPrimary),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfileAvatar(
                  imageUrl: profile.profilePicture,
                  onTap: profile.profilePicture != null && profile.profilePicture!.isNotEmpty
                      ? () => _showImage(profile.profilePicture!)
                      : null,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF000000),
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ProfileStat(
                            value: formatCount(_displayPostCount ?? profile.postCount),
                            label: 'Posts',
                            onTap: () {},
                          ),
                          ProfileStat(
                            value: formatCount(_displayFollowersCount ?? profile.followersCount),
                            label: 'Followers',
                            onTap: () => _openFollowList('followers'),
                          ),
                          ProfileStat(
                            value: formatCount(_displayFollowingCount ?? profile.followingCount),
                            label: 'Following',
                            onTap: () => _openFollowList('following'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (profile.username.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '@${profile.username}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1A1A1A)),
              ),
            ],
            const SizedBox(height: 10),
            if (profile.bio != null && profile.bio!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.bio!,
                    maxLines: _showFullBio ? null : 3,
                    overflow: _showFullBio ? null : TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF333333)),
                  ),
                  if (profile.bio!.length > 100)
                    GestureDetector(
                      onTap: () => setState(() => _showFullBio = !_showFullBio),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _showFullBio ? 'Read less' : 'Read more',
                          style: const TextStyle(color: Color(0xFFfb5204), fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                ],
              )
            else
              const Text(
                'No bio available.',
                style: TextStyle(color: Color(0xFF999999), fontStyle: FontStyle.italic, fontSize: 13),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () async {
                        await Navigator.pushNamed(context, AppRoutes.editProfile, arguments: PlaySession.apiOf(context));
                        if (mounted) _load(refresh: true);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1A1A1A),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ),
                ),
                // const SizedBox(width: 10),
                // Material(
                //   color: const Color(0xFFF3F4F6),
                //   borderRadius: BorderRadius.circular(8),
                //   child: InkWell(
                //     onTap: _shareProfile,
                //     borderRadius: BorderRadius.circular(8),
                //     child: const SizedBox(
                //       width: 46,
                //       height: 46,
                //       child: Icon(Icons.share_outlined, color: Color(0xFFfb5404)),
                //     ),
                //   ),
                // ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  void _showImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
