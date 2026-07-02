import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../models/comment.dart';
import '../models/live_product.dart';
import '../models/reel.dart';
import '../services/reels_api.dart';
import '../services/video_preload_pool.dart';
import '../utils/app_routes.dart';
import '../utils/flutter_nav.dart';
import '../utils/play_profile_guard.dart';
import '../utils/play_session.dart';
import '../utils/profile_thumbnail_cache.dart';
import 'caption_sheet.dart';
import 'comments_sheet.dart';
import 'product_strip.dart';
import 'reel_layout.dart';
import 'reel_progress_bar.dart';

class ReelItemWidget extends StatefulWidget {
  final Reel reel;
  final VideoPreloadPool pool;
  final ReelsApi api;
  final bool isActive;
  final VoidCallback onClose;
  final void Function(String reelId)? onRemoveReel;

  const ReelItemWidget({
    super.key,
    required this.reel,
    required this.pool,
    required this.api,
    required this.isActive,
    required this.onClose,
    this.onRemoveReel,
  });

  @override
  State<ReelItemWidget> createState() => _ReelItemWidgetState();
}

class _ReelItemWidgetState extends State<ReelItemWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _playbackStarted = false;
  bool _paused = false;
  bool _liked = false;
  bool _following = false;
  int _likeCount = 0;
  int _commentCount = 0;
  bool _interestLoading = false;
  bool _shareInProgress = false;
  bool _deleteInProgress = false;
  String? _toast;

  List<LiveProduct> _liveProducts = [];
  bool _loadingProducts = false;
  String? _productsError;
  bool _productStripOpen = false;
  bool _productsFetched = false;

  String _currentPlaybackUrl = '';
  int _videoErrorCount = 0;
  bool _recoveringVideo = false;
  double _progress = 0;
  bool _draggingProgress = false;

  @override
  void initState() {
    super.initState();
    _syncLikeFromRegistry();
    _following = PlaySessionRegistry.resolveFollowState(
      userId: widget.reel.user.id,
      fallback: widget.reel.isFollowing,
    );
    _commentCount = widget.reel.commentCount;
    _productStripOpen = widget.reel.products.isNotEmpty;
    _currentPlaybackUrl = widget.reel.playbackUrl;
    _attachPlayer();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoTick);
    super.dispose();
  }

  @override
  void didUpdateWidget(ReelItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        widget.pool.pauseExcept(widget.reel.id);
        _syncFollowFromRegistry();
        _syncLikeFromRegistry();
        // User may have tapped pause before scrolling away — resume on return.
        final wasPaused = _paused;
        _paused = false;
        if (wasPaused && mounted) setState(() {});
        _resumeAfterRouteReturn(restartFromStart: false);
        if (!_productsFetched) _fetchProducts();
        widget.api.trackView(widget.reel.id);
      } else {
        _paused = false;
        _deactivatePlayback();
        widget.pool.stop(widget.reel.id);
        if (mounted) setState(() => _progress = 0);
      }
    }
  }

  void _syncFollowFromRegistry() {
    final next = PlaySessionRegistry.resolveFollowState(
      userId: widget.reel.user.id,
      fallback: _following,
    );
    if (next != _following && mounted) {
      setState(() => _following = next);
    }
  }

  void _syncLikeFromRegistry() {
    final viewerId = widget.api.viewerId;
    final liked = PlaySessionRegistry.resolveLikeState(
      reelId: widget.reel.id,
      fallback: widget.reel.isLikedBy(viewerId),
    );
    final count = PlaySessionRegistry.resolveLikeCount(
      reelId: widget.reel.id,
      fallback: widget.reel.likeCount,
    );
    if ((liked != _liked || count != _likeCount) && mounted) {
      setState(() {
        _liked = liked;
        _likeCount = count;
      });
    } else {
      _liked = liked;
      _likeCount = count;
    }
  }

  void _persistLikeState() {
    PlaySessionRegistry.setLikeState(
      reelId: widget.reel.id,
      liked: _liked,
      likeCount: _likeCount,
    );
  }

  Future<void> _resumeAfterRouteReturn({bool restartFromStart = true}) async {
    final c = _controller;
    final hasError = c != null && c.value.hasError;
    if (hasError || !_initialized) {
      _videoErrorCount = 0;
      final fallback = widget.reel.mp4FallbackUrl;
      if (fallback != null &&
          fallback.isNotEmpty &&
          fallback != _currentPlaybackUrl) {
        await _attachPlayer(urlOverride: fallback);
      } else {
        await _ensureActivePlayback();
      }
      return;
    }
    await _activatePlayback(restartFromStart: restartFromStart);
  }

  Future<void> _activatePlayback({bool restartFromStart = true}) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.hasError) return;
    try {
      await widget.pool.ensureAudible(widget.reel.id);
      if (restartFromStart) {
        await c.seekTo(Duration.zero);
        if (mounted) {
          setState(() {
            _progress = 0;
            _playbackStarted = false;
          });
        }
      }
      if (widget.isActive && !_paused) {
        await c.play();
      }
    } catch (_) {}
  }

  void _deactivatePlayback() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      c.pause();
    } catch (_) {}
  }

  void _onVideoTick() {
    final c = _controller;
    if (c == null || !mounted) return;

    if (c.value.isInitialized && !c.value.hasError) {
      if (!_initialized) {
        if (widget.isActive && !_paused) {
          unawaited(() async {
            await widget.pool.ensureAudible(widget.reel.id);
            if (!mounted || !widget.isActive || _paused) return;
            await c.seekTo(Duration.zero);
            if (mounted && widget.isActive && !_paused) await c.play();
          }());
        }
        setState(() {
          _initialized = true;
          _progress = 0;
        });
      }
      if (c.value.isPlaying && !_playbackStarted) {
        setState(() => _playbackStarted = true);
      }
      _syncProgress(c);
    }

    if (c.value.hasError) {
      _handleVideoError();
    }
  }

  void _syncProgress(VideoPlayerController c) {
    if (!widget.isActive || _draggingProgress || !c.value.isInitialized) return;
    final durMs = c.value.duration.inMilliseconds;
    if (durMs <= 0) return;
    final next = (c.value.position.inMilliseconds / durMs).clamp(0.0, 1.0);
    if ((next - _progress).abs() >= 0.003) {
      setState(() => _progress = next);
    }
  }

  Future<void> _seekToProgress(double value) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur.inMilliseconds <= 0) return;
    final target = Duration(milliseconds: (value * dur.inMilliseconds).round());
    await c.seekTo(target);
    if (mounted) setState(() => _progress = value.clamp(0.0, 1.0));
  }

  void _onProgressSeekStart(double value) {
    setState(() {
      _draggingProgress = true;
      _progress = value.clamp(0.0, 1.0);
    });
  }

  void _onProgressSeekUpdate(double value) {
    if (!_draggingProgress) return;
    setState(() => _progress = value.clamp(0.0, 1.0));
  }

  Future<void> _onProgressSeekEnd() async {
    if (!_draggingProgress) return;
    final value = _progress;
    setState(() => _draggingProgress = false);
    await _seekToProgress(value);
    if (widget.isActive && !_paused) _controller?.play();
  }

  Future<void> _ensureActivePlayback() async {
    final c = _controller;
    if (c != null && _initialized && !c.value.hasError) {
      _onActiveChanged();
      return;
    }
    await _attachPlayer();
  }

  Future<void> _attachPlayer({String? urlOverride}) async {
    final url = urlOverride ?? _currentPlaybackUrl;
    if (url.isEmpty) return;

    _currentPlaybackUrl = url;
    final controller = await widget.pool.obtain(widget.reel.id, url);
    if (!mounted) return;

    _controller?.removeListener(_onVideoTick);
    _controller = controller;

    if (controller == null) {
      setState(() => _initialized = false);
      return;
    }

    controller.addListener(_onVideoTick);

    if (controller.value.isInitialized && !controller.value.hasError) {
      if (widget.isActive && !_paused) {
        await widget.pool.ensureAudible(widget.reel.id);
        await controller.seekTo(Duration.zero);
        await controller.play();
      }
      if (mounted) {
        setState(() {
          _initialized = true;
          _playbackStarted = controller.value.isPlaying;
          _progress = 0;
        });
      }
    } else {
      setState(() => _initialized = false);
    }
  }

  Future<void> _handleVideoError() async {
    if (_recoveringVideo || !mounted) return;
    if (_videoErrorCount >= 3) return;

    _recoveringVideo = true;
    _videoErrorCount++;

    final fallback = widget.reel.mp4FallbackUrl;
    final retryUrl = (fallback != null && fallback != _currentPlaybackUrl)
        ? fallback
        : _currentPlaybackUrl;

    _controller?.removeListener(_onVideoTick);
    widget.pool.release(widget.reel.id);
    _controller = null;
    _initialized = false;
    _playbackStarted = false;
    _progress = 0;

    await Future<void>.delayed(Duration(milliseconds: fallback != null ? 300 : 800));
    if (!mounted) {
      _recoveringVideo = false;
      return;
    }

    await _attachPlayer(urlOverride: retryUrl);
    _recoveringVideo = false;
  }

  void _onActiveChanged() {
    if (widget.isActive) {
      unawaited(_activatePlayback());
    } else {
      _deactivatePlayback();
    }
  }

  Future<void> _stopPlaybackBeforeRemoval() async {
    _controller?.removeListener(_onVideoTick);
    final c = _controller;
    if (c != null) {
      try {
        if (c.value.isInitialized) {
          await c.pause();
          await c.setVolume(0);
        }
      } catch (_) {}
    }
    widget.pool.release(widget.reel.id);
    _controller = null;
    _initialized = false;
    _playbackStarted = false;
    _progress = 0;
  }

  Future<void> _fetchProducts() async {
    _productsFetched = true;
    setState(() {
      _loadingProducts = true;
      _productsError = null;
    });
    try {
      final list = await widget.api.fetchProductsForReel(widget.reel.id);
      if (!mounted) return;
      final hasProducts = list.isNotEmpty || widget.reel.products.isNotEmpty;
      setState(() {
        _liveProducts = list;
        _loadingProducts = false;
        _productStripOpen = hasProducts;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _productsError = e.toString();
          _loadingProducts = false;
        });
      }
    }
  }

  void _togglePlayPause() {
    final c = _controller;
    if (c == null || !_initialized) return;
    setState(() {
      _paused = !_paused;
      if (_paused) {
        c.pause();
      } else {
        c.play();
      }
    });
  }

  Future<void> _handleLike() async {
    if (!await ensurePlayProfileForAction(context)) return;
    final next = !_liked;
    final previousLiked = _liked;
    final previousCount = _likeCount;
    setState(() {
      _liked = next;
      _likeCount += next ? 1 : -1;
      if (_likeCount < 0) _likeCount = 0;
    });
    _persistLikeState();
    try {
      await widget.api.toggleLike(widget.reel.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liked = previousLiked;
        _likeCount = previousCount;
      });
      _persistLikeState();
    }
  }

  Future<void> _handleFollow() async {
    if (!await ensurePlayProfileForAction(context)) return;
    final next = !_following;
    setState(() => _following = next);
    try {
      await widget.api.toggleFollow(widget.reel.user.id, follow: next);
      PlaySessionRegistry.setFollowState(
        following: next,
        id: widget.reel.user.id,
      );
    } catch (_) {
      if (mounted) setState(() => _following = !next);
    }
  }

  Future<void> _openProfile() async {
    if (!await ensurePlayProfileForAction(context)) return;
    final target = widget.reel.user.id;
    if (target.isEmpty) return;
    await AppRoutes.openProfile(context, target);
    if (!mounted) return;
    _syncFollowFromRegistry();
  }

  Future<void> _handleShare() async {
    if (_shareInProgress) return;
    _shareInProgress = true;
    try {
      final msg = await widget.api.getShareMessage(widget.reel.id);
      await Share.share(msg);
    } finally {
      _shareInProgress = false;
    }
  }

  Future<void> _openComments() async {
    if (!await ensurePlayProfileForAction(context)) return;
    await CommentsSheet.show(
      context,
      api: widget.api,
      reelId: widget.reel.id,
      onChanged: () async {
        final list = await widget.api.fetchComments(widget.reel.id);
        if (mounted) setState(() => _commentCount = countCommentsRecursive(list));
      },
    );
  }

  Future<void> _showInterestSheet() async {
    if (!await ensurePlayProfileForAction(context)) return;
    final isOwnReel = widget.reel.user.id.isNotEmpty &&
        widget.reel.user.id == widget.api.viewerId;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => lightSheetWrapper(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isOwnReel) ...[
                  ListTile(
                    leading: const Icon(Icons.visibility_outlined, color: Colors.black87),
                    title: const Text('Interested', style: TextStyle(color: Colors.black87)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _markInterest('interested', 'Marked as Interested');
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.visibility_off_outlined, color: Colors.red),
                    title: const Text('Not Interested', style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _stopPlaybackBeforeRemoval();
                      widget.onRemoveReel?.call(widget.reel.id);
                      await _markInterest('not_interested', 'Marked as Not Interested');
                    },
                  ),
                ],
                if (isOwnReel) ...[
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFdc2626)),
                    title: const Text(
                      'Delete Play',
                      style: TextStyle(color: Color(0xFFdc2626), fontWeight: FontWeight.w600),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _confirmAndDeleteReel();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndDeleteReel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFfef2f2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_rounded, color: Color(0xFFdc2626), size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Delete this play?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'This action is permanent. Your video, likes, and comments will be removed and cannot be recovered.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.45),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: Colors.black, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFdc2626),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    if (_deleteInProgress) return;

    setState(() => _deleteInProgress = true);
    final result = await widget.api.deleteReel(widget.reel.id);
    if (!mounted) return;
    setState(() => _deleteInProgress = false);

    if (result.success) {
      await _stopPlaybackBeforeRemoval();
      widget.onRemoveReel?.call(widget.reel.id);
    } else {
      setState(() => _toast = result.message.isNotEmpty ? result.message : 'Could not delete. Try again.');
      Future.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => _toast = null);
      });
    }
  }

  Future<void> _markInterest(String action, String fallbackMsg) async {
    if (_interestLoading) return;
    setState(() => _interestLoading = true);
    final result = await widget.api.markInterest(widget.reel.id, action);
    if (!mounted) return;
    setState(() => _interestLoading = false);

    final optimistic = action == 'not_interested';
    final message = optimistic
        ? fallbackMsg
        : (result.success
            ? (result.message.isNotEmpty ? result.message : fallbackMsg)
            : (result.message.isNotEmpty ? result.message : 'Could not update preference'));

    if (result.success || optimistic) {
      setState(() => _toast = message);
      Future.delayed(const Duration(milliseconds: 1700), () {
        if (mounted) setState(() => _toast = null);
      });
    }
  }

  bool get _hasProducts =>
      _liveProducts.isNotEmpty || widget.reel.products.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final user = widget.reel.user;
    final layout = ReelLayoutMetrics.of(context, productStripOpen: _productStripOpen && _hasProducts);
    final hasThumb = widget.reel.thumbnailUrl != null && widget.reel.thumbnailUrl!.isNotEmpty;
    final hasMusic = widget.reel.musicId != null && widget.reel.musicId!.isNotEmpty;
    final musicLabel = widget.reel.music;
    final showMusicLabel = musicLabel != null &&
        musicLabel.isNotEmpty &&
        !RegExp(r'^[a-f0-9]{24}$', caseSensitive: false).hasMatch(musicLabel);

    if (widget.isActive && !_productsFetched) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchProducts());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        Positioned(
          top: layout.safeTop,
          left: layout.safeLeft,
          right: layout.safeRight,
          bottom: layout.safeBottom,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasThumb && !_playbackStarted)
                  Image.network(
                    widget.reel.thumbnailUrl!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                if (_initialized && _controller != null)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _togglePlayPause,
                  child: _paused
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                            child: const Icon(Icons.play_arrow, color: Colors.white, size: 42),
                          ),
                        )
                      : const SizedBox.expand(),
                ),
                if (!_initialized && !hasThumb)
                  const Center(child: CircularProgressIndicator(color: Color(0xFFfb5404))),
              ],
            ),
          ),
        ),
        Positioned(
          top: layout.safeTop + 8,
          right: layout.safeRight + 12,
          child: IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, color: Colors.white, size: 22),
            style: IconButton.styleFrom(backgroundColor: Colors.black45),
          ),
        ),
        Positioned(
          right: layout.safeRight + 10,
          bottom: layout.actionsBottom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionBtn(
                icon: _liked ? Icons.favorite : Icons.favorite_border,
                label: _formatCount(_likeCount),
                color: _liked ? Colors.red : Colors.white,
                onTap: _handleLike,
              ),
              _ActionBtn(icon: Icons.chat_bubble_outline, label: _formatCount(_commentCount), onTap: _openComments),
              _ActionBtn(icon: Icons.share_outlined, label: 'Share', onTap: _handleShare),
              // if (hasMusic)
              //   _ActionBtn(icon: Icons.music_note, label: 'Music', onTap: () {}),
              _ActionBtn(icon: Icons.more_vert, label: '', onTap: _showInterestSheet),
              // Show shop bag when products exist but strip is hidden
              if (_hasProducts && !_productStripOpen)
                _ActionBtn(
                  icon: Icons.shopping_bag_outlined,
                  label: '',
                  onTap: () => setState(() => _productStripOpen = true),
                ),
              const SizedBox(height: 46),
            ],
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          left: layout.safeLeft + 12,
          right: layout.rightGutter,
          bottom: layout.userInfoBottom,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  PlayUserAvatar(
                    radius: 16,
                    imageUrl: user.avatar,
                    fallbackLetter: user.username ?? 'U',
                    onTap: _openProfile,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: GestureDetector(
                      onTap: _openProfile,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: reelOverlayText(15).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  if (user.id.isNotEmpty && user.id != widget.api.viewerId) ...[
                    const SizedBox(width: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: reelOverlayBoxShadow,
                      ),
                      child: TextButton(
                        onPressed: _handleFollow,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: _following ? 0.12 : 0.22),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: _following ? 0.45 : 0.65),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: Text(
                          _following ? 'Following' : 'Follow',
                          style: reelOverlayText(12).copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: _following ? 0.85 : 1),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (widget.reel.caption.isNotEmpty) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => CaptionSheet.show(
                    context,
                    caption: widget.reel.caption,
                    views: widget.reel.viewCount,
                    products: widget.reel.products,
                  ),
                  child: Text(
                    widget.reel.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: reelOverlayText(13),
                  ),
                ),
              ],
              if (showMusicLabel) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    reelOverlayIcon(Icons.music_note, color: Colors.white.withValues(alpha: 0.8), size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        musicLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: reelOverlayText(12),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Positioned(
          left: layout.safeLeft,
          right: layout.safeRight,
          bottom: layout.productStripBottom,
          child: ProductStrip(
            liveProducts: _liveProducts,
            reelProducts: widget.reel.products,
            loading: _loadingProducts,
            error: _productsError,
            visible: _productStripOpen && _hasProducts,
            onClose: () => setState(() => _productStripOpen = false),
            onProductTap: (slugOrId) => openProductInShop(slugOrId),
          ),
        ),
        Positioned(
          left: layout.safeLeft,
          right: layout.safeRight,
          bottom: layout.progressBarBottom,
          child: ReelProgressBar(
            progress: _progress,
            visible: widget.isActive && _initialized && _controller != null,
            onSeekStart: _onProgressSeekStart,
            onSeekUpdate: _onProgressSeekUpdate,
            onSeekEnd: _onProgressSeekEnd,
          ),
        ),
        if (_toast != null)
          Positioned(
            left: layout.safeLeft + 24,
            right: layout.safeRight + 24,
            bottom: layout.safeBottom + 72,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(_toast!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
      ],
    );
  }

  String _formatCount(int n) {
    if (n <= 0) return '0';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    this.color = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            reelOverlayIcon(icon, color: color, size: 30),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(label, style: reelOverlayText(11)),
            ],
          ],
        ),
      ),
    );
  }
}
