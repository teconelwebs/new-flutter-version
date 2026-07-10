/// Play / Reels module — import from main Welfog app only for play features.
library welfog_flutter_play;

export 'models/play_launch_context.dart';
export 'utils/app_routes.dart';
export 'utils/flutter_nav.dart';
export 'utils/play_profile_helper.dart';
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

  const EmbeddedReelsWrapper({
    super.key,
    required this.viewerId,
    this.isActive = true,
  });

  @override
  State<EmbeddedReelsWrapper> createState() => _EmbeddedReelsWrapperState();
}

class _EmbeddedReelsWrapperState extends State<EmbeddedReelsWrapper> {
  String? _resolvedViewerId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolveViewer();
  }

  @override
  void didUpdateWidget(EmbeddedReelsWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewerId != widget.viewerId) {
      _resolveViewer();
    }
  }

  Future<void> _resolveViewer() async {
    setState(() => _loading = true);
    final id = await PlayProfileHelper.resolveReelsViewerId();
    if (mounted) {
      setState(() {
        _resolvedViewerId = id;
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

    return PlaySessionScope(
      initialViewerId: playId,
      deviceId: '',
      shareUserId: '',
      launchContext: PlayLaunchContext(
        mainUserId: widget.viewerId,
        mobile: '',
        playProfileReady: playId != widget.viewerId,
      ),
      child: ReelsScreen(isActive: widget.isActive),
    );
  }
}
