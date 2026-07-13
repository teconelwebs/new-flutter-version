import 'dart:async';

import 'package:flash_list/flash_list.dart';
import 'package:flutter/material.dart';

import '../models/search_result.dart';
import '../services/recent_search_store.dart';
import '../utils/app_routes.dart';
import '../utils/flutter_nav.dart';
import '../utils/play_profile_guard.dart';
import '../utils/play_session.dart';
import '../utils/profile_thumbnail_cache.dart';
import '../widgets/profile_widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryController = TextEditingController();
  final _focusNode = FocusNode();

  List<SearchUserHit> _users = [];
  List<SearchVideoHit> _videos = [];
  List<SearchUserHit> _recent = [];

  bool _loadingSearch = false;
  bool _loadingVideos = true;
  bool _fetchingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int _selectedTab = 0; // 0=All, 1=Videos, 2=Accounts

  Timer? _debounce;
  String _query = '';
  bool _initialized = false;

  static const _accent = Color(0xFFfb5404);
  static const _tabs = ['All', 'Videos', 'Accounts'];
  static const _gridCrossAxisCount = 3;
  static const _gridSpacing = 3.0;
  static const _gridAspectRatio = 2 / 3;
  static const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: _gridCrossAxisCount,
    crossAxisSpacing: _gridSpacing,
    mainAxisSpacing: _gridSpacing,
    childAspectRatio: _gridAspectRatio,
  );

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    final hasProfile = await ensurePlayProfileForAction(context);
    if (!hasProfile && mounted) {
      Navigator.of(context).pop();
    } else if (mounted) {
      _bootstrap();
    }
  }

  @override
  void activate() {
    super.activate();
    if (_initialized) _purgeBlockedContent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  double _videoTileWidth(BuildContext context) {
    const horizontalPadding = 24.0;
    final inner = MediaQuery.sizeOf(context).width - horizontalPadding;
    return (inner - _gridSpacing * (_gridCrossAxisCount - 1)) / _gridCrossAxisCount;
  }

  double _videoTileHeight(BuildContext context) => _videoTileWidth(context) / _gridAspectRatio;

  int get _videoRowCount => (_videos.length + _gridCrossAxisCount - 1) ~/ _gridCrossAxisCount;

  void _prefetchVideoThumbnails(Iterable<SearchVideoHit> videos) {
    if (!mounted) return;
    ProfileThumbnailCache.prefetchForGrid(
      context,
      urls: videos.map((v) => v.thumbnailUrl),
      tileWidth: _videoTileWidth(context),
      maxUrls: 24,
    );
  }

  Future<void> _bootstrap() async {
    final api = PlaySession.apiOf(context);
    await PlaySessionRegistry.ensureBlockedListLoaded(api);
    final recent = await RecentSearchStore.load();
    if (mounted) {
      setState(() => _recent = _filterBlockedUsers(recent));
    }
    await _loadContent(page: 1, reset: true, query: '');
  }

  List<SearchUserHit> _filterBlockedUsers(List<SearchUserHit> users) {
    return users.where((u) => !PlaySessionRegistry.isSearchUserBlocked(u)).toList();
  }

  List<SearchVideoHit> _filterBlockedVideos(List<SearchVideoHit> videos) {
    return videos.where((v) => !PlaySessionRegistry.isSearchVideoBlocked(v)).toList();
  }

  void _purgeBlockedContent() {
    setState(() {
      _users = _filterBlockedUsers(_users);
      _videos = _filterBlockedVideos(_videos);
      _recent = _filterBlockedUsers(_recent);
    });
  }

  void _onQueryChanged() {
    final next = _queryController.text;
    if (next == _query) return;
    setState(() {
      _query = next;
      if (next.isEmpty) _selectedTab = 0;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _loadContent(page: 1, reset: true, query: next.trim());
    });
  }

  Future<void> _loadContent({
    required int page,
    required bool reset,
    required String query,
  }) async {
    final isSearchMode = query.isNotEmpty;
    final api = PlaySession.apiOf(context);

    if (page == 1) {
      setState(() {
        _loadingSearch = isSearchMode;
        if (!isSearchMode) _loadingVideos = true;
        if (reset) {
          _page = 1;
          _hasMore = true;
        }
      });
    } else {
      setState(() => _fetchingMore = true);
    }

    try {
      final result = await api.searchPopular(
        query: query,
        videoPage: page,
        videoLimit: 20,
      );

      if (!mounted) return;

      setState(() {
        _users = isSearchMode ? _filterBlockedUsers(result.users) : [];
        if (reset) {
          _videos = _filterBlockedVideos(result.videos);
        } else {
          _videos = _filterBlockedVideos([..._videos, ...result.videos]);
        }
        _hasMore = result.hasMoreVideos;
        _page = page;
        _loadingSearch = false;
        _loadingVideos = false;
        _fetchingMore = false;
      });
      _prefetchVideoThumbnails(result.videos);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSearch = false;
        _loadingVideos = false;
        _fetchingMore = false;
      });
    }
  }

  void _handleBack() {
    if (_query.isNotEmpty) {
      _focusNode.unfocus();
      _queryController.clear();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      closeFlutterPlay();
    }
  }

  Future<void> _selectUser(SearchUserHit user) async {
    _focusNode.unfocus();
    await RecentSearchStore.addUser(user);
    final recent = await RecentSearchStore.load();
    if (mounted) setState(() => _recent = _filterBlockedUsers(recent));
    if (!mounted) return;
    await AppRoutes.openProfile(context, user.targetUserId);
    if (!mounted) return;
    _purgeBlockedContent();
  }

  Future<void> _deleteRecent(String username) async {
    await RecentSearchStore.removeUsername(username);
    final recent = await RecentSearchStore.load();
    if (mounted) setState(() => _recent = recent);
  }

  void _openVideo(int index) {
    _focusNode.unfocus();
    if (index < 0 || index >= _videos.length) return;
    final reelId = _videos[index].id;
    if (reelId.isEmpty) return;
    Navigator.pushNamed(
      context,
      '${AppRoutes.reels}?initialReelId=${Uri.encodeComponent(reelId)}',
      arguments: PlaySession.apiOf(context),
    );
  }

  void _fetchMore() {
    if (_fetchingMore || !_hasMore || _query.trim().isNotEmpty) return;
    _loadContent(page: _page + 1, reset: false, query: '');
  }

  Future<void> _handleLoadMore() async {
    _fetchMore();
  }

  bool get _isSearchMode => _query.trim().isNotEmpty;

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: profileScreenWrapper(
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: SafeArea(
            child: Column(
              children: [
                _buildSearchBar(),
                if (_isSearchMode) _buildTabBar(),
                Expanded(
                  child: _isSearchMode
                      ? _buildSearchResults()
                      : _buildDefaultContent(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Search bar ───────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF333333)),
            padding: const EdgeInsets.all(8),
          ),
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: TextField(
                controller: _queryController,
                focusNode: _focusNode,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
                decoration: InputDecoration(
                  hintText: 'Search videos, accounts...',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                          onTap: () => _queryController.clear(),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.cancel, color: Color(0xFF9CA3AF), size: 18),
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  isDense: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab bar (visible only in search mode) ────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final selected = _selectedTab == i;
                return Padding(
                  padding: EdgeInsets.only(right: i < _tabs.length - 1 ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? _accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? _accent : const Color(0xFFD1D5DB),
                        ),
                      ),
                      child: Text(
                        _tabs[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Search results ───────────────────────────────────────────────────────

  Widget _buildSearchResults() {
    if (_loadingSearch) return const SearchResultsSkeleton();
    if (_users.isEmpty && _videos.isEmpty) return _buildEmptyState();

    switch (_selectedTab) {
      case 1:
        return _buildVideosTab();
      case 2:
        return _buildAccountsTab();
      default:
        return _buildAllTab();
    }
  }

  Widget _buildAllTab() {
    final topUsers = _users.take(5).toList();
    return CustomScrollView(
      slivers: [
        if (topUsers.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _sectionHeader(
              'Accounts',
              icon: Icons.person_outline,
              count: _users.length,
              onSeeAll: _users.length > 5 ? () => setState(() => _selectedTab = 2) : null,
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF0F0F0)),
              ),
              child: Column(
                children: topUsers.asMap().entries.map((e) {
                  final isLast = e.key == topUsers.length - 1;
                  return Column(
                    children: [
                      _buildUserRow(e.value),
                      if (!isLast) const Divider(height: 1, indent: 64, endIndent: 16),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],
        if (_videos.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _sectionHeader(
              'Videos',
              icon: Icons.play_circle_outline,
              count: _videos.length,
              onSeeAll: () => setState(() => _selectedTab = 1),
            ),
          ),
          _buildVideoSliverGrid(),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
        if (topUsers.isEmpty && _videos.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState()),
      ],
    );
  }

  Widget _buildVideosTab() {
    if (_videos.isEmpty) {
      return _emptySection('No videos found for "$_query"', Icons.videocam_off_outlined);
    }
    return FlashList<int>(
      data: List.generate(_videoRowCount, (i) => i),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemHeight: _videoTileHeight(context) + _gridSpacing,
      itemBuilder: (context, rowIndex, _) => _buildVideoRow(rowIndex),
    );
  }

  Widget _buildAccountsTab() {
    if (_users.isEmpty) {
      return _emptySection('No accounts found for "$_query"', Icons.person_off_outlined);
    }
    return FlashList<SearchUserHit>(
      data: _users,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemHeight: 76,
      itemBuilder: (context, user, index) {
        final isLast = index == _users.length - 1;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: index == 0 ? const Radius.circular(14) : Radius.zero,
              bottom: isLast ? const Radius.circular(14) : Radius.zero,
            ),
            border: const Border(
              left: BorderSide(color: Color(0xFFF0F0F0)),
              right: BorderSide(color: Color(0xFFF0F0F0)),
              top: BorderSide(color: Color(0xFFF0F0F0)),
              bottom: BorderSide(color: Color(0xFFF0F0F0)),
            ),
          ),
          child: Column(
            children: [
              _buildUserRow(user),
              if (!isLast) const Divider(height: 1, indent: 64, endIndent: 16),
            ],
          ),
        );
      },
    );
  }

  // ─── Default content (no query) ───────────────────────────────────────────

  Widget _buildDefaultContent() {
    return FlashList<int>(
      data: List.generate(_videoRowCount, (i) => i),
      isLoading: _loadingVideos,
      hasMore: _hasMore,
      onLoadMore: _handleLoadMore,
      loadMoreThreshold: 420,
      padding: EdgeInsets.zero,
      header: _buildDefaultHeader(),
      centerLoadingView: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SearchVideoGridSkeleton(
          itemCount: 9,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
        ),
      ),
      bottomLoadingIndicator: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SearchVideoGridSkeleton(
          itemCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
        ),
      ),
      itemHeight: _videoTileHeight(context) + _gridSpacing,
      itemBuilder: (context, rowIndex, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: _buildVideoRow(rowIndex),
      ),
    );
  }

  Widget _buildDefaultHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_recent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Recent Searches',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    await RecentSearchStore.clear();
                    if (mounted) setState(() => _recent = []);
                  },
                  child: const Text('Clear all', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF0F0F0)),
            ),
            child: Column(
              children: _recent.asMap().entries.map((e) {
                final isLast = e.key == _recent.length - 1;
                final user = e.value;
                return Column(
                  children: [
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFE5E7EB),
                        backgroundImage: user.profilePicture != null && user.profilePicture!.isNotEmpty
                            ? NetworkImage(user.profilePicture!)
                            : null,
                        child: user.profilePicture == null || user.profilePicture!.isEmpty
                            ? const Icon(Icons.person, color: Color(0xFF9CA3AF), size: 20)
                            : null,
                      ),
                      title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF9CA3AF), size: 18),
                        onPressed: () => _deleteRecent(user.username),
                      ),
                      onTap: () => _selectUser(user),
                    ),
                    if (!isLast) const Divider(height: 1, indent: 64, endIndent: 16),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Row(
            children: [
              Icon(Icons.local_fire_department, color: _accent, size: 20),
              SizedBox(width: 6),
              Text('Popular Videos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoRow(int rowIndex) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_gridCrossAxisCount, (col) {
        final index = rowIndex * _gridCrossAxisCount + col;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: col == 0 ? 0 : _gridSpacing / 2,
              right: col == _gridCrossAxisCount - 1 ? 0 : _gridSpacing / 2,
              bottom: _gridSpacing,
            ),
            child: AspectRatio(
              aspectRatio: _gridAspectRatio,
              child: index < _videos.length
                  ? _buildVideoTile(index)
                  : const SizedBox.shrink(),
            ),
          ),
        );
      }),
    );
  }

  // ─── Shared widgets ───────────────────────────────────────────────────────

  Widget _sectionHeader(String title, {IconData? icon, int? count, VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: _accent),
            const SizedBox(width: 6),
          ],
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          if (count != null && count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
              child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
            ),
          ],
          const Spacer(),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Text('See all', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _accent)),
            ),
        ],
      ),
    );
  }

  Widget _buildUserRow(SearchUserHit user) {
    return InkWell(
      onTap: () => _selectUser(user),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFE5E7EB),
              backgroundImage: user.profilePicture != null && user.profilePicture!.isNotEmpty
                  ? NetworkImage(user.profilePicture!)
                  : null,
              child: user.profilePicture == null || user.profilePicture!.isEmpty
                  ? const Icon(Icons.person, color: Color(0xFF9CA3AF), size: 22)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.username, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                  if (user.followersCount > 0)
                    Text('${user.followersCount} followers', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  if (user.bio != null && user.bio!.isNotEmpty)
                    Text(user.bio!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 13, color: Color(0xFFD1D5DB)),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSliverGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: _gridDelegate,
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildVideoTile(index),
          childCount: _videos.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
        ),
      ),
    );
  }

  Widget _buildVideoTile(int index) {
    if (index < 0 || index >= _videos.length) {
      return const ProfileSkeletonBox(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      );
    }
    final video = _videos[index];
    final tileW = _videoTileWidth(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return GestureDetector(
      onTap: () => _openVideo(index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: ColoredBox(
          color: const Color(0xFFE5E5E5),
          child: video.thumbnailUrl != null && video.thumbnailUrl!.isNotEmpty
              ? Image(
                  image: ProfileThumbnailCache.thumbnailProvider(
                    video.thumbnailUrl!,
                    tileW,
                    dpr,
                  ),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const Icon(Icons.videocam, color: Colors.white54),
                )
              : const Icon(Icons.videocam, color: Colors.white54),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No results for "$_query"', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          const Text('Try a different search term', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _emptySection(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
        ],
      ),
    );
  }
}
