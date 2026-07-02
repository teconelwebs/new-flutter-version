class ProfilePost {
  final String id;
  final String? thumbnailUrl;
  final int views;
  final String? videoUrl;
  final String? status;
  final List<String> qualityVariants;
  final String? error;
  final DateTime? createdAt;

  ProfilePost({
    required this.id,
    this.thumbnailUrl,
    this.views = 0,
    this.videoUrl,
    this.status,
    this.qualityVariants = const [],
    this.error,
    this.createdAt,
  });

  bool get isFailed => status?.toLowerCase() == 'failed';

  bool get hasHdQuality => qualityVariants.contains('720p');

  /// Processing stuck on server longer than this is treated as failed in UI.
  static const preparingStaleAfter = Duration(hours: 2);

  bool get _rawPreparing {
    final s = status?.toLowerCase();
    if (s == 'processing') return true;
    if (s == 'published' && !hasHdQuality) {
      return videoUrl != null && videoUrl!.isNotEmpty;
    }
    return false;
  }

  bool get isStalePreparing {
    if (isFailed || createdAt == null || !_rawPreparing) return false;
    return DateTime.now().difference(createdAt!) > preparingStaleAfter;
  }

  /// Still encoding on server (or early published without full HD ladder).
  bool get isPreparing => !isFailed && _rawPreparing && !isStalePreparing;

  /// Failed on server or stuck preparing — owner can retry/cancel.
  bool get needsOwnerRecovery => isFailed || isStalePreparing;

  bool get isPlayable =>
      !isFailed && !isPreparing && videoUrl != null && videoUrl!.isNotEmpty;

  /// Backward-compatible alias used across profile grid.
  bool get isProcessing => !isPlayable && !isFailed;

  static String? _readThumbnail(Map<String, dynamic> json) {
    for (final key in ['thumbnailUrl', 'thumbnail', 'posterUrl', 'thumbnail_img']) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String? _readVideoUrl(Map<String, dynamic> json) {
    for (final key in ['videoUrl', 'masterHlsUrl', 'hlsUrl']) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static DateTime? _readCreatedAt(Map<String, dynamic> json) {
    final raw = json['createdAt'] ?? json['created_at'];
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }

  factory ProfilePost.fromJson(Map<String, dynamic> json) {
    final variantsRaw = json['qualityVariants'];
    final variants = variantsRaw is List
        ? variantsRaw.map((e) => e.toString()).toList()
        : <String>[];

    return ProfilePost(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      thumbnailUrl: _readThumbnail(json),
      views: (json['views'] as num?)?.toInt() ?? 0,
      videoUrl: _readVideoUrl(json),
      status: json['status']?.toString(),
      qualityVariants: variants,
      error: json['error']?.toString(),
      createdAt: _readCreatedAt(json),
    );
  }
}
