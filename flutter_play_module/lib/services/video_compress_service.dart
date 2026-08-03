import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:v_video_compressor/v_video_compressor.dart';

/// Size-aware compression: targets safe output sizes while keeping quality close to original.
class VideoCompressService {
  static final VVideoCompressor _compressor = VVideoCompressor();

  /// Original size (MB) → target max output (MB) midpoints from product spec.
  static const List<(double originalMb, double targetMaxMb)> _anchors = [
    (45, 22.5),   // Compress 45 MB to 22.5 MB (exactly 20–25 MB)
    (50, 27.5),   // 20–35 MB
    (100, 55),    // 40–70 MB
    (150, 80),    // 60–100 MB
    (200, 105),   // 80–130 MB
    (300, 150),   // 120–180 MB
    (400, 185),   // 150–220 MB
    (500, 220),   // 180–260 MB
    (1000, 325),  // 250–400 MB
  ];

  /// Below ~35 MB we keep the original (already in the safe zone for short reels).
  static const double skipBelowMb = 35;

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
    bool force = false,
    void Function(double progress)? onProgress,
  }) async {
    if (!await input.exists()) return input;

    final bytes = await input.length();
    final sizeMb = bytes / (1024 * 1024);
    final isMov = input.path.toLowerCase().endsWith('.mov') || input.path.toLowerCase().endsWith('.qt');
    final needsTranscode = force || isMov;

    if (!needsTranscode && sizeMb <= skipBelowMb) {
      return input; // Safe to skip compression for standard small MP4s
    }

    final targetMb = targetMaxMbForOriginal(sizeMb) ?? (needsTranscode ? sizeMb * 0.95 : null);
    if (targetMb == null) return input;

    if (!needsTranscode && targetMb >= sizeMb * 0.92) return input;

    VVideoInfo? info;
    try {
      info = await _compressor.getVideoInfo(input.path);
    } catch (e) {
      debugPrint("⚠️ Native getVideoInfo failed: $e");
    }

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
      advanced: info != null ? VVideoAdvancedConfig(
        videoBitrate: videoBps,
        audioBitrate: audioBps,
        crf: 20,
        variableBitrate: true,
        hardwareAcceleration: true,
        encodingSpeed: VEncodingSpeed.faster,
        autoCorrectOrientation: true,
        dimensionHandling: VDimensionHandling.autoAlign,
      ) : null,
    );

    dynamic result;
    try {
      result = await _compressor.compressVideo(
        input.path,
        config,
        onProgress: onProgress,
      );
    } catch (e) {
      debugPrint("⚠️ Video compression native plugin error: $e");
    }

    if (result == null || result.compressedFilePath.isEmpty) {
      try {
        debugPrint("🔄 Fallback 1: Attempting standard high-quality compression...");
        final fallbackConfig1 = VVideoCompressionConfig(
          quality: VVideoCompressQuality.high,
          includeAudio: true,
          useFastStart: true,
          useHardwareAcceleration: true,
          optimizeForStreaming: true,
        );
        result = await _compressor.compressVideo(
          input.path,
          fallbackConfig1,
          onProgress: onProgress,
        );
      } catch (e1) {
        debugPrint("❌ Fallback 1 failed: $e1");
      }
    }

    if (result == null || result.compressedFilePath.isEmpty) {
      try {
        debugPrint("🔄 Fallback 2: Attempting standard medium-quality compression (720p)...");
        final fallbackConfig2 = VVideoCompressionConfig(
          quality: VVideoCompressQuality.medium,
          includeAudio: true,
          useFastStart: true,
          useHardwareAcceleration: true,
          optimizeForStreaming: true,
        );
        result = await _compressor.compressVideo(
          input.path,
          fallbackConfig2,
          onProgress: onProgress,
        );
      } catch (e2) {
        debugPrint("❌ Fallback 2 failed: $e2");
      }
    }

    if (result == null || result.compressedFilePath.isEmpty) {
      try {
        debugPrint("🔄 Fallback 3: Attempting standard medium-quality without hardware acceleration...");
        final fallbackConfig3 = VVideoCompressionConfig(
          quality: VVideoCompressQuality.medium,
          includeAudio: true,
          useFastStart: true,
          useHardwareAcceleration: false,
          optimizeForStreaming: true,
        );
        result = await _compressor.compressVideo(
          input.path,
          fallbackConfig3,
          onProgress: onProgress,
        );
      } catch (e3) {
        debugPrint("❌ Fallback 3 failed: $e3");
      }
    }

    if (result == null || result.compressedFilePath.isEmpty) return input;

    final out = File(result.compressedFilePath);
    if (!await out.exists()) return input;

    final compressedMb = result.compressedSizeBytes / (1024 * 1024);
    final savedRatio = 1 - (result.compressedSizeBytes / bytes);

    if (!needsTranscode) {
      if (savedRatio < 0.08) return input;
      if (compressedMb > targetMb * 1.35 && savedRatio < 0.2) return input;
    }

    return out;
  }
}
