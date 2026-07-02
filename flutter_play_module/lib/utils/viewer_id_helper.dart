bool isValidObjectId(String? value) {
  if (value == null || value.isEmpty) return false;
  return RegExp(r'^[a-f0-9]{24}$', caseSensitive: false).hasMatch(value);
}

/// Same stable guest id algorithm as RN playProfileHelper.toStableObjectId
String stableGuestIdFromDevice(String deviceId) {
  var h1 = 0;
  var h2 = 0;
  var h3 = 0;

  for (var i = 0; i < deviceId.length; i++) {
    final code = deviceId.codeUnitAt(i);
    h1 = (h1 * 31 + code) & 0xFFFFFFFF;
    h2 = (h2 * 37 + code) & 0xFFFFFFFF;
    h3 = (h3 * 41 + code) & 0xFFFFFFFF;
  }

  final hex = '${h1.toRadixString(16).padLeft(8, '0')}'
      '${h2.toRadixString(16).padLeft(8, '0')}'
      '${h3.toRadixString(16).padLeft(8, '0')}';
  return hex.substring(0, 24);
}

String resolveViewerIdForFeed(String viewerId, String deviceId) {
  if (isValidObjectId(viewerId)) return viewerId;
  if (deviceId.isNotEmpty) return stableGuestIdFromDevice(deviceId);
  return viewerId.isNotEmpty ? viewerId : stableGuestIdFromDevice('guest');
}
