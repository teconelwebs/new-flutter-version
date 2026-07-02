import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

/// Device-aware prefetch tuning. Uses Android SDK + hardware signals
/// (heuristic scoring — lightweight alternative to on-device ML).
class AdaptivePrefetchConfig {
  final int preloadAhead;
  final int preloadBehind;
  final int maxConcurrentInits;
  final int fastScrollBonus;
  final String tierLabel;
  final double initTimeoutSec;

  const AdaptivePrefetchConfig({
    required this.preloadAhead,
    required this.preloadBehind,
    required this.maxConcurrentInits,
    required this.fastScrollBonus,
    required this.tierLabel,
    required this.initTimeoutSec,
  });

  factory AdaptivePrefetchConfig.fallback() => const AdaptivePrefetchConfig(
        preloadAhead: 3,
        preloadBehind: 1,
        maxConcurrentInits: 2,
        fastScrollBonus: 1,
        tierLabel: 'standard',
        initTimeoutSec: 12,
      );
}

class AdaptivePrefetchEngine {
  static AdaptivePrefetchConfig? _cached;

  static Future<AdaptivePrefetchConfig> load() async {
    if (_cached != null) return _cached!;

    if (!Platform.isAndroid) {
      _cached = AdaptivePrefetchConfig.fallback();
      return _cached!;
    }

    try {
      final info = await DeviceInfoPlugin().androidInfo;
      _cached = _fromAndroidInfo(info);
    } catch (_) {
      _cached = AdaptivePrefetchConfig.fallback();
    }
    return _cached!;
  }

  static AdaptivePrefetchConfig _fromAndroidInfo(AndroidDeviceInfo info) {
    var score = 0;

    final sdk = info.version.sdkInt;
    if (sdk >= 34) {
      score += 35; // Android 14+
    } else if (sdk >= 33) {
      score += 30; // Android 13
    } else if (sdk >= 31) {
      score += 25; // Android 12
    } else if (sdk >= 29) {
      score += 18; // Android 10–11
    } else if (sdk >= 26) {
      score += 10; // Android 8–9
    } else {
      score += 4;
    }

    final cores = info.supportedAbis.length >= 2 ? 2 : 1;
    score += cores * 8;

    final model = '${info.brand} ${info.model}'.toLowerCase();
    if (_isLikelyHighEnd(model)) score += 20;
    if (_isLikelyLowEnd(model)) score -= 15;

    if (info.isPhysicalDevice == false) score += 15;

    if (score >= 75) {
      return const AdaptivePrefetchConfig(
        preloadAhead: 5,
        preloadBehind: 1,
        maxConcurrentInits: 3,
        fastScrollBonus: 2,
        tierLabel: 'ultra',
        initTimeoutSec: 15,
      );
    }
    if (score >= 50) {
      return const AdaptivePrefetchConfig(
        preloadAhead: 4,
        preloadBehind: 1,
        maxConcurrentInits: 2,
        fastScrollBonus: 1,
        tierLabel: 'high',
        initTimeoutSec: 12,
      );
    }
    if (score >= 30) {
      return const AdaptivePrefetchConfig(
        preloadAhead: 3,
        preloadBehind: 1,
        maxConcurrentInits: 2,
        fastScrollBonus: 1,
        tierLabel: 'balanced',
        initTimeoutSec: 10,
      );
    }
    return const AdaptivePrefetchConfig(
      preloadAhead: 2,
      preloadBehind: 0,
      maxConcurrentInits: 1,
      fastScrollBonus: 0,
      tierLabel: 'lite',
      initTimeoutSec: 8,
    );
  }

  static bool _isLikelyHighEnd(String model) {
    const tags = ['ultra', 'pro', 'plus', 'max', 'fold', 's2', 's3', 's24', 's23', 'pixel 8', 'pixel 9'];
    return tags.any(model.contains);
  }

  static bool _isLikelyLowEnd(String model) {
    const tags = ['go', 'lite', 'mini', 'a0', 'a1', 'a2', 'core', 'redmi 9a', 'sm-a035'];
    return tags.any(model.contains);
  }
}

/// Predicts scroll speed to temporarily boost prefetch on fast swipes.
class ScrollPredictor {
  DateTime? _lastAt;
  int _lastIndex = 0;
  double _pagesPerSecond = 0;

  void onPageChanged(int index) {
    final now = DateTime.now();
    if (_lastAt != null) {
      final ms = now.difference(_lastAt!).inMilliseconds;
      if (ms > 0) {
        _pagesPerSecond = (index - _lastIndex).abs() / ms * 1000;
      }
    }
    _lastAt = now;
    _lastIndex = index;
  }

  int extraPreload(AdaptivePrefetchConfig config) {
    if (_pagesPerSecond >= 2.5) return config.fastScrollBonus + 1;
    if (_pagesPerSecond >= 1.2) return config.fastScrollBonus;
    return 0;
  }

  bool get isFastScrolling => _pagesPerSecond >= 1.2;
}
