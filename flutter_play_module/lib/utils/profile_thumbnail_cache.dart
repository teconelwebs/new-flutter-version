import 'dart:async';

import 'package:flutter/material.dart';

/// Prefetches profile grid thumbnails with a small concurrency cap so scroll
/// stays smooth without opening dozens of parallel downloads.
class ProfileThumbnailCache {
  ProfileThumbnailCache._();

  static const _maxConcurrent = 4;
  static int _inFlight = 0;
  static final List<_PrefetchJob> _queue = [];
  static final Set<String> _seen = <String>{};

  static ImageProvider thumbnailProvider(String url, double logicalWidth, double devicePixelRatio) {
    final cacheWidth = (logicalWidth * devicePixelRatio).round().clamp(64, 512);
    return ResizeImage(NetworkImage(url), width: cacheWidth);
  }

  static ImageProvider avatarProvider(
    String url,
    double devicePixelRatio, {
    double logicalDiameter = 32,
  }) {
    final cacheWidth = (logicalDiameter * devicePixelRatio).round().clamp(48, 128);
    return ResizeImage(NetworkImage(url), width: cacheWidth);
  }

  static void prefetchForGrid(
    BuildContext context, {
    required Iterable<String?> urls,
    required double tileWidth,
    int maxUrls = 18,
  }) {
    _enqueue(
      context,
      urls: urls,
      logicalWidth: tileWidth,
      maxUrls: maxUrls,
    );
  }

  static void prefetchAvatars(
    BuildContext context, {
    required Iterable<String?> urls,
    double logicalDiameter = 32,
    int maxUrls = 24,
  }) {
    _enqueue(
      context,
      urls: urls,
      logicalWidth: logicalDiameter,
      maxUrls: maxUrls,
    );
  }

  static void _enqueue(
    BuildContext context, {
    required Iterable<String?> urls,
    required double logicalWidth,
    required int maxUrls,
  }) {
    if (!context.mounted) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    var added = 0;
    for (final raw in urls) {
      if (added >= maxUrls) break;
      final url = raw?.trim();
      if (url == null || url.isEmpty || !_seen.add(url)) continue;
      _queue.add(_PrefetchJob(context, url, logicalWidth, dpr));
      added++;
    }
    _pump();
  }

  static void _pump() {
    while (_inFlight < _maxConcurrent && _queue.isNotEmpty) {
      final job = _queue.removeAt(0);
      if (!job.context.mounted) continue;
      _inFlight++;
      unawaited(() async {
        try {
          await precacheImage(
            thumbnailProvider(job.url, job.logicalWidth, job.dpr),
            job.context,
          );
        } catch (_) {
          _seen.remove(job.url);
        } finally {
          _inFlight--;
          _pump();
        }
      }());
    }
  }
}

class _PrefetchJob {
  final BuildContext context;
  final String url;
  final double logicalWidth;
  final double dpr;

  const _PrefetchJob(this.context, this.url, this.logicalWidth, this.dpr);
}

/// Small avatar for reels overlay — uses resized + prefetched image cache.
class PlayUserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String fallbackLetter;
  final VoidCallback? onTap;

  const PlayUserAvatar({
    super.key,
    this.imageUrl,
    this.radius = 16,
    this.fallbackLetter = 'U',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFFFCC80),
      backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
          ? ProfileThumbnailCache.avatarProvider(
              imageUrl!,
              MediaQuery.devicePixelRatioOf(context),
              logicalDiameter: radius * 2,
            )
          : null,
      child: imageUrl == null || imageUrl!.isEmpty
          ? Text(
              fallbackLetter.isNotEmpty ? fallbackLetter.substring(0, 1).toUpperCase() : 'U',
              style: const TextStyle(color: Color(0xFF424242), fontWeight: FontWeight.bold),
            )
          : null,
    );

    if (onTap == null) return avatar;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: avatar,
    );
  }
}

void configureProfileImageCache() {
  final cache = PaintingBinding.instance.imageCache;
  cache.maximumSize = 600;
  cache.maximumSizeBytes = 128 << 20;
}
