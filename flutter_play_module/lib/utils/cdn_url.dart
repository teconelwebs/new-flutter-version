/// Product/media CDN — matches RN `CDN_BASE_URL` in constants/urlconstants.ts
const kCdnBaseUrl = 'https://d1f02fefkbso7w.cloudfront.net';

/// Builds a full CDN URL from a relative path like `1116/1116-020626-830061.webp`.
String cdnImageUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  final trimmed = path.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  final normalized = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
  return '$kCdnBaseUrl/$normalized';
}
