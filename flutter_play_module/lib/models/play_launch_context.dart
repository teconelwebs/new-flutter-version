class PlayLaunchContext {
  final String mainUserId;
  final String mobile;
  final String name;
  final bool playProfileReady;

  const PlayLaunchContext({
    this.mainUserId = '',
    this.mobile = '',
    this.name = '',
    // Default false — missing ready flag must not skip username setup.
    this.playProfileReady = false,
  });

  static bool _isGuestMainUserId(String id) {
    final v = id.trim().toLowerCase();
    return v.isEmpty || v == 'guest' || v.startsWith('guest_');
  }

  /// Logged-in shop user without a real Play username must set one up.
  /// Mobile is preferred but not required (sheet can resolve mobile from prefs).
  bool get needsSetup {
    if (playProfileReady) return false;
    if (_isGuestMainUserId(mainUserId)) return false;
    return true;
  }

  factory PlayLaunchContext.fromQuery(Map<String, String> params) {
    final ready = params['playProfileReady'];
    return PlayLaunchContext(
      mainUserId: params['mainUserId'] ?? '',
      mobile: params['mobile'] ?? '',
      name: params['name'] ?? '',
      playProfileReady: ready == '1' || ready == 'true',
    );
  }
}
