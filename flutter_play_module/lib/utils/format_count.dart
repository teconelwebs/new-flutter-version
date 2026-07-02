String formatCount(num n) {
  if (n <= 0) return '0';
  if (n >= 1000000) {
    final v = (n / 1000000).toStringAsFixed(1);
    return v.endsWith('.0') ? '${v.substring(0, v.length - 2)}M' : '${v}M';
  }
  if (n >= 1000) {
    final v = (n / 1000).toStringAsFixed(1);
    return v.endsWith('.0') ? '${v.substring(0, v.length - 2)}k' : '${v}k';
  }
  return n.toString();
}
