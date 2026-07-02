import 'dart:io';

import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../utils/play_session.dart';
import '../widgets/profile_widgets.dart';
import '../utils/profile_image_picker.dart';
import '../utils/profile_theme.dart';
import 'edit_mobile_screen.dart';
import 'edit_profile_field_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;
  bool _uploadingPhoto = false;
  File? _localImage;
  bool _initialized = false;

  String _name = '';
  String _username = '';
  String _email = '';
  String _mobile = '';
  String _bio = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _load();
    }
  }

  Future<void> _load() async {
    final api = PlaySession.apiOf(context);
    try {
      final profile = await api.fetchUserProfile(api.viewerId);
      if (!mounted) return;
      _applyProfile(profile);
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      Navigator.maybePop(context);
    }
  }

  void _applyProfile(UserProfile profile) {
    _profile = profile;
    _name = profile.name;
    _username = profile.username;
    _email = profile.email ?? '';
    _mobile = profile.mobile ?? '';
    _bio = profile.bio ?? '';
  }

  Map<String, dynamic> _buildPayload({String? profilePicture}) {
    final profile = _profile!;
    return {
      'name': _name.trim(),
      'username': _username.trim().toLowerCase().replaceAll(' ', ''),
      'email': _email.trim(),
      'mobile': _mobile.trim(),
      'bio': _bio.trim(),
      'profilePicture': profilePicture ?? profile.profilePicture ?? '',
    };
  }

  Future<void> _pickImage() async {
    final profile = _profile;
    if (profile == null || _uploadingPhoto) return;

    final cropped = await pickAndCropProfileImage();
    if (cropped == null || !mounted) return;

    setState(() {
      _localImage = cropped;
      _uploadingPhoto = true;
    });

    final api = PlaySession.apiOf(context);
    final profileId = profile.id.isNotEmpty ? profile.id : (profile.userid ?? '');
    if (profileId.isEmpty) {
      if (mounted) {
        setState(() {
          _localImage = null;
          _uploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile id missing. Please reopen edit profile.')),
        );
      }
      return;
    }

    try {
      final picUrl = await api.uploadProfilePicture(profileId, cropped);
      await api.updateUserProfile(profileId, _buildPayload(profilePicture: picUrl));
      if (!mounted) return;
      setState(() {
        _localImage = null;
        _uploadingPhoto = false;
        _profile = UserProfile(
          id: profile.id,
          userid: profile.userid,
          username: profile.username,
          name: profile.name,
          email: profile.email,
          mobile: profile.mobile,
          bio: profile.bio,
          profilePicture: picUrl,
          postCount: profile.postCount,
          followersCount: profile.followersCount,
          followingCount: profile.followingCount,
          followers: profile.followers,
          following: profile.following,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
        setState(() {
          _localImage = null;
          _uploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _removeImage() async {
    final profile = _profile;
    if (profile == null) return;
    final profileId = profile.id.isNotEmpty ? profile.id : (profile.userid ?? '');
    if (profileId.isEmpty) return;
    final api = PlaySession.apiOf(context);
    try {
      await api.removeProfilePicture(profileId);
      if (mounted) {
        setState(() {
          _localImage = null;
          _profile = UserProfile(
            id: profile.id,
            userid: profile.userid,
            username: profile.username,
            name: profile.name,
            email: profile.email,
            mobile: profile.mobile,
            bio: profile.bio,
            profilePicture: null,
            postCount: profile.postCount,
            followersCount: profile.followersCount,
            followingCount: profile.followingCount,
            followers: profile.followers,
            following: profile.following,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _openField(ProfileEditField field) async {
    final profile = _profile;
    if (profile == null) return;

    final api = PlaySession.apiOf(context);
    final launchContext = PlaySession.launchContextOf(context);

    if (field == ProfileEditField.mobile) {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => PlaySession(
            api: api,
            launchContext: launchContext,
            child: EditMobileScreen(
              currentMobile: _mobile,
              profileId: profile.id,
              profilePayload: _buildPayload(),
            ),
          ),
        ),
      );
      if (result == null || !mounted) return;
      setState(() {
        _mobile = result;
        _profile = UserProfile(
          id: profile.id,
          userid: profile.userid,
          username: _username,
          name: _name,
          email: _email,
          mobile: _mobile,
          bio: _bio,
          profilePicture: profile.profilePicture,
          postCount: profile.postCount,
          followersCount: profile.followersCount,
          followingCount: profile.followingCount,
          followers: profile.followers,
          following: profile.following,
        );
      });
      return;
    }

    final initial = switch (field) {
      ProfileEditField.name => _name,
      ProfileEditField.username => _username,
      ProfileEditField.email => _email,
      ProfileEditField.mobile => _mobile,
      ProfileEditField.bio => _bio,
    };

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaySession(
          api: api,
          launchContext: launchContext,
          child: EditProfileFieldScreen(
            field: field,
            initialValue: initial,
            profileId: profile.id,
            profilePayload: _buildPayload(),
          ),
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      switch (field) {
        case ProfileEditField.name:
          _name = result;
        case ProfileEditField.username:
          _username = result;
        case ProfileEditField.email:
          _email = result;
        case ProfileEditField.mobile:
          _mobile = result;
        case ProfileEditField.bio:
          _bio = result;
      }
      _profile = UserProfile(
        id: profile.id,
        userid: profile.userid,
        username: _username,
        name: _name,
        email: _email,
        mobile: _mobile,
        bio: _bio,
        profilePicture: profile.profilePicture,
        postCount: profile.postCount,
        followersCount: profile.followersCount,
        followingCount: profile.followingCount,
        followers: profile.followers,
        following: profile.following,
      );
    });
  }

  ImageProvider? get _avatarImage {
    if (_localImage != null) return FileImage(_localImage!);
    final pic = _profile?.profilePicture;
    if (pic != null && pic.isNotEmpty) return NetworkImage(pic);
    return null;
  }

  String _displayValue(String value, {required String placeholder}) {
    final v = value.trim();
    return v.isEmpty ? placeholder : v;
  }

  String get _displayName {
    final n = _name.trim();
    if (n.isNotEmpty) {
      return n.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
    }
    return _username.isNotEmpty ? _username : 'User';
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: _loading
          ? const EditProfileSkeleton()
          : Column(
              children: [
                _buildHeader(topPad),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: _buildFormCard(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader(double topPad) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFfb5204), Color(0xFFFFB347)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, topPad + 6, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _circleIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.maybePop(context),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
                GestureDetector(
                  onTap: _uploadingPhoto ? null : _pickImage,
                  onLongPress: _uploadingPhoto
                      ? null
                      : ((_profile?.profilePicture != null && _profile!.profilePicture!.isNotEmpty) ||
                              _localImage != null
                          ? _removeImage
                          : null),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                        child: CircleAvatar(
                          radius: 34,
                          backgroundColor: Colors.white,
                          backgroundImage: _avatarImage,
                          child: _avatarImage == null
                              ? Icon(Icons.person_rounded, size: 34, color: Colors.grey.shade500)
                              : null,
                        ),
                      ),
                      if (_uploadingPhoto)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: ProfileColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _username.isNotEmpty ? _username : 'username',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleIconButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white.withValues(alpha: 0.22),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: ProfileColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_outline_rounded, color: ProfileColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile Information',
                      style: TextStyle(
                        color: ProfileColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Update your personal details',
                      style: TextStyle(color: ProfileColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _fieldRow(
            icon: Icons.badge_outlined,
            label: 'Name',
            value: _displayValue(_name, placeholder: 'Add your name'),
            onTap: () => _openField(ProfileEditField.name),
          ),
          _divider(),
          _fieldRow(
            icon: Icons.alternate_email_rounded,
            label: 'Username',
            value: _displayValue(_username, placeholder: 'Add username'),
            onTap: () => _openField(ProfileEditField.username),
          ),
          _divider(),
          _fieldRow(
            icon: Icons.email_outlined,
            label: 'Email Address',
            value: _displayValue(_email, placeholder: 'Add email'),
            onTap: () => _openField(ProfileEditField.email),
          ),
          _divider(),
          _fieldRow(
            icon: Icons.phone_outlined,
            label: 'Mobile Number',
            value: _displayValue(_mobile, placeholder: 'Add mobile number'),
            onTap: () => _openField(ProfileEditField.mobile),
          ),
          _divider(),
          _fieldRow(
            icon: Icons.edit_note_rounded,
            label: 'Bio',
            value: _displayValue(_bio, placeholder: 'Tell something about yourself'),
            onTap: () => _openField(ProfileEditField.bio),
            multiline: true,
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Divider(height: 1, color: ProfileColors.divider),
      );

  Widget _fieldRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    bool multiline = false,
  }) {
    final isPlaceholder = value == 'Add your name' ||
        value == 'Add username' ||
        value == 'Add email' ||
        value == 'Add mobile number' ||
        value == 'Tell something about yourself';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            crossAxisAlignment: multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ProfileColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: ProfileColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(color: ProfileColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: TextStyle(
                        color: isPlaceholder ? ProfileColors.textHint : ProfileColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: multiline ? 1.35 : 1.2,
                      ),
                      maxLines: multiline ? 3 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
