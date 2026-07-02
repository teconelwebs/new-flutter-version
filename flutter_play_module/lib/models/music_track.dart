class MusicTrack {
  static final _mongoIdPattern = RegExp(r'^[a-f0-9]{24}$', caseSensitive: false);

  final String id;
  final String title;
  final String artist;
  final String url;
  final String? coverUrl;
  final int durationMs;

  MusicTrack({
    required this.id,
    required this.title,
    this.artist = '',
    required this.url,
    this.coverUrl,
    this.durationMs = 0,
  });

  bool get hasMongoId => isMongoId(id);

  static bool isMongoId(String value) => _mongoIdPattern.hasMatch(value.trim());

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    final duration = _readDurationMs(json);
    return MusicTrack(
      id: _readId(json),
      title: json['title']?.toString() ?? json['name']?.toString() ?? 'Untitled',
      artist: json['artist']?.toString() ?? json['singer']?.toString() ?? '',
      url: json['url']?.toString() ?? json['audioUrl']?.toString() ?? '',
      coverUrl: _readCover(json),
      durationMs: duration,
    );
  }

  static String _readId(Map<String, dynamic> json) {
    final raw = json['_id'] ?? json['id'];
    if (raw == null) return '';
    if (raw is String) return raw.trim();
    if (raw is Map) {
      final oid = raw[r'$oid'] ?? raw['oid'];
      if (oid != null) return oid.toString().trim();
    }
    final text = raw.toString().trim();
    return text == 'null' ? '' : text;
  }

  static String? _readCover(Map<String, dynamic> json) {
    for (final key in [
      'cover',
      'coverPhoto',
      'coverPhotoUrl',
      'imageUrl',
      'image',
      'thumbnail',
      'thumbnailUrl',
      'artwork',
      'poster',
    ]) {
      final value = json[key]?.toString();
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return null;
  }

  static int _readDurationMs(Map<String, dynamic> json) {
    final raw = json['duration'] ?? json['durationMs'] ?? json['durationSeconds'] ?? json['length'] ?? json['time'];
    if (raw is num) {
      final v = raw.toDouble();
      if (json['durationSeconds'] != null || json['length'] != null || json['time'] != null) {
        return (v * 1000).round();
      }
      return v >= 1000 ? v.round() : (v * 1000).round();
    }
    return 0;
  }
}

class MusicPageResult {
  final List<MusicTrack> items;
  final bool hasMore;

  const MusicPageResult({required this.items, required this.hasMore});
}
