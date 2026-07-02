import 'dart:io';

import 'package:v_video_compressor/v_video_compressor.dart';

/// Size-aware compression: targets safe output sizes while keeping quality close to original.
class VideoCompressService {
  static final VVideoCompressor _compressor = VVideoCompressor();

  /// Original size (MB) → target max output (MB) midpoints from product spec.
  static const List<(double originalMb, double targetMaxMb)> _anchors = [
    (50, 27.5),   // 20–35 MB
    (100, 55),    // 40–70 MB
    (150, 80),    // 60–100 MB
    (200, 105),   // 80–130 MB
    (300, 150),   // 120–180 MB
    (400, 185),   // 150–220 MB
    (500, 220),   // 180–260 MB
    (1000, 325),  // 250–400 MB
  ];

  /// Below ~45 MB we keep the original (already in the safe zone for short reels).
  static const double skipBelowMb = 45;

  static double? targetMaxMbForOriginal(double originalMb) {
    if (originalMb <= skipBelowMb) return null;

    if (originalMb <= _anchors.first.$1) {
      return _anchors.first.$2;
    }

    for (var i = 0; i < _anchors.length - 1; i++) {
      final a = _anchors[i];
      final b = _anchors[i + 1];
      if (originalMb <= b.$1) {
        final t = (originalMb - a.$1) / (b.$1 - a.$1);
        return a.$2 + t * (b.$2 - a.$2);
      }
    }

    final last = _anchors.last;
    final prev = _anchors[_anchors.length - 2];
    final slope = (last.$2 - prev.$2) / (last.$1 - prev.$1);
    return last.$2 + slope * (originalMb - last.$1);
  }

  static Future<File> compressForUpload(
    File input, {
    void Function(double progress)? onProgress,
  }) async {
    if (!await input.exists()) return input;

    final bytes = await input.length();
    final sizeMb = bytes / (1024 * 1024);
    final targetMb = targetMaxMbForOriginal(sizeMb);

    if (targetMb == null || targetMb >= sizeMb * 0.92) return input;

    final info = await _compressor.getVideoInfo(input.path);
    final durationSec = ((info?.durationMillis ?? 0) / 1000).clamp(1, 3600);

    final targetBytes = (targetMb * 1024 * 1024).round();
    const audioBps = 128000;
    final videoBps = (((targetBytes * 8) / durationSec) - audioBps)
        .round()
        .clamp(900000, 8000000);

    final config = VVideoCompressionConfig(
      quality: VVideoCompressQuality.high,
      includeAudio: true,
      useFastStart: true,
      useHardwareAcceleration: true,
      optimizeForStreaming: true,
      useVariableBitrate: true,
      advanced: VVideoAdvancedConfig(
        videoBitrate: videoBps,
        audioBitrate: audioBps,
        crf: 20,
        variableBitrate: true,
        hardwareAcceleration: true,
        encodingSpeed: VEncodingSpeed.faster,
        autoCorrectOrientation: true,
        dimensionHandling: VDimensionHandling.autoAlign,
      ),
    );

    final result = await _compressor.compressVideo(
      input.path,
      config,
      onProgress: onProgress,
    );

    if (result == null || result.compressedFilePath.isEmpty) return input;

    final out = File(result.compressedFilePath);
    if (!await out.exists()) return input;

    final compressedMb = result.compressedSizeBytes / (1024 * 1024);
    final savedRatio = 1 - (result.compressedSizeBytes / bytes);

    // Keep original if compression barely helped or overshot quality for little gain.
    if (savedRatio < 0.08) return input;
    if (compressedMb > targetMb * 1.35 && savedRatio < 0.2) return input;

    return out;
  }
}
