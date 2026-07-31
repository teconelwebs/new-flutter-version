import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;

/// Prefetches profile grid thumbnails with a small concurrency cap so scroll
/// stays smooth without opening dozens of parallel downloads.
class ProfileThumbnailCache {
  ProfileThumbnailCache._();

  static const _maxConcurrent = 4;
  static int _inFlight = 0;
  static final List<_PrefetchJob> _queue = [];
  static final Set<String> _seen = <String>{};

  static ImageProvider thumbnailProvider(String url, double logicalWidth, double devicePixelRatio) {
    final cacheWidth = (logicalWidth * devicePixelRatio).round().clamp(64, 150);
    
    // Fetch and log file size asynchronously
    unawaited(() async {
      try {
        final response = await http.head(Uri.parse(url));
        final sizeHeader = response.headers['content-length'];
        if (sizeHeader != null) {
          final sizeInBytes = int.tryParse(sizeHeader) ?? 0;
          final sizeInMb = sizeInBytes / (1024 * 1024);
          
          const originalRamMb = (1080 * 1920 * 4) / (1024 * 1024); // ~7.91 MB
          final targetHeight = (cacheWidth * 1.33).round();
          final compressedRamMb = (cacheWidth * targetHeight * 4) / (1024 * 1024);
          final savingsPercent = ((originalRamMb - compressedRamMb) / originalRamMb * 100).toStringAsFixed(1);
          
          // ignore: avoid_print
          print('--------------------------------------------------');
          // ignore: avoid_print
          print('🖼️ [ProfileThumbnailCache] THUMBNAIL OPTIMIZATION REPORT');
          // ignore: avoid_print
          print('   • Original Network File Size: ${sizeInMb.toStringAsFixed(3)} MB');
          // ignore: avoid_print
          print('   • Original Decoded RAM Size (1080x1920): ${originalRamMb.toStringAsFixed(2)} MB');
          // ignore: avoid_print
          print('   • Compressed Decoded RAM Size ($cacheWidth x $targetHeight): ${compressedRamMb.toStringAsFixed(2)} MB');
          // ignore: avoid_print
          print('   • Memory Footprint Saved: $savingsPercent% (~${(originalRamMb - compressedRamMb).toStringAsFixed(2)} MB)');
          // ignore: avoid_print
          print('   • URL: $url');
          // ignore: avoid_print
          print('--------------------------------------------------');
        }
      } catch (e) {
        debugPrint('⚠️ [ProfileThumbnailCache] failed to fetch thumbnail size: $e');
      }
    }());

    return ResizeImage(CachedNetworkImageProvider(url), width: cacheWidth);
  }

  static ImageProvider avatarProvider(
    String url,
    double devicePixelRatio, {
    double logicalDiameter = 32,
  }) {
    final cacheWidth = (logicalDiameter * devicePixelRatio).round().clamp(48, 128);
    return ResizeImage(CachedNetworkImageProvider(url), width: cacheWidth);
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
