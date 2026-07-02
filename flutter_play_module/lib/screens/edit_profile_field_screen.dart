import 'package:flutter/material.dart';

import '../utils/play_session.dart';
import '../utils/profile_theme.dart';

enum ProfileEditField { name, username, email, mobile, bio }

class EditProfileFieldScreen extends StatefulWidget {
  const EditProfileFieldScreen({
    super.key,
    required this.field,
    required this.initialValue,
    required this.profileId,
    required this.profilePayload,
  });

  final ProfileEditField field;
  final String initialValue;
  final String profileId;
  final Map<String, dynamic> profilePayload;

  @override
  State<EditProfileFieldScreen> createState() => _EditProfileFieldScreenState();
}

class _EditProfileFieldScreenState extends State<EditProfileFieldScreen> {
  late final TextEditingController _ctrl;
  String? _error;
  bool _saving = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
    _ctrl.addListener(() {
      final changed = _normalizedValue(_ctrl.text) != _normalizedValue(widget.initialValue);
      if (changed != _changed) setState(() => _changed = changed);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _title => switch (widget.field) {
        ProfileEditField.name => 'Name',
        ProfileEditField.username => 'Username',
        ProfileEditField.email => 'Email',
        ProfileEditField.mobile => 'Mobile',
        ProfileEditField.bio => 'Bio',
      };

  String get _payloadKey => switch (widget.field) {
        ProfileEditField.name => 'name',
        ProfileEditField.username => 'username',
        ProfileEditField.email => 'email',
        ProfileEditField.mobile => 'mobile',
        ProfileEditField.bio => 'bio',
      };

  TextInputType get _keyboard => switch (widget.field) {
        ProfileEditField.email => TextInputType.emailAddress,
        ProfileEditField.mobile => TextInputType.phone,
        ProfileEditField.bio => TextInputType.multiline,
        _ => TextInputType.text,
      };

  int? get _maxLength => switch (widget.field) {
        ProfileEditField.mobile => 10,
        ProfileEditField.bio => 150,
        ProfileEditField.username => 30,
        _ => null,
      };

  int get _maxLines => widget.field == ProfileEditField.bio ? 5 : 1;

  String? _validate(String value) {
    final trimmed = value.trim();
    switch (widget.field) {
      case ProfileEditField.name:
        if (trimmed.isEmpty) return 'Name is required';
      case ProfileEditField.username:
        final u = trimmed.toLowerCase().replaceAll(' ', '');
        if (!RegExp(r'^[a-z0-9_]+$').hasMatch(u)) {
          return 'Only letters, numbers, and underscores allowed';
        }
      case ProfileEditField.email:
        if (!RegExp(r'^[a-zA-Z0-9._+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$').hasMatch(trimmed)) {
          return 'Please enter a valid email address';
        }
      case ProfileEditField.mobile:
        if (!RegExp(r'^[6-9]\d{9}$').hasMatch(trimmed)) {
          return 'Please enter a valid 10-digit mobile number';
        }
      case ProfileEditField.bio:
        break;
    }
    return null;
  }

  String _normalizedValue(String value) {
    final trimmed = value.trim();
    if (widget.field == ProfileEditField.username) {
      return trimmed.toLowerCase().replaceAll(' ', '');
    }
    return trimmed;
  }

  Future<void> _save() async {
    final err = _validate(_ctrl.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    final value = _normalizedValue(_ctrl.text);
    if (value == widget.initialValue) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = PlaySession.apiOf(context);
    final payload = Map<String, dynamic>.from(widget.profilePayload);
    payload[_payloadKey] = value;

    try {
      await api.updateUserProfile(widget.profileId, payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 1),
        ),
      );
      Navigator.pop(context, value);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = msg.toLowerCase().contains('already taken')
            ? 'This username is already taken. Please try another.'
            : msg;
      });
    }
  }

  List<Widget> _helperLines() {
    switch (widget.field) {
      case ProfileEditField.name:
        return [
          _helperText(
            "Help people discover your account by using the name you're known by: "
            'either your full name, nickname, or business name.',
          ),
          const SizedBox(height: 12),
          _helperText('Your name is visible to everyone on the platform.'),
        ];
      case ProfileEditField.username:
        return [
          _helperText(
            'Usernames can contain letters, numbers, and underscores. '
            'Choose something unique that represents you.',
          ),
          const SizedBox(height: 12),
          _helperText('Your username appears on your profile and in mentions.'),
        ];
      case ProfileEditField.email:
        return [
          _helperText(
            'Add an email address to your account. It can be used to recover your account.',
          ),
        ];
      case ProfileEditField.mobile:
        return [
          _helperText(
            'Enter your 10-digit Indian mobile number starting with 6, 7, 8, or 9.',
          ),
        ];
      case ProfileEditField.bio:
        return [
          _helperText(
            'Write a short bio to tell people more about yourself. '
            'You can include interests, location, or anything else.',
          ),
          const SizedBox(height: 12),
          _helperText('${_ctrl.text.length}/150 characters'),
        ];
    }
  }

  Widget _helperText(String text) {
    return Text(
      text,
      style: const TextStyle(color: ProfileColors.textMuted, fontSize: 13, height: 1.45),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canTapSave = !_saving;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: ProfileColors.textPrimary, size: 26),
            onPressed: _saving ? null : () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            _title,
            style: const TextStyle(
              color: ProfileColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            IconButton(
              onPressed: canTapSave ? _save : null,
              icon: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: ProfileColors.primary),
                    )
                  : Icon(
                      Icons.check_rounded,
                      size: 28,
                      color: _changed ? const Color(0xFF0095F6) : ProfileColors.textHint,
                    ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _ctrl,
                autofocus: true,
                keyboardType: _keyboard,
                maxLines: _maxLines,
                maxLength: _maxLength,
                autocorrect: widget.field != ProfileEditField.username,
                style: const TextStyle(
                  color: ProfileColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                cursorColor: ProfileColors.primary,
                decoration: InputDecoration(
                  labelText: _title,
                  labelStyle: const TextStyle(color: ProfileColors.textMuted, fontSize: 13),
                  floatingLabelStyle: const TextStyle(color: ProfileColors.textSecondary, fontSize: 13),
                  counterText: widget.field == ProfileEditField.bio ? null : '',
                  errorText: _error,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _error != null ? Colors.red : ProfileColors.textPrimary, width: 1.2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _error != null ? Colors.red : ProfileColors.textPrimary, width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _error != null ? Colors.red : ProfileColors.textPrimary, width: 1.4),
                  ),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                  if (widget.field == ProfileEditField.bio) setState(() {});
                },
              ),
              const SizedBox(height: 16),
              ..._helperLines(),
            ],
          ),
        ),
    );
  }
}
