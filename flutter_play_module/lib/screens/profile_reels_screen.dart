import 'package:flutter/material.dart';

import '../models/reel.dart';
import '../services/adaptive_prefetch_engine.dart';
import '../services/reels_api.dart';
import '../services/video_preload_pool.dart';
import '../utils/flutter_nav.dart';
import '../utils/play_session.dart';
import '../widgets/reel_item.dart';

class ProfileReelsScreen extends StatefulWidget {
  final String profileMongoId;
  final String initialReelId;
  final int? gridIndexHint;
  final List<String> seedReelIds;

  const ProfileReelsScreen({
    super.key,
    required this.profileMongoId,
    required this.initialReelId,
    this.gridIndexHint,
    this.seedReelIds = const [],
  });

  @override
  State<ProfileReelsScreen> createState() => _ProfileReelsScreenState();
}

class _ProfileReelsScreenState extends State<ProfileReelsScreen> with RouteAware {
  static const _pageSize = 50;

  PageController? _pageController;
  VideoPreloadPool? _preloadPool;
  List<Reel> _reels = [];
  int _currentIndex = 0;
  int _apiSkip = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _loading = true;
  String? _error;
  bool _initialized = false;
  bool _routeVisible = true;
  bool _routeSubscribed = false;
  bool _pageReady = false;
  String? _paginationExcludeId;

