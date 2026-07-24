import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/play_launch_context.dart';
import '../widgets/play_profile_setup_sheet.dart';
import 'play_profile_helper.dart';
import 'play_session.dart';

/// Blocks gated actions until the logged-in user has a real Play username.
/// Returns true when the action may proceed.
Future<bool> ensurePlayProfileForAction(BuildContext context) async {
  final launchContext = PlaySession.launchContextOf(context);
  final scope = playSessionScopeOf(context);
  final api = PlaySession.apiOf(context);

  final prefs = await SharedPreferences.getInstance();
  if (!context.mounted) return false;

  final mainUserId = (prefs.getString('user_id') ?? '').trim();
  final token = (prefs.getString('access_token') ?? '').trim();
  final loggedIn = mainUserId.isNotEmpty &&
      token.isNotEmpty &&
      mainUserId.toLowerCase() != 'guest';

  // Guests can browse; gated social actions only force setup for logged-in users.
  if (!loggedIn) {
    if (!launchContext.needsSetup) return true;
  } else {
    final ready = await PlayProfileHelper.isPlayUsernameReady();
    if (!context.mounted) return false;
    if (ready) {
      scope?.markPlayProfileReady();
      return true;
    }
  }

  if (scope == null) return true;

  final userData = await PlayProfileHelper.getPlayProfileUserData();
  if (!context.mounted) return false;

  final sheetContext = userData != null
      ? PlayLaunchContext(
          mainUserId: userData.mainUserId,
          mobile: userData.mobile.isNotEmpty
              ? userData.mobile
              : launchContext.mobile,
          name: userData.name.isNotEmpty ? userData.name : launchContext.name,
          playProfileReady: false,
        )
      : PlayLaunchContext(
          mainUserId: mainUserId.isNotEmpty
              ? mainUserId
              : launchContext.mainUserId,
          mobile: launchContext.mobile,
          name: launchContext.name,
          playProfileReady: false,
        );

  if (sheetContext.mainUserId.isEmpty ||
      sheetContext.mainUserId.toLowerCase() == 'guest') {
    // Can't create a play profile without a shop login id.
    return true;
  }

  return PlayProfileSetupSheet.show(
    context,
    launchContext: sheetContext,
    deviceId: api.deviceId,
    onCreated: scope.onProfileCreated,
    onDismissed: () {
      // Action-triggered sheet: keep watching reels; don't reset auto-prompt.
    },
  );
}
