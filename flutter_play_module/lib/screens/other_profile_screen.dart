import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

import '../models/profile_post.dart';
import '../models/user_profile.dart';
import '../models/profile_reels_route_args.dart';
import '../utils/app_routes.dart';
import '../utils/format_count.dart';
import '../utils/flutter_nav.dart';
import '../utils/play_profile_guard.dart';
import '../utils/play_session.dart';
import '../utils/profile_thumbnail_cache.dart';
import '../utils/my_profile_cache.dart';
import '../widgets/profile_widgets.dart';

class OtherProfileScreen extends StatefulWidget {
  final String userId;

  const OtherProfileScreen({super.key, required this.userId});

  @override
  State<OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends State<OtherProfileScreen>
    with RouteAware {
  UserProfile? _profile;
  List<ProfilePost> _posts = [];
  bool _loading = true;
  bool _loadingPosts = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _postsSkip = 0;
  bool _showFullBio = false;
  bool _isFollowing = false;
  bool _isBlocked = false;
  bool _actionLoading = false;
  String? _error;
  String? _toast;
  bool _initialized = false;
  int? _displayFollowersCount;
  int? _displayFollowingCount;
  bool _routeSubscribed = false;

  static const _textPrimary = Color(0xFF1A1A1A);
  static const _textSecondary = Color(0xFF555555);
  static const _textMuted = Color(0xFF888888);

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
    if (!_initialized) {
      _initialized = true;
      _checkProfile();
    }
  }

