import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/storage/session_store.dart';
import '../../home/presentation/home_screen.dart';
import '../data/login_service.dart';
import '../../../core/services/check_app_update.dart';

class LoginScreen extends StatefulWidget {
  // ignore: use_super_parameters
  const LoginScreen({Key? key}) : super(key: key);
  static const routeName = AppRoutes.login;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _loginService = LoginService();

  // Input Controllers & Nodes
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();

  // Local State
  bool _otpSent = false;
  bool _loading = false;
  bool _acceptedTerms = false;
  int _resendTimer = 0;
  Timer? _timer;

  // Custom Top Toast Animation & State
  String? _toastTitle;
  String? _toastMessage;
  bool _toastIsError = false;
  bool _showToastWidget = false;
  late AnimationController _toastAnimController;
  late Animation<double> _toastSlideAnimation;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();

    _phoneFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _otpFocusNode.addListener(() {
      if (mounted) setState(() {});
    });

    // Custom Top Toast Setup
    _toastAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _toastSlideAnimation = Tween<double>(begin: -150.0, end: 0.0).animate(
      CurvedAnimation(parent: _toastAnimController, curve: Curves.easeOutBack),
    );

    // Trigger app update check after a small delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        checkAppUpdate(context);
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    _timer?.cancel();
    _toastAnimController.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }

  // Resend OTP Countdown Timer
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

  // Generates Temporary ID mimicking Javascript logic
  // ignore: unused_element
  String _generateTempId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomNum = Random().nextInt(1000000);
    return "TEMP_${timestamp}_$randomNum";
  }

  Future<void> _continue() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(HomeScreen.routeName);
  }

  // Guest Mode Transition
  Future<void> _handleGuestMode() async {
    await _continue();
  }

  // Send OTP Validation and Call
  Future<void> _sendOtp() async {
    if (!_acceptedTerms) {
      _showToast(
        title: "Terms & Conditions",
        message: "Please accept the Terms & Conditions to proceed.",
        isError: true,
      );
      return;
    }
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showToast(
        title: "Phone Number Required",
        message: "Please enter your mobile number.",
        isError: true,
      );
      return;
    }
    if (phone.length != 10 || int.tryParse(phone) == null) {
      _showToast(
        title: "Invalid Phone Number",
        message: "Please enter a valid 10-digit mobile number.",
        isError: true,
      );
      return;
    }

    setState(() {
      _loading = true;
    });
    FocusScope.of(context).unfocus(); // Keyboard hide logic

    try {
      final result = await _loginService.sendOtp(phone);
      if (!mounted) return;
      if (result.accountStatus == 'deleted') {
        setState(() {
          _loading = false;
        });
        Navigator.of(context).pushNamed(
          AppRoutes.accountDeleted,
          arguments: {
            'phone': phone,
            'deleted_date': result.deletedDate ?? '',
          },
        );
        return;
      }
      if (result.errorMessage != null) {
        setState(() {
          _loading = false;
        });
        _showToast(
          title: "Failed to send OTP",
          message: result.errorMessage!,
          isError: true,
        );
        return;
      }
      setState(() {
        _otpSent = true;
        _resendTimer = 30;
      });
      _startTimer();
      Future.delayed(const Duration(milliseconds: 150), () {
        _otpFocusNode.requestFocus();
      });
      _showToast(
        title: "OTP Sent",
        message: "OTP sent to +91 $phone",
        isError: false,
      );
    } catch (_) {
      if (!mounted) return;
      _showToast(
        title: "Failed to send OTP",
        message: "Unable to send OTP. Please try again.",
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // Verify OTP Logic
  Future<void> _verifyOtp() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showToast(
        title: "Invalid OTP",
        message: "Please enter a valid 6-digit OTP.",
        isError: true,
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final result = await _loginService.verifyOtp(phoneNumber: phone, otp: otp);
      if (!mounted) return;
      if (result.errorMessage != null) {
        _showToast(
          title: "Login Failed",
          message: result.errorMessage!,
          isError: true,
        );
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
      await _continue();
    } catch (error) {
      if (!mounted) return;
      _showToast(
        title: "Login Failed",
        message: "Verification Error",
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // Reset form status
  void _resetForm() {
    setState(() {
      _otpController.clear();
      _phoneController.clear();
      _otpSent = false;
      _resendTimer = 0;
      _timer?.cancel();
    });
  }

  // Custom Top Toast using Animation Overlay inside Scaffold Stack
  void _showToast({required String title, required String message, bool isError = false}) {
    _toastTimer?.cancel();
    setState(() {
      _toastTitle = title;
      _toastMessage = message;
      _toastIsError = isError;
      _showToastWidget = true;
    });
    _toastAnimController.forward(from: 0.0);

    _toastTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        _toastAnimController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _showToastWidget = false;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final insets = mediaQuery.padding;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // Scrollable login body
            Positioned.fill(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Orange Header
                    _buildHeader(insets),
                    
                    // White Form Card container
                    _buildFormCard(context),
                  ],
                ),
              ),
            ),
            
            // Floating Skip button overlay (Positioned top-right)
            Positioned(
              top: insets.top + 16,
              right: 20,
              child: GestureDetector(
                onTap: _handleGuestMode,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      // ignore: deprecated_member_use
                      color: Colors.white.withOpacity(0.35),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Skip",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Top custom toast popup
            if (_showToastWidget)
              _buildToastNotification(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(EdgeInsets insets) {
    final bool isFocused = _phoneFocusNode.hasFocus || _otpFocusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFB5404), Color(0xFFFF7E40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles to match design
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // ignore: deprecated_member_use
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // ignore: deprecated_member_use
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          AnimatedPadding(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: EdgeInsets.fromLTRB(
              24,
              isFocused ? insets.top + 16 : insets.top + 34,
              24,
              isFocused ? 28 : 44,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  style: TextStyle(
                    fontSize: isFocused ? 18 : 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.25,
                  ),
                  child: const Text(
                    "Shop deals. Watch Play.\nAll in one app.",
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      const Text(
                        "Login to shop products, scroll short videos on Play, track orders, and checkout faster.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildHeaderTag("Shop & deals"),
                          _buildHeaderTag("Scroll Play"),
                          _buildHeaderTag("Safe checkout"),
                        ],
                      ),
                    ],
                  ),
                  secondChild: const SizedBox.shrink(),
                  crossFadeState: isFocused ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 350),
                ),
              ],
            ),
          ),
          // Bottom overlap rounded cut Container to safely replace negative margin
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          // ignore: deprecated_member_use
          color: Colors.white.withOpacity(0.12),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2EB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFB5404),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _otpSent ? "STEP 2 OF 2" : "STEP 1 OF 2",
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFB5404),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushNamed(AppRoutes.contactSupport);
                },
                child: const Text(
                  "Need help?",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFB5404),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: 3,
                  decoration: BoxDecoration(
                    color: _otpSent ? const Color(0xFFFB5404) : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _otpSent ? _buildOtpForm() : _buildMobileForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileForm() {
    return Column(
      key: const ValueKey('mobile_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Enter mobile number",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "We will send a one-time verification code to continue your login securely.",
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        Focus(
          onFocusChange: (hasFocus) {
            setState(() {});
          },
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              TextField(
                controller: _phoneController,
                focusNode: _phoneFocusNode,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                  letterSpacing: 0.5,
                ),
                decoration: InputDecoration(
                  labelText: "Enter mobile number",
                  labelStyle: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                  floatingLabelStyle: const TextStyle(
                    color: Color(0xFFFB5404),
                    fontWeight: FontWeight.bold,
                  ),
                  alignLabelWithHint: true,
                  contentPadding: const EdgeInsets.only(left: 74, right: 16, top: 18, bottom: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFFFB5404), width: 1.5),
                  ),
                  counterText: "",
                ),
                onSubmitted: (_) => _sendOtp(),
              ),
              Positioned(
                left: 18,
                child: IgnorePointer(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "+91",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 1,
                        height: 22,
                        color: const Color(0xFFD1D5DB),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Icon(Icons.check_circle, size: 16, color: Color(0xFFFB5404)),
            SizedBox(width: 8),
            Text(
              "6-digit OTP will be sent instantly",
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFFB5404),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildResponsiveButton(
          text: _loading ? "Loading..." : "Next",
          onPressed: _loading ? null : _sendOtp,
        ),
        const SizedBox(height: 18),
        _buildTermsCheckbox(),
      ],
    );
  }

  Widget _buildOtpForm() {
    final String timerText = "00:${_resendTimer.toString().padLeft(2, '0')}";
    final String rawPhone = _phoneController.text.trim();
    final String maskedPhone;
    if (rawPhone.length >= 10) {
      maskedPhone = "+91 ${rawPhone.substring(0, 3)}XXXX${rawPhone.substring(7)}";
    } else {
      maskedPhone = "+91 $rawPhone";
    }

    return Column(
      key: const ValueKey('otp_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Enter OTP",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Enter the one-time verification code to continue your login securely.",
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "OTP sent to $maskedPhone",
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF4B5563),
                fontWeight: FontWeight.w600,
              ),
            ),
            GestureDetector(
              onTap: _resetForm,
              child: const Text(
                "Change",
                style: TextStyle(
                  color: Color(0xFFFB5404),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Stack(
          children: [
            Opacity(
              opacity: 0,
              child: SizedBox(
                height: 48,
                child: TextField(
                  controller: _otpController,
                  focusNode: _otpFocusNode,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (val) {
                    setState(() {});
                    if (val.length == 6) {
                      _verifyOtp();
                    }
                  },
                ),
              ),
            ),
            Focus(
              onFocusChange: (hasFocus) {
                setState(() {});
              },
              child: GestureDetector(
                onTap: () => _otpFocusNode.requestFocus(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    final text = _otpController.text;
                    final hasDigit = text.length > index;
                    final digit = hasDigit ? text[index] : "";
                    final isFocused = _otpFocusNode.hasFocus && text.length == index;
                    
                    return Container(
                      width: 44,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFocused
                              ? const Color(0xFFFB5404)
                              : const Color(0xFFE5E7EB),
                          width: isFocused ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        digit,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Resend OTP in $timerText",
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
            GestureDetector(
              onTap: _resendTimer > 0 ? null : _sendOtp,
              child: Text(
                "Resend",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _resendTimer > 0 ? const Color(0xFF9CA3AF) : const Color(0xFFFB5404),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildResponsiveButton(
          text: _loading ? "Verifying..." : "Verify OTP",
          onPressed: _loading ? null : _verifyOtp,
        ),

      ],
    );
  }

  Widget _buildResponsiveButton({required String text, VoidCallback? onPressed}) {
    final bool isDisabled = onPressed == null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDisabled ? const Color(0xFFE5E7EB) : const Color(0xFFFB5404),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: const Color(0xFFFB5404).withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isDisabled ? const Color(0xFF9CA3AF) : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _acceptedTerms,
            activeColor: const Color(0xFFFB5404),
            checkColor: Colors.white,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            onChanged: (val) {
              setState(() {
                _acceptedTerms = val ?? false;
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: "I agree to the ",
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
              children: [
                TextSpan(
                  text: "Terms & Conditions",
                  style: const TextStyle(
                    color: Color(0xFFFB5404),
                    fontWeight: FontWeight.bold,
                  ),
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
                  style: const TextStyle(
                    color: Color(0xFFFB5404),
                    fontWeight: FontWeight.bold,
                  ),
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
                  style: const TextStyle(
                    color: Color(0xFFFB5404),
                    fontWeight: FontWeight.bold,
                  ),
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
          ),
        ),
      ],
    );
  }

  Widget _buildToastNotification(BuildContext context) {
    return AnimatedBuilder(
      animation: _toastAnimController,
      builder: (context, child) {
        final double topSafeArea = MediaQuery.of(context).padding.top;
        return Positioned(
          top: topSafeArea + 12 + _toastSlideAnimation.value,
          left: 16,
          right: 16,
          child: child!,
        );
      },
      child: GestureDetector(
        onTap: () {
          _toastTimer?.cancel();
          _toastAnimController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _showToastWidget = false;
              });
            }
          });
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _toastIsError ? const Color(0xFFFEE2E2) : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _toastIsError ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _toastIsError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _toastIsError ? Icons.error_outline : Icons.check_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _toastTitle ?? "",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _toastIsError ? const Color(0xFF991B1B) : const Color(0xFF065F46),
                        ),
                      ),
                      if (_toastMessage != null && _toastMessage!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _toastMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _toastIsError ? const Color(0xFFB91C1C) : const Color(0xFF047857),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.close,
                  color: _toastIsError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
