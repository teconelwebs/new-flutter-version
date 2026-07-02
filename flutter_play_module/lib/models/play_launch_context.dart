class PlayLaunchContext {
  final String mainUserId;
  final String mobile;
  final bool playProfileReady;

  const PlayLaunchContext({
    this.mainUserId = '',
    this.mobile = '',
    this.playProfileReady = true,
  });

  bool get needsSetup =>
      !playProfileReady && mainUserId.isNotEmpty && mobile.isNotEmpty;

  factory PlayLaunchContext.fromQuery(Map<String, String> params) {
    final ready = params['playProfileReady'];
    return PlayLaunchContext(
      mainUserId: params['mainUserId'] ?? '',
      mobile: params['mobile'] ?? '',
      playProfileReady: ready != '0' && ready != 'false',
    );
  }
}
