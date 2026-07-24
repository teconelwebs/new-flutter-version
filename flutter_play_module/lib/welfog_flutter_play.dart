/// Play / Reels module — import from main Welfog app only for play features.
library welfog_flutter_play;

export 'models/play_launch_context.dart';
export 'utils/app_routes.dart';
export 'utils/flutter_nav.dart';
export 'utils/play_profile_helper.dart';
export 'services/play_profile_service.dart';
export 'screens/reels_screen.dart';
export 'utils/play_session.dart';
export 'services/device_id_store.dart';

import 'package:flutter/material.dart';
import 'utils/play_session.dart';
import 'models/play_launch_context.dart';
import 'screens/reels_screen.dart';
import 'utils/play_profile_helper.dart';

class EmbeddedReelsWrapper extends StatefulWidget {
  final String viewerId;
  final bool isActive;
  final String initialReelId;

  const EmbeddedReelsWrapper({
    super.key,
    required this.viewerId,
    this.isActive = true,
    this.initialReelId = '',
  });

  @override
  State<EmbeddedReelsWrapper> createState() => _EmbeddedReelsWrapperState();
}

class _EmbeddedReelsWrapperState extends State<EmbeddedReelsWrapper> {
  String? _resolvedViewerId;
  PlayProfileUserData? _userData;
  bool? _usernameReady;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolveViewer();
  }

  @override
  void didUpdateWidget(EmbeddedReelsWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewerId != widget.viewerId ||
        oldWidget.initialReelId != widget.initialReelId ||
        (widget.isActive && !oldWidget.isActive)) {
      _resolveViewer();
    }
  }

  Future<void> _resolveViewer() async {
    setState(() => _loading = true);
    final id = await PlayProfileHelper.ensurePlayProfileMongoId() ??
        await PlayProfileHelper.resolveReelsViewerId();
    final data = await PlayProfileHelper.getPlayProfileUserData();
    // Ready only when a real username exists — not merely a mongo doc.
    final usernameReady = await PlayProfileHelper.isPlayUsernameReady();

    debugPrint(
      '🎮 [PlayTab] resolve viewerId=$id usernameReady=$usernameReady '
      'mainUserId=${data?.mainUserId} mobile=${data?.mobile} '
      'name=${data?.name}',
    );

    if (usernameReady && widget.isActive) {
      await PlayProfileHelper.ensureMainUserIdOnPlayProfile();
    }

    if (mounted) {
      setState(() {
        _resolvedViewerId = id;
        _userData = data;
        _usernameReady = usernameReady;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFB5404)),
          ),
        ),
      );
    }

    final playId = _resolvedViewerId ?? widget.viewerId;
    final rawMain = (_userData?.mainUserId.isNotEmpty == true)
        ? _userData!.mainUserId
        : widget.viewerId;
    final mainUserId =
        (rawMain.toLowerCase() == 'guest' || rawMain.startsWith('guest_'))
            ? ''
            : rawMain;

    return PlaySessionScope(
      initialViewerId: playId,
      deviceId: '',
      shareUserId: '',
      launchContext: PlayLaunchContext(
        mainUserId: mainUserId,
        mobile: _userData?.mobile ?? '',
        name: _userData?.name ?? '',
        playProfileReady: _usernameReady ?? false,
      ),
      child: ReelsScreen(
        isActive: widget.isActive,
        initialReelId: widget.initialReelId,
      ),
    );
  }
}
