import 'package:flutter/material.dart';

import '../models/play_launch_context.dart';
import '../services/play_profile_service.dart';
import '../utils/flutter_nav.dart';
import '../utils/play_profile_helper.dart';

/// Bottom sheet for new users — matches RN PlayProfileSetupSheet UX.
class PlayProfileSetupSheet extends StatefulWidget {
  final PlayLaunchContext launchContext;
  final String deviceId;
  final ValueChanged<String> onCreated;
  final VoidCallback onDismissed;

  const PlayProfileSetupSheet({
    super.key,
    required this.launchContext,
    required this.deviceId,
    required this.onCreated,
    required this.onDismissed,
  });

  static Future<bool> show(
    BuildContext context, {
    required PlayLaunchContext launchContext,
    required String deviceId,
    required ValueChanged<String> onCreated,
    required VoidCallback onDismissed,
  }) async {
    var profileCreated = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) => PlayProfileSetupSheet(
        launchContext: launchContext,
        deviceId: deviceId,
        onCreated: (id) {
          profileCreated = true;
          onCreated(id);
        },
        onDismissed: onDismissed,
      ),
    );
    return profileCreated;
  }

  @override
  State<PlayProfileSetupSheet> createState() => _PlayProfileSetupSheetState();
}

class _PlayProfileSetupSheetState extends State<PlayProfileSetupSheet> {
  final _usernameController = TextEditingController();
  bool _creating = false;
  String? _errorText;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final username = _usernameController.text.trim();
    final mainUserId = widget.launchContext.mainUserId.trim();
    if (username.isEmpty) {
      setState(() => _errorText = 'Please enter a username.');
      return;
    }
    if (PlayProfileService.isPlaceholderUsername(username, mainUserId)) {
      setState(() => _errorText = 'Please choose a custom username.');
      return;
    }

    setState(() {
      _creating = true;
      _errorText = null;
    });

    try {
      var mobile = widget.launchContext.mobile.trim();
      var name = widget.launchContext.name.trim();
      if (mobile.isEmpty || name.isEmpty) {
        final userData = await PlayProfileHelper.getPlayProfileUserData();
        if (mobile.isEmpty) mobile = (userData?.mobile ?? '').trim();
        if (name.isEmpty) name = (userData?.name ?? '').trim();
      }

      debugPrint(
        '🎮 [PlaySetup] submit — mainUserId(OTP)=$mainUserId '
        'mobile=$mobile username=$username name=$name',
      );
      if (mobile.isEmpty) {
        if (!mounted) return;
        setState(() {
          _creating = false;
          _errorText = 'Mobile number missing. Please re-login and try again.';
        });
        return;
      }

      final service = PlayProfileService(deviceId: widget.deviceId);
      // Name dialog may have already created mongo profile — only set username.
      var existingMongoId =
          await PlayProfileHelper.ensurePlayProfileMongoId();
      // Fallback: resolve by mobile so we never mint a duplicate profile.
      if ((existingMongoId == null || existingMongoId.isEmpty) &&
          mobile.isNotEmpty) {
        existingMongoId =
            await PlayProfileHelper.resolvePlayUserIdByMobile();
      }

      late final String playUserId;
      if (existingMongoId != null && existingMongoId.isNotEmpty) {
        await service.updateUsername(
          playMongoId: existingMongoId,
          username: username,
          mainUserId: mainUserId,
          name: name,
          mobile: mobile,
        );
        playUserId = existingMongoId;
        debugPrint(
          '🎮 [PlaySetup] username updated on existing mongoId=$playUserId '
          'userid=$mainUserId username=$username',
        );
      } else {
        playUserId = await service.createPlayProfile(
          mainUserId: mainUserId,
          mobile: mobile,
          username: username,
          name: name,
        );
        debugPrint(
          '🎮 [PlaySetup] profile created mongoId=$playUserId '
          'userid=$mainUserId username=$username',
        );
      }
      await PlayProfileHelper.cachePlayProfileCreated(
        playUserId: playUserId,
        username: username,
        mainUserId: mainUserId,
        usernameReady: true,
      );
      await service.syncMainUserId(
        playMongoId: playUserId,
        mainUserId: mainUserId,
      );
      await notifyPlayProfileCreated(playUserId, username);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCreated(playUserId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _errorText = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _handleLater() {
    Navigator.of(context).pop();
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFB5204).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFFB5204), size: 34),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Create Play Profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a username to enjoy videos, upload videos, and connect with creators.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _usernameController,
                  enabled: !_creating,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  maxLength: 30,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  cursorColor: const Color(0xFFFB5204),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Enter username',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _errorText != null ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _errorText != null ? const Color(0xFFEF4444) : const Color(0xFFFB5204),
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _handleCreate(),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _errorText!,
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _creating ? null : _handleCreate,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFB5204),
                      disabledBackgroundColor: const Color(0xFFFB5204).withValues(alpha: 0.6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _creating
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                TextButton(
                  onPressed: _creating ? null : _handleLater,
                  child: const Text(
                    'Maybe Later',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
