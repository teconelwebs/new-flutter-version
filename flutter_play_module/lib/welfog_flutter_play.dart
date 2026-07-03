/// Play / Reels module — import from main Welfog app only for play features.
library welfog_flutter_play;

export 'models/play_launch_context.dart';
export 'utils/app_routes.dart';
export 'utils/flutter_nav.dart';
export 'utils/play_profile_helper.dart';
export 'screens/reels_screen.dart';
export 'utils/play_session.dart';

import 'package:flutter/material.dart';
import 'utils/play_session.dart';
import 'models/play_launch_context.dart';
import 'screens/reels_screen.dart';

class EmbeddedReelsWrapper extends StatelessWidget {
  final String viewerId;

  const EmbeddedReelsWrapper({
    super.key,
    required this.viewerId,
  });

  @override
  Widget build(BuildContext context) {
    return PlaySessionScope(
      initialViewerId: viewerId,
      deviceId: '',
      shareUserId: '',
      launchContext: const PlayLaunchContext(playProfileReady: true),
      child: const ReelsScreen(),
    );
  }
}
