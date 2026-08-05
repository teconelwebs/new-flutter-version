import 'package:flutter/material.dart';

import '../models/reel.dart';
import '../services/adaptive_prefetch_engine.dart';
import '../services/reels_api.dart';
import '../services/video_preload_pool.dart';
import '../utils/flutter_nav.dart';
import '../utils/play_session.dart';
import '../utils/profile_thumbnail_cache.dart';
import '../widgets/play_profile_setup_sheet.dart';
import '../widgets/reel_item.dart';

class ReelsScreen extends StatefulWidget {
  final String initialReelId;
  final bool isActive;
  final bool openCommentsOnStart;

  const ReelsScreen({
    super.key,
    this.initialReelId = '',
    this.isActive = true,
    this.openCommentsOnStart = false,
  });

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> with RouteAware {
  final PageController _pageController = PageController();
  final ScrollPredictor _scrollPredictor = ScrollPredictor();

  AdaptivePrefetchConfig? _prefetchConfig;
  VideoPreloadPool? _preloadPool;

  List<Reel> _reels = [];
  int _currentIndex = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  bool _routeVisible = true;
  bool _routeSubscribed = false;
  int _bootstrapGen = 0;
  bool _setupOffered = false;
  String? _lastListenedReelId;

  ReelsApi get _api => PlaySession.apiOf(context);

  bool _bootstrapStarted = false;

  @override
  void initState() {
    super.initState();
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
      _bootstrapStarted = false;
      _maybeBootstrap();
    } else {
      _lastViewerId = currentViewerId;
      _maybeBootstrap();
    }
  }

  void _maybeBootstrap() {
    if (_bootstrapStarted) return;
    _bootstrapStarted = true;
    _bootstrap();
  }

