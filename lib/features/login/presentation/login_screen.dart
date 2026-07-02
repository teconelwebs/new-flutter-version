import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/storage/session_store.dart';
import '../../home/presentation/home_screen.dart';
import '../data/login_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const routeName = AppRoutes.login;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginService = LoginService();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;
  int _resendTimer = 0;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    Navigator.of(context).pushReplacementNamed(HomeScreen.routeName);
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 10 || int.tryParse(phone) == null) {
      _showMessage('Enter a valid 10-digit mobile number.');
      return;
    }

    setState(() => _loading = true);
    try {
      final error = await _loginService.sendOtp(phone);
      if (!mounted) return;
      if (error != null) {
        _showMessage(error);
        return;
      }
      setState(() {
        _otpSent = true;
        _resendTimer = 30;
      });
      _startResendCountdown();
      _showMessage('OTP sent to +91 $phone');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to send OTP. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    final phone = _phoneCtrl.text.trim();
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      _showMessage('Enter valid 6-digit OTP.');
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await _loginService.verifyOtp(phoneNumber: phone, otp: otp);
      if (!mounted) return;
      if (result.errorMessage != null) {
        _showMessage(result.errorMessage!);
        return;
      }
      await SessionStore.saveLogin(
        accessToken: result.accessToken,
        userId: result.userId,
        userName: result.userName,
        mobile: phone,
      );
      await _continue();
    } catch (_) {
      if (!mounted) return;
      _showMessage('Verification failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _startResendCountdown() {
    Future.doWhile(() async {
      if (!mounted || _resendTimer <= 0) return false;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendTimer -= 1);
      return _resendTimer > 0;
    });
  }

  void _resetToPhoneStep() {
    setState(() {
      _otpSent = false;
      _otpCtrl.clear();
      _resendTimer = 0;
    });
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0A6B69);
    const accentTeal = Color(0xFF2A8C7A);
    const buttonStart = Color(0xFFFFA63A);
    const buttonEnd = Color(0xFFF26A1A);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _continue,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Center(
                child: Icon(
                  Icons.storefront_rounded,
                  size: 64,
                  color: teal,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Welcome to Welfog',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _otpSent
                    ? 'Enter OTP sent to +91 ${_phoneCtrl.text}'
                    : 'Shop More, Save More',
                style: const TextStyle(color: Color(0xFF6E7380)),
              ),
              const SizedBox(height: 28),
              if (!_otpSent) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE9E9E9)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '+91',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: const InputDecoration(
                          labelText: 'Enter mobile number',
                          counterText: '',
                          prefixIcon: Icon(Icons.call_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  height: 2,
                  color: accentTeal.withValues(alpha: 0.45),
                ),
                const SizedBox(height: 18),
                InkWell(
                  onTap: _loading ? null : _sendOtp,
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: _loading
                            ? const [Color(0xFFC9C9C9), Color(0xFFBDBDBD)]
                            : const [buttonStart, buttonEnd],
                      ),
                    ),
                    child: Row(
                      children: [
                        const Spacer(),
                        Text(
                          _loading ? 'Sending OTP...' : 'Send OTP',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            size: 18,
                            color: Color(0xFFF26A1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Enter 6-digit OTP',
                    counterText: '',
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _loading ? null : _verifyOtp,
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: _loading
                            ? const [Color(0xFFC9C9C9), Color(0xFFBDBDBD)]
                            : const [buttonStart, buttonEnd],
                      ),
                    ),
                    child: Row(
                      children: [
                        const Spacer(),
                        Text(
                          _loading ? 'Verifying...' : 'Verify OTP',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 18,
                            color: Color(0xFFF26A1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _resendTimer > 0 || _loading ? null : _sendOtp,
                      child: Text(
                        _resendTimer > 0
                            ? 'Resend in ${_resendTimer}s'
                            : 'Resend OTP',
                      ),
                    ),
                    TextButton(
                      onPressed: _loading ? null : _resetToPhoneStep,
                      child: const Text('Change number'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
