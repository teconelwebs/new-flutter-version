import 'dart:async';

import 'package:video_player/video_player.dart';

import '../models/reel.dart';
import 'adaptive_prefetch_engine.dart';

enum PreloadState { idle, loading, ready, failed }

class VideoPreloadPool {
  VideoPreloadPool(this.config);

  final AdaptivePrefetchConfig config;
  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, Future<void>> _initFutures = {};
  final Map<String, PreloadState> _states = {};

  PreloadState stateFor(String reelId) => _states[reelId] ?? PreloadState.idle;

  Future<VideoPlayerController?> obtain(String reelId, String url) async {
    if (url.isEmpty) return null;

    final existing = _controllers[reelId];
    if (existing != null) {
      final failed = _states[reelId] == PreloadState.failed ||
          (existing.value.isInitialized && existing.value.hasError);
      if (failed) release(reelId);
    }

    if (!_controllers.containsKey(reelId)) {
      await warm(reelId, url, priority: true);
    } else {
      final future = _initFutures[reelId];
      if (future != null) {
        try {
          await future.timeout(
            Duration(milliseconds: (config.initTimeoutSec * 1000).round()),
          );
        } catch (_) {}
      }
    }

    return _controllers[reelId];
  }

  void stop(String reelId) {
    final controller = _controllers[reelId];
    if (controller == null) return;
    try {
      if (controller.value.isInitialized) {
        controller.pause();
      }
    } catch (_) {}
  }

  void pauseExcept(String? keepReelId) {
    for (final entry in _controllers.entries) {
      if (entry.key == keepReelId) continue;
      final controller = entry.value;
      try {
        if (controller.value.isInitialized) controller.pause();
      } catch (_) {}
    }
  }

  Future<void> ensureAudible(String reelId) async {
    final controller = _controllers[reelId];
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.setVolume(1);
    } catch (_) {}
  }

  void release(String reelId) {
    stop(reelId);
    final controller = _controllers.remove(reelId);
    _initFutures.remove(reelId);
    _states.remove(reelId);
    try {
      controller?.dispose();
    } catch (_) {}
  }

  Future<void> warm(String reelId, String url, {bool priority = false}) async {
    if (url.isEmpty) return;
    if (_controllers.containsKey(reelId)) {
      if (priority) await _initFutures[reelId];
      return;
    }

    _states[reelId] = PreloadState.loading;

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controllers[reelId] = controller;

    final init = controller.initialize().then((_) async {
      if (controller.value.hasError) {
        _states[reelId] = PreloadState.failed;
        return;
      }
      controller.setLooping(true);
      _states[reelId] = PreloadState.ready;
      if (priority) {
        try {
          await controller.setVolume(0);
          await controller.play();
          await controller.seekTo(Duration.zero);
          await controller.pause();
          await controller.setVolume(1);
        } catch (_) {}
      }
    }).catchError((_) {
      _states[reelId] = PreloadState.failed;
      controller.dispose();
      _controllers.remove(reelId);
      _initFutures.remove(reelId);
    });

    _initFutures[reelId] = init;
    if (priority) await init;
  }

  Future<void> prefetchWindow(
    List<Reel> reels,
    int centerIndex, {
    int extraAhead = 0,
    bool waitForFirst = false,
  }) async {
    if (reels.isEmpty) return;

    final ahead = config.preloadAhead + extraAhead;
    final behind = config.preloadBehind;
    final indices = <int>[];

    for (var i = centerIndex - behind; i <= centerIndex + ahead; i++) {
      if (i >= 0 && i < reels.length) indices.add(i);
    }

    indices.sort((a, b) {
      final da = (a - centerIndex).abs();
      final db = (b - centerIndex).abs();
      if (da != db) return da.compareTo(db);
      return a.compareTo(b);
    });

    if (waitForFirst) {
      final reel = reels[centerIndex];
      await warm(reel.id, reel.playbackUrl, priority: true);
    }

    final rest = waitForFirst
        ? indices.where((i) => i != centerIndex).toList()
        : indices;

    for (var start = 0; start < rest.length; start += config.maxConcurrentInits) {
      final batch = rest.skip(start).take(config.maxConcurrentInits);
      await Future.wait(
        batch.map((i) {
          final reel = reels[i];
          return warm(reel.id, reel.playbackUrl);
        }),
        eagerError: false,
      );
    }
  }

  void prefetchWindowBackground(
    List<Reel> reels,
    int centerIndex, {
    int extraAhead = 0,
  }) {
    unawaited(prefetchWindow(reels, centerIndex, extraAhead: extraAhead));
  }

  void trimOutside(List<Reel> reels, int centerIndex, {int extraAhead = 0}) {
    if (reels.isEmpty) return;

    final keep = <String>{};
    final ahead = config.preloadAhead + extraAhead + 1;
    final behind = config.preloadBehind + 1;

    for (var i = centerIndex - behind; i <= centerIndex + ahead; i++) {
      if (i >= 0 && i < reels.length) keep.add(reels[i].id);
    }

    final toRemove = _controllers.keys.where((id) => !keep.contains(id)).toList();
    for (final id in toRemove) {
      release(id);
    }
  }

  void pauseAll() {
    for (final c in _controllers.values) {
      if (c.value.isInitialized) c.pause();
    }
  }

  void disposeAll() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _initFutures.clear();
    _states.clear();
  }
}