  void _maybeOfferProfileSetup() {
    if (!widget.isActive) return;
    final scope = playSessionScopeOf(context);
    if (scope == null || !scope.shouldOfferProfileSetup || _setupOffered) return;
    _setupOffered = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final launchContext = PlaySession.launchContextOf(context);
      PlayProfileSetupSheet.show(
        context,
        launchContext: launchContext,
        deviceId: _api.deviceId,
        onCreated: scope.onProfileCreated,
        onDismissed: scope.dismissProfileSetup,
      );
    });
  }

  @override
  void didUpdateWidget(ReelsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (!widget.isActive) {
        _preloadPool?.pauseAll();
      } else {
        _setupOffered = false;
        final scope = playSessionScopeOf(context);
        scope?.resetSetupDismissed();
        _maybeOfferProfileSetup();

        if (_reels.isNotEmpty) {
          _preloadPool?.prefetchWindowBackground(_reels, _currentIndex);
        }
      }
    }
  }

  @override
  void dispose() {
    _bootstrapGen++;
    appRouteObserver.unsubscribe(this);
    _preloadPool?.pauseAll();
    _preloadPool?.disposeAll();
    _pageController.dispose();
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
    _applyBlockedUsers();
    setState(() {
      _routeVisible = _reels.isNotEmpty;
      if (_reels.isNotEmpty) _error = null;
    });
    if (_reels.isNotEmpty) {
      _preloadPool?.prefetchWindowBackground(_reels, _currentIndex);
      _prefetchReelAvatars(_currentIndex);
    }
  }

  void _prefetchReelAvatars(int centerIndex) {
    if (!mounted || _reels.isEmpty) return;
    final start = (centerIndex - 2).clamp(0, _reels.length);
    final end = (centerIndex + 10).clamp(0, _reels.length);
    if (start >= end) return;
    ProfileThumbnailCache.prefetchAvatars(
      context,
      urls: _reels.sublist(start, end).map((r) => r.user.avatar),
      maxUrls: 16,
    );
  }

  void _applyBlockedUsers() {
    final blocked = PlaySessionRegistry.blockedUserIds;
    if (blocked.isEmpty) return;
    _preloadPool?.pauseAll();
    _removeReelsFromUsers(blocked);
  }

  void _removeReelsFromUsers(Set<String> userIds) {
    if (userIds.isEmpty || _reels.isEmpty) return;

    final filtered = _reels.where((r) => !userIds.contains(r.user.id)).toList();
    if (filtered.length == _reels.length) return;

    var newIndex = _currentIndex;
    if (filtered.isEmpty) {
      newIndex = 0;
    } else {
      var removedBefore = 0;
      for (var i = 0; i < _currentIndex && i < _reels.length; i++) {
        if (userIds.contains(_reels[i].user.id)) removedBefore++;
      }
      newIndex = (_currentIndex - removedBefore).clamp(0, filtered.length - 1);
    }

    setState(() {
      _reels = filtered;
      _currentIndex = newIndex;
      if (filtered.isEmpty) _routeVisible = false;
    });

    _preloadPool?.trimOutside(filtered, newIndex);

    if (_pageController.hasClients && filtered.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        final target = newIndex.clamp(0, filtered.length - 1);
        if (_pageController.page?.round() != target) {
          _pageController.jumpToPage(target);
        }
      });
    }
  }

  Future<void> _bootstrap() async {
    _preloadPool?.disposeAll();
    final gen = ++_bootstrapGen;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = PlaySession.apiOf(context);
      await PlaySessionRegistry.ensureBlockedListLoaded(api);
      
      final config = await AdaptivePrefetchEngine.load();
      final loaded = await _fetchInitialReels();

      if (!mounted || gen != _bootstrapGen) return;

      _prefetchConfig = config;
      _preloadPool = VideoPreloadPool(config);

      final filteredReels = loaded.reels
          .where((r) => !PlaySessionRegistry.isUserBlocked(r.user.id))
          .toList();

      if (filteredReels.isNotEmpty) {
        _preloadPool!.prefetchWindowBackground(filteredReels, 0);
      }

      setState(() {
        _reels = filteredReels;
        _hasMore = loaded.hasMore;
        _loading = false;
      });
      _prefetchReelAvatars(0);
      _maybeOfferProfileSetup();
    } catch (e) {
      if (!mounted || gen != _bootstrapGen) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
      _maybeOfferProfileSetup();
    }
  }

  Future<({List<Reel> reels, bool hasMore})> _fetchInitialReels() async {
    final initialId = widget.initialReelId.trim();
    if (initialId.isEmpty) {
      return _api.fetchReelsPage();
    }

    Reel? initialReel;
    try {
      initialReel = await _api.fetchReelById(initialId);
    } catch (_) {}

    final exclude = initialReel?.id ?? initialId;
    var feedPage = (reels: <Reel>[], hasMore: false);
    try {
      feedPage = await _api.fetchReelsPage(exclude: exclude);
    } catch (_) {}

    if (initialReel != null) {
      final feed = feedPage.reels.where((r) => r.id != initialReel!.id).toList();
      return (reels: [initialReel, ...feed], hasMore: feedPage.hasMore);
    }
    return feedPage;
  }

  void _handleClose() {
    _bootstrapGen++;
    _preloadPool?.pauseAll();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    closeFlutterPlay();
  }

  void _removeReel(String reelId) {
    final idx = _reels.indexWhere((r) => r.id == reelId);
    if (idx < 0) return;

    _preloadPool?.release(reelId);

    final newReels = List<Reel>.from(_reels)..removeAt(idx);
    if (newReels.isEmpty) {
      setState(() => _reels = newReels);
      _handleClose();
      return;
    }

    var newIndex = _currentIndex;
    if (idx < _currentIndex) {
      newIndex = _currentIndex - 1;
    } else if (idx == _currentIndex) {
      newIndex = idx.clamp(0, newReels.length - 1);
    }

    setState(() {
      _reels = newReels;
      _currentIndex = newIndex;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(newIndex);
      final extra = _prefetchConfig == null
          ? 0
          : _scrollPredictor.extraPreload(_prefetchConfig!);
      _preloadPool?.trimOutside(_reels, newIndex, extraAhead: extra);
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _reels.isEmpty) return;

    setState(() => _loadingMore = true);
    try {
      final exclude = _reels.map((r) => r.id).join(',');
      final page = await _api.fetchReelsPage(exclude: exclude);
      if (!mounted) return;

      final seen = _reels.map((r) => r.id).toSet();
      final filteredMore = page.reels
          .where((r) => !seen.contains(r.id))
          .where((r) => !PlaySessionRegistry.isUserBlocked(r.user.id))
          .toList();

      if (filteredMore.isNotEmpty) {
        final merged = [..._reels, ...filteredMore];
        _preloadPool?.prefetchWindowBackground(
          merged,
          _currentIndex,
          extraAhead: _scrollPredictor.extraPreload(_prefetchConfig!),
        );
        setState(() {
          _reels = merged;
          _hasMore = page.hasMore;
          _loadingMore = false;
        });
        _prefetchReelAvatars(_currentIndex);
      } else {
        setState(() {
          _hasMore = page.hasMore && page.reels.isNotEmpty;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  bool _canScrollForward() {
    final nextIndex = _currentIndex + 1;
    if (nextIndex >= _reels.length) {
      return true; // No next page to block
    }
    final nextReel = _reels[nextIndex];
    final pool = _preloadPool;
    if (pool == null) return true;
    final state = pool.stateFor(nextReel.id);
    return state == PreloadState.ready;
  }

  void _onPageChanged(int index) {
    _scrollPredictor.onPageChanged(index);
    final extra = _prefetchConfig == null ? 0 : _scrollPredictor.extraPreload(_prefetchConfig!);

    setState(() => _currentIndex = index);

    final pool = _preloadPool;
    if (pool != null && _reels.isNotEmpty) {
      pool.prefetchWindowBackground(_reels, index, extraAhead: extra);
      pool.trimOutside(_reels, index, extraAhead: extra);
    }
    _prefetchReelAvatars(index);

    if (index >= _reels.length - 5) _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final allowPop = Navigator.of(context).canPop();
    return videoScreenWrapper(
      child: PopScope(
        canPop: allowPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleClose();
        },
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFfb5404)),
              SizedBox(height: 12),
              Text('Preparing play...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 40),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _bootstrap,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFfb5404)),
                  child: const Text('Retry'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _handleClose,
                  child: const Text('Close', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No play available', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _handleClose,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFfb5404)),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    }

    final pool = _preloadPool!;

    // Set up reactive listener for the next reel preloading completion
    final nextIndex = _currentIndex + 1;
    if (nextIndex < _reels.length) {
      final nextReel = _reels[nextIndex];
      if (nextReel.id != _lastListenedReelId && pool.stateFor(nextReel.id) != PreloadState.ready) {
        _lastListenedReelId = nextReel.id;
        pool.initFutureOf(nextReel.id)?.then((_) {
          if (mounted && _currentIndex + 1 < _reels.length && _reels[_currentIndex + 1].id == nextReel.id) {
            setState(() {});
          }
        });
      }
    }

    final scrollAllowed = _canScrollForward();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: DirectionalScrollPhysics(
              allowForward: scrollAllowed,
              allowBackward: true,
              parent: const PageScrollPhysics(),
            ),
            itemCount: _reels.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final reel = _reels[index];
              return ReelItemWidget(
                key: ValueKey(reel.id),
                reel: reel,
                pool: pool,
                api: _api,
                isActive: index == _currentIndex && _routeVisible && widget.isActive,
                openCommentsOnStart: widget.openCommentsOnStart &&
                    index == _currentIndex &&
                    reel.id == widget.initialReelId.trim(),
                onClose: _handleClose,
                onRefresh: _bootstrap,
                onRemoveReel: _removeReel,
              );
            },
          ),
          if (!scrollAllowed)
            Positioned(
              left: 0,
              right: 0,
              bottom: 80,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 0.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFB5404),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Preparing next video...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DirectionalScrollPhysics extends ScrollPhysics {
  final bool allowForward;
  final bool allowBackward;

  const DirectionalScrollPhysics({
    super.parent,
    this.allowForward = true,
    this.allowBackward = true,
  });

  @override
  DirectionalScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return DirectionalScrollPhysics(
      parent: buildParent(ancestor),
      allowForward: allowForward,
      allowBackward: allowBackward,
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value < position.pixels && !allowBackward) {
      return value - position.pixels;
    }
    if (value > position.pixels && !allowForward) {
      return value - position.pixels;
    }
    return super.applyBoundaryConditions(position, value);
  }
}
