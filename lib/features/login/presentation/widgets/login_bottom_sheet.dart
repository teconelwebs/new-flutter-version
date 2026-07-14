import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/utils/safe_insets.dart';
import '../../data/login_service.dart';

class LoginBottomSheet extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginBottomSheet({
    super.key,
    required this.onLoginSuccess,
  });

  @override
  State<LoginBottomSheet> createState() => _LoginBottomSheetState();
}

class _LoginBottomSheetState extends State<LoginBottomSheet> {
  final _loginService = LoginService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();

  bool _otpSent = false;
  bool _loading = false;
  int _resendTimer = 0;
  Timer? _timer;
  String? _errorText;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _resendTimer = 30;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() {
          _resendTimer--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10 || int.tryParse(phone) == null) {
      setState(() {
        _errorText = "Please enter a valid 10-digit mobile number.";
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });
    FocusScope.of(context).unfocus();

    try {
      final result = await _loginService.sendOtp(phone);
      if (!mounted) return;

      if (result.errorMessage != null) {
        setState(() {
          _errorText = result.errorMessage;
          _loading = false;
        });
        return;
      }

      setState(() {
        _otpSent = true;
        _resendTimer = 30;
        _loading = false;
      });
      _startTimer();
      
      // Auto-focus OTP field
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          _otpFocusNode.requestFocus();
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorText = "Unable to send OTP. Please try again.";
          _loading = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() {
        _errorText = "Please enter a valid 6-digit OTP.";
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final result = await _loginService.verifyOtp(phoneNumber: phone, otp: otp);
      if (!mounted) return;

      if (result.errorMessage != null) {
        setState(() {
          _errorText = result.errorMessage;
          _loading = false;
        });
        return;
      }

      await SessionStore.saveLogin(
        accessToken: result.accessToken,
        userId: result.userId,
        userName: result.userName,
        mobile: phone,
        account: result.account,
        postLoginCheck: result.account == 'register',
      );

      if (mounted) {
        // Close bottom sheet and trigger success callback
        Navigator.of(context).pop();
        widget.onLoginSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = "Verification failed. Please try again.";
          _loading = false;
        });
      }
    }
  }

  void _resetForm() {
    setState(() {
      _otpController.clear();
      _phoneController.clear();
      _otpSent = false;
      _resendTimer = 0;
      _errorText = null;
      _timer?.cancel();
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _phoneFocusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 14,
        bottom: systemBottomInset(context) +
            (bottomInset > 0 ? bottomInset + 16 : 24.0),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle Bar
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: Colors.black.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Header Content
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Welcome to ",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const Text(
                  "Welfog",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFB5404),
                  ),
                ),
                const SizedBox(width: 6),
                Image.asset(
                  "assets/icons/login/icon1.png",
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "Login to watch video and Play",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 24),

            // Text field / Content
            if (!_otpSent) ...[
              // Phone Input Field
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE9E9E9)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        border: Border(right: BorderSide(color: Color(0xFFEFEFEF))),
                      ),
                      child: const Text(
                        "+91",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.call_outlined, color: Color(0xFF9AA0A6), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                focusNode: _phoneFocusNode,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                                decoration: const InputDecoration(
                                  hintText: "Enter mobile number",
                                  hintStyle: TextStyle(color: Color(0xFFA9A9A9)),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  counterText: "",
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onSubmitted: (_) => _sendOtp(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Button to Send OTP
              _buildPrimaryButton(
                text: _loading ? "Sending OTP..." : "Send OTP",
                onPressed: _loading ? null : _sendOtp,
              ),
            ] else ...[
              // OTP Input View
              Text(
                "Enter OTP sent to +91 ${_phoneController.text}",
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF374151),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE9E9E9)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.key_outlined, color: Color(0xFF9AA0A6), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _otpController,
                        focusNode: _otpFocusNode,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          letterSpacing: 1.5,
                        ),
                        decoration: const InputDecoration(
                          hintText: "Enter 6-digit OTP",
                          hintStyle: TextStyle(color: Color(0xFFA0A0A0), letterSpacing: 0),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          counterText: "",
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (_) => _verifyOtp(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Button to Verify OTP
              _buildPrimaryButton(
                text: _loading ? "Verifying..." : "Verify OTP",
                onPressed: _loading ? null : _verifyOtp,
              ),
              const SizedBox(height: 16),

              // Resend & Change options
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _resendTimer > 0 ? null : _sendOtp,
                    child: Text(
                      _resendTimer > 0 ? "Resend OTP in ${_resendTimer}s" : "Resend OTP",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _resendTimer > 0 ? const Color(0xFF9CA3AF) : const Color(0xFFFB5404),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _resetForm,
                    child: const Text(
                      "Change Number",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFB5404),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Display error messages elegantly below input/buttons
            if (_errorText != null) ...[
              const SizedBox(height: 14),
              Text(
                _errorText!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            const SizedBox(height: 20),
            
            // Inline Terms & Policy Links
            Center(
              child: Text.rich(
                TextSpan(
                  text: "By continuing, you agree to our ",
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.4),
                  children: [
                    TextSpan(
                      text: "Terms & Conditions",
                      style: const TextStyle(color: Color(0xFFFB5404), fontWeight: FontWeight.bold),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.policy,
                            arguments: 'terms-and-conditions',
                          );
                        },
                    ),
                    const TextSpan(text: ", "),
                    TextSpan(
                      text: "Privacy Policy",
                      style: const TextStyle(color: Color(0xFFFB5404), fontWeight: FontWeight.bold),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.policy,
                            arguments: 'privacy-policy',
                          );
                        },
                    ),
                    const TextSpan(text: ", and "),
                    TextSpan(
                      text: "Anti-Phishing",
                      style: const TextStyle(color: Color(0xFFFB5404), fontWeight: FontWeight.bold),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.policy,
                            arguments: 'anti-phishing-defense-policy',
                          );
                        },
                    ),
                    const TextSpan(text: "."),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({required String text, required VoidCallback? onPressed}) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFFB5404),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: const Color(0xFFFB5404).withOpacity(0.24),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
