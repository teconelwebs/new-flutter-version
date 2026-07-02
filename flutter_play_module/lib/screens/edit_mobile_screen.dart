import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_api.dart';
import '../utils/play_session.dart';
import '../utils/profile_theme.dart';

class EditMobileScreen extends StatefulWidget {
  const EditMobileScreen({
    super.key,
    required this.currentMobile,
    required this.profileId,
    required this.profilePayload,
  });

  final String currentMobile;
  final String profileId;
  final Map<String, dynamic> profilePayload;

  @override
  State<EditMobileScreen> createState() => _EditMobileScreenState();
}

class _EditMobileScreenState extends State<EditMobileScreen> {
  final _newPhoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPhoneFocus = FocusNode();
  final _otpFocus = FocusNode();

  bool _changing = false;
  bool _otpSent = false;
  bool _sendingOtp = false;
  bool _verifying = false;
  String? _error;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  late final String _currentDigits;
  late AuthApi _authApi;
  bool _authReady = false;

  @override
  void initState() {
    super.initState();
    _currentDigits = normalizeIndianMobile(widget.currentMobile);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_authReady) {
      _authApi = AuthApi(deviceId: PlaySession.apiOf(context).deviceId);
      _authReady = true;
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _newPhoneCtrl.dispose();
    _otpCtrl.dispose();
    _newPhoneFocus.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  String get _newDigits => normalizeIndianMobile(_newPhoneCtrl.text);

  void _beginChange() {
    setState(() {
      _changing = true;
      _otpSent = false;
      _error = null;
      _otpCtrl.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _newPhoneFocus.requestFocus();
    });
  }

  void _resetChangeFlow() {
    _resendTimer?.cancel();
    setState(() {
      _changing = false;
      _otpSent = false;
      _sendingOtp = false;
      _verifying = false;
      _resendSeconds = 0;
      _error = null;
      _newPhoneCtrl.clear();
      _otpCtrl.clear();
    });
  }

  Future<void> _sendOtp() async {
    if (_sendingOtp) return;

    final newPhone = _newDigits;
    if (!isValidIndianMobile(newPhone)) {
      setState(() => _error = 'Please enter a valid 10-digit mobile number.');
      return;
    }
    if (newPhone == _currentDigits) {
      setState(() => _error = 'New number must be different from your current number.');
      return;
    }

    setState(() {
      _sendingOtp = true;
      _error = null;
    });

    try {
      final result = await _authApi.sendOtp(newPhone);
      if (!mounted) return;
      if (!result.success) {
        setState(() {
          _sendingOtp = false;
          _error = result.message ?? 'Failed to send OTP.';
        });
        return;
      }
      setState(() {
        _sendingOtp = false;
        _otpSent = true;
      });
      _startResendTimer();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _otpFocus.requestFocus();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sendingOtp = false;
        _error = 'Unable to send OTP. Please try again.';
      });
    }
  }

  Future<void> _verifyAndSave() async {
    if (_verifying) return;

    final newPhone = _newDigits;
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Please enter the 6-digit OTP.');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final verified = await _authApi.verifyOtp(newPhone, otp);
      if (!mounted) return;
      if (!verified) {
        setState(() {
          _verifying = false;
          _error = 'Invalid OTP. Please try again.';
        });
        return;
      }

      final api = PlaySession.apiOf(context);
      final payload = Map<String, dynamic>.from(widget.profilePayload);
      payload['mobile'] = newPhone;
      await api.updateUserProfile(widget.profileId, payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mobile number updated'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, newPhone);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Widget _currentNumberCard() {
    final display = _currentDigits.length == 10
        ? formatMobileDisplay(_currentDigits)
        : (widget.currentMobile.trim().isEmpty ? 'Not added' : widget.currentMobile.trim());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current mobile number',
            style: TextStyle(color: ProfileColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            display,
            style: const TextStyle(
              color: ProfileColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _phonePrefixField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required bool enabled,
    VoidCallback? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      maxLength: 10,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(color: ProfileColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
      cursorColor: ProfileColors.primary,
      onSubmitted: enabled ? (_) => onSubmitted?.call() : null,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        prefixText: '+91 ',
        prefixStyle: const TextStyle(
          color: ProfileColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        errorText: _error,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _error != null ? Colors.red : ProfileColors.textPrimary, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _error != null ? Colors.red : const Color(0xFFE5E7EB), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _error != null ? Colors.red : ProfileColors.primary, width: 1.4),
        ),
      ),
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
    required bool loading,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: ProfileColors.primary,
          disabledBackgroundColor: ProfileColors.primary.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _sendingOtp || _verifying;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: ProfileColors.textPrimary, size: 26),
          onPressed: busy ? null : () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Mobile Number',
          style: TextStyle(color: ProfileColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _currentNumberCard(),
            const SizedBox(height: 20),
            if (!_changing) ...[
              const Text(
                'Your mobile number is used for account verification and recovery.',
                style: TextStyle(color: ProfileColors.textMuted, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 20),
              _primaryButton(label: 'Change Number', onPressed: _beginChange, loading: false),
            ] else if (!_otpSent) ...[
              const Text(
                'Enter your new mobile number. We will send an OTP to verify it.',
                style: TextStyle(color: ProfileColors.textMuted, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 16),
              _phonePrefixField(
                controller: _newPhoneCtrl,
                focusNode: _newPhoneFocus,
                label: 'New mobile number',
                enabled: !_sendingOtp,
                onSubmitted: _sendOtp,
              ),
              const SizedBox(height: 16),
              _primaryButton(label: 'Send OTP', onPressed: _sendOtp, loading: _sendingOtp),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _sendingOtp ? null : _resetChangeFlow,
                  child: const Text('Cancel', style: TextStyle(color: ProfileColors.textSecondary)),
                ),
              ),
            ] else ...[
              Text(
                'OTP sent to ${formatMobileDisplay(_newDigits)}',
                style: const TextStyle(color: ProfileColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _otpCtrl,
                focusNode: _otpFocus,
                enabled: !_verifying,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  color: ProfileColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 6,
                ),
                cursorColor: ProfileColors.primary,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'Enter OTP',
                  counterText: '',
                  errorText: _error,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _error != null ? Colors.red : ProfileColors.textPrimary, width: 1.2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _error != null ? Colors.red : const Color(0xFFE5E7EB), width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _error != null ? Colors.red : ProfileColors.primary, width: 1.4),
                  ),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _verifyAndSave(),
              ),
              const SizedBox(height: 16),
              _primaryButton(label: 'Verify & Update', onPressed: _verifyAndSave, loading: _verifying),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: (_resendSeconds > 0 || _sendingOtp) ? null : _sendOtp,
                    child: Text(
                      _resendSeconds > 0 ? 'Resend OTP in ${_resendSeconds}s' : 'Resend OTP',
                      style: TextStyle(
                        color: _resendSeconds > 0 ? ProfileColors.textHint : ProfileColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _verifying ? null : _resetChangeFlow,
                    child: const Text(
                      'Change number',
                      style: TextStyle(color: ProfileColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
