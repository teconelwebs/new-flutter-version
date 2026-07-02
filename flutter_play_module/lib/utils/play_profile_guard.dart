import 'package:flutter/material.dart';

import '../widgets/play_profile_setup_sheet.dart';
import 'play_session.dart';

/// Blocks gated actions until the user creates a Play profile.
/// Returns true when the action may proceed.
Future<bool> ensurePlayProfileForAction(BuildContext context) async {
  final launchContext = PlaySession.launchContextOf(context);
  if (!launchContext.needsSetup) return true;

  final scope = playSessionScopeOf(context);
  if (scope == null) return true;

  final api = PlaySession.apiOf(context);
  return PlayProfileSetupSheet.show(
    context,
    launchContext: launchContext,
    deviceId: api.deviceId,
    onCreated: scope.onProfileCreated,
    onDismissed: () {
      // Action-triggered sheet: keep watching reels; don't reset auto-prompt state.
    },
  );
}