  @override
  void dispose() {
    if (_routeSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    super.dispose();
  }

  @override
  void didPopNext() {
    _load(refresh: true);
  }

  Future<void> _checkProfile() async {
    final hasProfile = await ensurePlayProfileForAction(context);
    if (!hasProfile && mounted) {
      Navigator.of(context).pop();
    } else if (mounted) {
      _load();
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (!refresh) setState(() => _loading = true);
    final api = PlaySession.apiOf(context);
    try {
      PlaySessionRegistry.resetBlockedListCache();
      await PlaySessionRegistry.ensureBlockedListLoaded(api);
      final profile = await api.fetchUserProfile(widget.userId);
      final blocked = PlaySessionRegistry.isProfileBlocked(
        profileId: profile.id,
        profileUserid: profile.userid,
        routeUserId: widget.userId,
      );
      final profileKey = profile.userid ?? profile.id;
      final counts = blocked
          ? (followers: 0, following: 0)
          : await api.fetchFollowCounts(profileKey);
      if (!mounted) return;

      final isFollowingResolved = blocked
          ? false
          : PlaySessionRegistry.resolveFollowState(
              userId: profile.id,
              alternateId: profile.userid,
              fallback: profile.isFollowedBy(api.viewerId),
            );

      setState(() {
        _profile = profile;
        _isFollowing = isFollowingResolved;
        _isBlocked = blocked;
        if (!blocked) {
          _displayFollowersCount = counts.followers;
          _displayFollowingCount = counts.following;
        }
        if (blocked) {
          _posts = [];
          _postsSkip = 0;
          _hasMore = false;
        }
        _loading = false;
        _error = null;
      });
      if (!_isBlocked) await _fetchPosts(reset: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _fetchPosts({bool reset = false}) async {
    final profile = _profile;
    if (profile == null || _isBlocked || _loadingPosts) return;
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
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingPosts = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    final profile = _profile;
    if (profile == null || _actionLoading || _isBlocked) return;
    final api = PlaySession.apiOf(context);
    final next = !_isFollowing;
    MyProfileCache.clear();
    setState(() {
      _isFollowing = next;
      _actionLoading = true;
      if (_displayFollowersCount != null) {
        _displayFollowersCount = _displayFollowersCount! + (next ? 1 : -1);
        if (_displayFollowersCount! < 0) _displayFollowersCount = 0;
      }
    });
    try {
      await api.toggleFollow(profile.id, follow: next);
      PlaySessionRegistry.setFollowState(
        following: next,
        id: profile.id,
        userid: profile.userid,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isFollowing = !next;
          if (_displayFollowersCount != null) {
            _displayFollowersCount = _displayFollowersCount! + (!next ? 1 : -1);
            if (_displayFollowersCount! < 0) _displayFollowersCount = 0;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _runBlockAction(String action) async {
    final profile = _profile;
    if (profile == null || _actionLoading) return;
    final scope = PlaySessionRegistry.scope;
    await scope?.refreshViewerFromSession();
    if (!mounted) return;
    final api = PlaySession.apiOf(context);
    setState(() => _actionLoading = true);
    try {
      final targetId = profile.id.trim().isNotEmpty
          ? profile.id
          : (profile.userid ?? widget.userId);
      final result = action == 'block'
          ? await api.blockUser(targetId)
          : await api.unblockUser(targetId);
      if (!mounted) return;
      final alreadyUnblocked = action == 'unblock' &&
          !result.ok &&
          result.message.toLowerCase().contains('not currently block');
      if (result.ok || alreadyUnblocked) {
        if (scope != null && result.message.isNotEmpty && result.ok) {
          // Keep session viewer id in sync after successful block/unblock.
          await scope.refreshViewerFromSession();
        }
        if (action == 'block') {
          PlaySessionRegistry.markProfileBlocked(
            id: profile.id,
            userid: profile.userid,
          );
          setState(() {
            _isBlocked = true;
            _isFollowing = false;
            _posts = [];
            _postsSkip = 0;
            _hasMore = false;
          });
          PlaySessionRegistry.setFollowState(
            following: false,
            id: profile.id,
            userid: profile.userid,
          );
          _showToast('User blocked');
        } else {
          PlaySessionRegistry.markProfileUnblocked(
            id: profile.id,
            userid: profile.userid,
          );
          PlaySessionRegistry.resetBlockedListCache();
          await PlaySessionRegistry.ensureBlockedListLoaded(api);
          if (!mounted) return;
          setState(() {
            _isBlocked = false;
            _posts = [];
            _postsSkip = 0;
            _hasMore = true;
          });
          _showToast(alreadyUnblocked ? 'User is already unblocked' : 'User unblocked');
          await _fetchPosts(reset: true);
        }
      } else {
        _showToast(
          result.message.isNotEmpty
              ? result.message
              : 'Action failed. Please try again.',
        );
      }
    } catch (_) {
      _showToast('Something went wrong');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }


  void _openFollowList(String type) async {
    if (_isBlocked) return;
    final profile = _profile;
    if (profile == null) return;
    final userid = profile.userid ?? profile.id;
    await Navigator.pushNamed(
      context,
      '${AppRoutes.followList}?type=$type&userid=${Uri.encodeComponent(userid)}',
      arguments: PlaySession.apiOf(context),
    );
    if (!mounted || _isBlocked) return;
    final api = PlaySession.apiOf(context);
    try {
      final counts = await api.fetchFollowCounts(userid);
      if (!mounted) return;
      setState(() {
        _displayFollowersCount = counts.followers;
        _displayFollowingCount = counts.following;
      });
    } catch (_) {}
  }

  void _openPost(ProfilePost post, int index) {
    if (_isBlocked) return;
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

  void _showToast(String msg) {
    setState(() => _toast = msg);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  bool get _standaloneProfile {
    final name = ModalRoute.of(context)?.settings.name ?? '';
    final uri = Uri.tryParse(name.startsWith('/') ? name : '/$name');
    return uri?.queryParameters['standalone'] == '1';
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

  Future<void> _showBlockSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(_isBlocked ? Icons.lock_open : Icons.block,
                  color: _isBlocked ? Colors.green : Colors.red),
              title: Text(
                _isBlocked ? 'Unblock' : 'Block',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _isBlocked ? Colors.green.shade700 : Colors.red,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _runBlockAction(_isBlocked ? 'unblock' : 'block');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = PlaySession.apiOf(context);
    final isSelf = _profile?.id == api.viewerId;
    final allowPop = !_standaloneProfile &&
        !(ModalRoute.of(context)?.isFirst ?? false) &&
        Navigator.canPop(context);

    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Profile'),
          leading: IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _handleBack,
          ),
          actions: [
            if (!isSelf && _profile != null)
              IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: _showBlockSheet),
          ],
        ),
        body: Stack(
          children: [
            _loading
                ? const ProfileScreenSkeleton()
                : _error != null
                    ? _errorView()
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollEndNotification &&
                              notification.metrics.extentAfter < 300 &&
                              _hasMore &&
                              !_loadingMore) {
                            setState(() => _loadingMore = true);
                            _fetchPosts();
                          }
                          return false;
                        },
                        child: RefreshIndicator(
                          color: const Color(0xFFfb5404),
                          onRefresh: () => _load(refresh: true),
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              if (_profile != null)
                                SliverToBoxAdapter(
                                    child: _buildHeader(_profile!, isSelf)),
                              const SliverToBoxAdapter(
                                child: Divider(
                                    height: 1, color: Color(0xFFEEEEEE)),
                              ),
                              if (_isBlocked)
                                const SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.all(32),
                                    child: Column(
                                      children: [
                                        Icon(Icons.block,
                                            size: 48, color: Color(0xFF9CA3AF)),
                                        SizedBox(height: 12),
                                        Text('You blocked this user',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                                color: _textPrimary)),
                                        SizedBox(height: 6),
                                        Text('Unblock to see their posts again',
                                            style:
                                                TextStyle(color: _textMuted)),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                ProfilePostsSliverGrid(
                                  posts: _posts,
                                  loadingMore: _loadingMore,
                                  loadingInitial:
                                      _loadingPosts && _posts.isEmpty,
                                  onPostTap: _openPost,
                                ),
                              const SliverToBoxAdapter(
                                  child: SizedBox(height: 24)),
                            ],
                          ),
                        ),
                      ),
            if (_toast != null) _toastWidget(),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          const Text('Profile Not Available',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.maybePop(context),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFfb5404)),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _toastWidget() {
    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(_toast!, style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildHeader(UserProfile profile, bool isSelf) {
    final statPosts = _isBlocked ? '0' : formatCount(profile.postCount);
    final statFollowers = _isBlocked
        ? '0'
        : formatCount(_displayFollowersCount ?? profile.followersCount);
    final statFollowing = _isBlocked
        ? '0'
        : formatCount(_displayFollowingCount ?? profile.followingCount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileAvatar(
                imageUrl: profile.profilePicture,
                onTap: profile.profilePicture != null &&
                        profile.profilePicture!.isNotEmpty
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
                        color: _textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ProfileStat(value: statPosts, label: 'Posts'),
                        ProfileStat(
                          value: statFollowers,
                          label: 'Followers',
                          onTap: () => _openFollowList('followers'),
                        ),
                        ProfileStat(
                          value: statFollowing,
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
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: _textPrimary),
            ),
          ],
          if (!isSelf) ...[
            const SizedBox(height: 14),
            if (_isBlocked)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      _actionLoading ? null : () => _runBlockAction('unblock'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    _actionLoading ? '...' : 'Unblock',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _actionLoading ? null : _toggleFollow,
                      style: FilledButton.styleFrom(
                        backgroundColor: _isFollowing
                            ? const Color(0xFFE8E8E8)
                            : const Color(0xFFfb5404),
                        foregroundColor:
                            _isFollowing ? _textPrimary : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: Text(
                        _actionLoading
                            ? '...'
                            : (_isFollowing ? 'Following' : 'Follow'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
          ],
          const SizedBox(height: 14),
          if (!_isBlocked && profile.bio != null && profile.bio!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isBioLong(profile.bio!)) ...[
                  GestureDetector(
                    onTap: () => setState(() => _showFullBio = !_showFullBio),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 14, height: 1.45, color: _textSecondary),
                        children: [
                          TextSpan(
                            text: _showFullBio
                                ? profile.bio!
                                : _getCollapsedBio(profile.bio!),
                          ),
                          TextSpan(
                            text: _showFullBio ? ' Read less' : ' more',
                            style: const TextStyle(
                              color: Color(0xFFfb5204),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    profile.bio!,
                    style: const TextStyle(fontSize: 14, height: 1.45, color: _textSecondary),
                  ),
                ],
              ],
            )
          else if (!_isBlocked)
            const Text('No bio available.',
                style:
                    TextStyle(color: _textMuted, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  bool _isBioLong(String bio) {
    if (bio.contains('\n')) return true;
    if (bio.length > 40) return true;
    return false;
  }

  String _getCollapsedBio(String bio) {
    String firstLine = bio;
    if (bio.contains('\n')) {
      firstLine = bio.split('\n').first;
    }
    if (firstLine.length > 40) {
      return '${firstLine.substring(0, 40)}...';
    }
    if (bio.contains('\n')) {
      return '$firstLine...';
    }
    return firstLine;
  }

  void _showImage(String url) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Close Profile Photo",
      // ignore: deprecated_member_use
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: () {}, // Prevent taps on image from closing
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.8,
                        height: MediaQuery.of(context).size.width * 0.8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              // ignore: deprecated_member_use
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: InteractiveViewer(
                            maxScale: 4.0,
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.person, size: 80, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 16,
                    right: 16,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
