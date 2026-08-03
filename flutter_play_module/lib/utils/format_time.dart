String formatMillis(int millis) {
  final totalSeconds = millis ~/ 1000;
  final seconds = totalSeconds % 60;
  final minutes = totalSeconds ~/ 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

bool isDefaultPlayUsername(String? username) {
  if (username == null || username.isEmpty) return false;
  return RegExp(r'^user\d+$', caseSensitive: false).hasMatch(username);
}

bool isMp4VideoPath(String path, {String? mimeType}) {
  final lower = path.toLowerCase();
  final mime = mimeType?.toLowerCase() ?? '';
  // Support MP4, MOV/QuickTime, MKV, 3GP, and WebM formats since we can transcode them
  return lower.contains('.mp4') || lower.endsWith('.mp4') || mime.contains('mp4') ||
         lower.contains('.mov') || lower.endsWith('.mov') || mime.contains('quicktime') ||
         lower.contains('.3gp') || lower.endsWith('.3gp') || mime.contains('3gpp') ||
         lower.contains('.mkv') || lower.endsWith('.mkv') || mime.contains('x-matroska') ||
         lower.contains('.webm') || lower.endsWith('.webm') || mime.contains('webm');
}