  int get _gridIndexHint {
    final fromGrid = widget.gridIndexHint;
    if (fromGrid != null && fromGrid >= 0) return fromGrid;
    final targetId = widget.initialReelId.trim();
    if (targetId.isEmpty) return 0;
    final seedIdx = widget.seedReelIds.indexOf(targetId);
    return seedIdx >= 0 ? seedIdx : 0;
  }

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
      _bootstrap();
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _preloadPool?.disposeAll();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    setState(() => _routeVisible = false);
    _preloadPool?.pauseAll();
  }

  @override
  void didPopNext() {
    if (!mounted) return;
    setState(() => _routeVisible = true);
    _preloadPool?.prefetchWindowBackground(_reels, _currentIndex);
  }

  List<Reel> _insertAnchorAtIndex(Reel anchor, List<Reel> others, int index) {
    final without = others.where((r) => r.id != anchor.id).toList();
    final at = index.clamp(0, without.length);
    return [...without.sublist(0, at), anchor, ...without.sublist(at)];
  }

  List<Reel> _alignWithSeedOrder(List<Reel> reels, List<String> seedIds) {
    if (seedIds.isEmpty) return reels;
    final byId = {for (final r in reels) r.id: r};
    final ordered = <Reel>[];
    final seen = <String>{};
    for (final id in seedIds) {
      final reel = byId[id];
      if (reel != null && seen.add(reel.id)) ordered.add(reel);
    }
    for (final reel in reels) {
      if (seen.add(reel.id)) ordered.add(reel);
    }
    return ordered;
  }

  void _finalizePaginationCursor(int rawApiSkip, {required bool excludedAnchor}) {
    final hadExclude = excludedAnchor && widget.initialReelId.trim().isNotEmpty;
    // excludeId removes the anchor from API pages; advance one slot in the full timeline.
    _apiSkip = hadExclude ? rawApiSkip + 1 : rawApiSkip;
    _paginationExcludeId = null;
  }

  int _resolveStartIndex(List<Reel> reels, String targetId) {
    if (reels.isEmpty) return 0;
    if (targetId.isNotEmpty) {
      final byId = reels.indexWhere((r) => r.id == targetId);
      if (byId >= 0) return byId;
    }
    final hint = _gridIndexHint;
    if (hint >= 0 && hint < reels.length) return hint;
    return 0;
  }

  Future<({List<Reel> reels, int startIndex, bool hasMore, int apiSkip})> _loadInitialReels(
    ReelsApi api,
  ) async {
    final targetId = widget.initialReelId.trim();
    final gridHint = _gridIndexHint;
    _paginationExcludeId = targetId.isEmpty ? null : targetId;

    final ordered = <Reel>[];
    final seen = <String>{};
    var apiSkip = 0;
    var hasMore = true;

    Reel? anchor;
    if (targetId.isNotEmpty) {
      try {
        anchor = await api.fetchReelById(targetId);
      } catch (_) {}
    }

    final initialLimit = gridHint + 25;
    final usedExclude = targetId.isNotEmpty;

    if (anchor != null && _paginationExcludeId != null) {
      final page = await api.fetchUserReelsPage(
        widget.profileMongoId,
        skip: 0,
        limit: initialLimit < _pageSize ? _pageSize : initialLimit,
        excludeId: _paginationExcludeId,
      );
      apiSkip = page.rawCount;
      hasMore = page.hasMore;
      for (final reel in page.reels) {
        if (seen.add(reel.id)) ordered.add(reel);
      }
      var reels = _insertAnchorAtIndex(anchor, ordered, gridHint);
      reels = _alignWithSeedOrder(reels, widget.seedReelIds);
      _finalizePaginationCursor(apiSkip, excludedAnchor: usedExclude);
      return (
        reels: reels,
        startIndex: _resolveStartIndex(reels, targetId),
        hasMore: hasMore,
        apiSkip: _apiSkip,
      );
    }

    while (hasMore) {
      final page = await api.fetchUserReelsPage(
        widget.profileMongoId,
        skip: apiSkip,
        limit: _pageSize,
        excludeId: _paginationExcludeId,
      );
      if (page.rawCount == 0) {
        hasMore = false;
        break;
      }

      for (final reel in page.reels) {
        if (seen.add(reel.id)) ordered.add(reel);
      }
      apiSkip += page.rawCount;
      hasMore = page.hasMore;

      if (targetId.isEmpty) {
        if (ordered.length >= _pageSize || !hasMore) break;
        continue;
      }

      final idx = ordered.indexWhere((r) => r.id == targetId);
      if (idx < 0) continue;

      final needMoreForGrid = ordered.length <= gridHint + 10;
      final nearEnd = idx >= ordered.length - 6;
      if ((needMoreForGrid || nearEnd) && hasMore) continue;
      break;
    }

    var reels = List<Reel>.from(ordered);
    var startIndex = _resolveStartIndex(reels, targetId);

    if (targetId.isNotEmpty && startIndex == 0 && reels.indexWhere((r) => r.id == targetId) < 0) {
      if (anchor != null) {
        reels = _insertAnchorAtIndex(anchor, reels, gridHint);
        startIndex = _resolveStartIndex(reels, targetId);
      } else {
        try {
          final single = await api.fetchReelById(targetId);
          if (single != null) {
            reels = _insertAnchorAtIndex(single, reels, gridHint);
            startIndex = _resolveStartIndex(reels, targetId);
          }
        } catch (_) {}
      }
    }

    reels = _alignWithSeedOrder(reels, widget.seedReelIds);
    startIndex = _resolveStartIndex(reels, targetId);
    _finalizePaginationCursor(apiSkip, excludedAnchor: usedExclude);

    return (
      reels: reels,
      startIndex: startIndex,
      hasMore: hasMore,
      apiSkip: _apiSkip,
    );
  }

  Future<void> _bootstrap() async {
    final api = PlaySession.apiOf(context);
    try {
      final config = await AdaptivePrefetchEngine.load();
      _preloadPool = VideoPreloadPool(config);

      final loaded = await _loadInitialReels(api);
      final reels = loaded.reels;
      final startIndex = loaded.startIndex.clamp(0, reels.isEmpty ? 0 : reels.length - 1);

      if (reels.isNotEmpty) {
        await _preloadPool!.prefetchWindow(reels, startIndex, waitForFirst: true);
      }
      if (!mounted) return;

      _pageController?.dispose();
      _pageController = PageController(initialPage: startIndex);
      _pageReady = false;

      setState(() {
        _reels = reels;
        _currentIndex = startIndex;
        _apiSkip = loaded.apiSkip;
        _hasMore = loaded.hasMore;
        _loading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _pageReady = true);
        if (_hasMore && startIndex >= reels.length - 5) {
          _loadMore();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _reels.isEmpty) return;
    setState(() => _loadingMore = true);
    final api = PlaySession.apiOf(context);
    final seen = _reels.map((r) => r.id).toSet();
    try {
      final page = await api.fetchUserReelsPage(
        widget.profileMongoId,
        skip: _apiSkip,
        limit: _pageSize,
        excludeId: _paginationExcludeId,
      );
      if (!mounted) return;

      _apiSkip += page.rawCount;

      if (page.rawCount == 0) {
        setState(() {
          _hasMore = false;
          _loadingMore = false;
        });
        return;
      }

      final more = page.reels.where((r) => !seen.contains(r.id)).toList();

      if (more.isNotEmpty) {
        final merged = [..._reels, ...more];
        _preloadPool?.prefetchWindowBackground(merged, _currentIndex);
        setState(() {
          _reels = merged;
          _hasMore = page.hasMore;
          _loadingMore = false;
        });
      } else if (page.hasMore) {
        setState(() {
          _hasMore = true;
          _loadingMore = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadMore();
        });
      } else {
        setState(() {
          _hasMore = false;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onPageChanged(int index) {
    if (!_pageReady) return;
    if (index < 0 || index >= _reels.length) return;
    if (index == _currentIndex) return;

    _preloadPool?.pauseAll();
    setState(() => _currentIndex = index);

    final pool = _preloadPool;
    if (pool != null && _reels.isNotEmpty) {
      pool.prefetchWindowBackground(_reels, index);
      pool.trimOutside(_reels, index);
    }
    if (_hasMore && !_loadingMore && index >= _reels.length - 5) {
      _loadMore();
    }
  }

  void _onReelDeleted(String reelId) {
    final idx = _reels.indexWhere((r) => r.id == reelId);
    if (idx < 0) return;

    _preloadPool?.release(reelId);

    final newReels = List<Reel>.from(_reels)..removeAt(idx);
    if (newReels.isEmpty) {
      Navigator.maybePop(context);
      return;
    }

    var newIndex = _currentIndex;
    if (idx < _currentIndex) {
      newIndex = _currentIndex - 1;
    } else if (idx == _currentIndex) {
      newIndex = idx.clamp(0, newReels.length - 1);
    }

    _preloadPool?.pauseAll();
    setState(() {
      _reels = newReels;
      _currentIndex = newIndex;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = _pageController;
      if (controller != null && controller.hasClients) {
        controller.jumpToPage(newIndex);
      }
      _preloadPool?.trimOutside(_reels, newIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    final api = PlaySession.apiOf(context);
    return videoScreenWrapper(
      child: _buildContent(context, api),
    );
  }

  Widget _buildContent(BuildContext context, ReelsApi api) {
    if (_loading || _pageController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFFfb5404))),
      );
    }
    if (_error != null || _reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'No play found', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.maybePop(context),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFfb5204)),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    final pool = _preloadPool!;
    final controller = _pageController!;
    final activeIndex = _currentIndex;
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: controller,
        scrollDirection: Axis.vertical,
        allowImplicitScrolling: true,
        itemCount: _reels.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final reel = _reels[index];
          return ReelItemWidget(
            key: ValueKey('${reel.id}_$index'),
            reel: reel,
            pool: pool,
            api: api,
            isActive: index == activeIndex && _routeVisible,
            onClose: () => Navigator.maybePop(context),
            onRemoveReel: _onReelDeleted,
          );
        },
      ),
    );
  }
}
