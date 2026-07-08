import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/storage/session_store.dart';
import '../../home/presentation/home_screen.dart';
import '../data/login_service.dart';

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
  int _resendTimer = 0;
  Timer? _timer;

  // Animations (Easing.out(Easing.exp) -> Curves.easeOutExpo)
  late AnimationController _logoController;
  late AnimationController _cardController;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _logoTranslateY;
  late Animation<double> _cardOpacity;
  late Animation<double> _cardTranslateY;

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

    // Controllers Setup
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Animating properties
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutExpo),
    );
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutExpo),
    );
    _logoTranslateY = Tween<double>(begin: -30.0, end: 0.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutExpo),
    );

    _cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutExpo),
    );
    _cardTranslateY = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutExpo),
    );

    // Starting Animation in Sequence
    _logoController.forward().then((_) {
      _cardController.forward();
    });

    // Custom Top Toast Setup
    _toastAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _toastSlideAnimation = Tween<double>(begin: -150.0, end: 0.0).animate(
      CurvedAnimation(parent: _toastAnimController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    _logoController.dispose();
    _cardController.dispose();
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
    final phone = _phoneController.text.trim();
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
    final screenHeight = mediaQuery.size.height;
    final isSmallDevice = screenHeight < 700;
    final insets = mediaQuery.padding;
    final bool isKeyboardOpen = mediaQuery.viewInsets.bottom > 0;

    // Dynamic padding calculations matching React Native calculations
    final double topPadding = min(96.0, max(isSmallDevice ? 22.0 : 34.0, insets.top + screenHeight * 0.06));
    final double bottomSpacing = min(190.0, max(110.0, screenHeight * 0.22));

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Background Effects
          Positioned(
            top: -28,
            left: -22,
            width: 220,
            height: 190,
            child: Opacity(
              opacity: 0.9,
              child: Image.asset("assets/vector/effect_img1.png", fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 8,
            right: -30,
            width: 190,
            height: 190,
            child: Opacity(
              opacity: 0.9,
              child: Image.asset("assets/vector/effect_img2.png", fit: BoxFit.contain),
            ),
          ),
          // Floating Ambient Icons - Hidden when keyboard is open to avoid clutter
          if (!isKeyboardOpen) ...[
            Positioned(
              top: 192,
              left: 36,
              width: 48,
              height: 48,
              child: Opacity(
                opacity: 0.16,
                child: Image.asset("assets/icons/login/icon2.png", fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 192,
              right: 34,
              width: 44,
              height: 44,
              child: Opacity(
                opacity: 0.14,
                child: Image.asset("assets/icons/login/icon3.png", fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 252,
              left: -14,
              width: 56,
              height: 56,
              child: Opacity(
                opacity: 0.12,
                child: Image.asset("assets/icons/login/icon4.png", fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 206,
              right: -14,
              width: 52,
              height: 52,
              child: Opacity(
                opacity: 0.1,
                child: Image.asset("assets/icons/login/icon4.png", fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 164,
              right: 110,
              width: 44,
              height: 44,
              child: Opacity(
                opacity: 0.12,
                child: Image.asset("assets/icons/login/icon5.png", fit: BoxFit.contain),
              ),
            ),
          ],
          // Bottom Art Vector - Hidden when keyboard is open to avoid layout overlap
          if (!isKeyboardOpen) ...[
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              height: 340,
              child: Opacity(
                opacity: 0.58,
                child: Image.asset("assets/vector/flash_img_1.png", fit: BoxFit.cover),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              height: 340,
              // ignore: deprecated_member_use
              child: Container(color: Colors.white.withOpacity(0.28)),
            ),
          ],

          // Scrollable login body - Centers and constrains layout width on tablets/web
          SafeArea(
            bottom: false,
            top: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: topPadding,
                    bottom: 12 + bottomSpacing + insets.bottom,
                  ),
              child: Column(
                children: [
                  // Animated Logo Section
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Transform.translate(
                            offset: Offset(0, _logoTranslateY.value),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Image.asset(
                          "assets/images/Untitleddesign.png",
                          width: 240,
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 54, height: 1, color: const Color(0xFFD9D9D9)),
                            const SizedBox(width: 10),
                            const Text(
                              "Shop More, Save More",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7A7A7A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(width: 54, height: 1, color: const Color(0xFFD9D9D9)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Animated Card Content
                  AnimatedBuilder(
                    animation: _cardController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _cardOpacity.value,
                        child: Transform.translate(
                          offset: Offset(0, _cardTranslateY.value),
                          child: child,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Welcome to ",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const Text(
                                "Welfog",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF0B7E7B),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Image.asset(
                                "assets/icons/login/icon1.png",
                                width: 26,
                                height: 26,
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Conditional Views (Phone Number vs OTP Sent)
                          if (!_otpSent) ...[
                            // Phone Number Field
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
                            Container(
                              height: 2,
                              margin: const EdgeInsets.only(top: 10),
                              decoration: BoxDecoration(
                                // ignore: deprecated_member_use
                                color: const Color(0xFF2A8C7A).withOpacity(0.5),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Send OTP Action Button
                            _buildPrimaryButton(
                              text: _loading ? "Sending OTP..." : "Send OTP",
                              icon: Icons.arrow_forward,
                              onPressed: _loading ? null : _sendOtp,
                            ),
                            const SizedBox(height: 10),

                            // Security Info Row
                            // ignore: prefer_const_constructors
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF33A38A)),
                                SizedBox(width: 8),
                                Text(
                                  "We ensure your data is safe and secure",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            // OTP input layout
                            Text(
                              "Enter OTP sent to +91 ${_phoneController.text}",
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF374151),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFD1D5DB)),
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
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Verify Button
                            _buildPrimaryButton(
                              text: _loading ? "Verifying..." : "Verify OTP",
                              icon: Icons.check,
                              onPressed: _loading ? null : _verifyOtp,
                            ),
                            const SizedBox(height: 12),

                            // Resend and Reset form options
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
                                      color: _resendTimer > 0 ? const Color(0xFF9CA3AF) : const Color(0xFFF4511E),
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
                                      color: Color(0xFFF4511E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 30),

                          // Footer with rich inline links (T&C, Privacy Policy)
                          const Center(
                            child: Text.rich(
                              TextSpan(
                                text: "By continuing, you agree to our ",
                                style: TextStyle(fontSize: 12, color: Color(0xFF374151), height: 1.5),
                                children: [
                                  TextSpan(
                                    text: "Terms & Conditions",
                                    style: TextStyle(color: Color(0xFF0A6B69), fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: ", "),
                                  TextSpan(
                                    text: "Privacy Policy",
                                    style: TextStyle(color: Color(0xFF0A6B69), fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: ", and "),
                                  TextSpan(
                                    text: "Anti-Phishing",
                                    style: TextStyle(color: Color(0xFF0A6B69), fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: "."),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      // Skip Button - Positioned here (at the end of Stack) so it is clickable on top of the SafeArea/Scrollview
      Positioned(
        top: insets.top + 12,
        right: 20,
        child: GestureDetector(
          onTap: _handleGuestMode,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x2E0A6B69)),
              boxShadow: [
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            // ignore: prefer_const_constructors
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  "Skip",
                  style: TextStyle(
                    color: Color(0xFF0A6B69),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward, size: 16, color: Color(0xFF0A6B69)),
              ],
            ),
          ),
        ),
      ),
      
      // Top custom toast popup
      if (_showToastWidget)
        AnimatedBuilder(
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
        ),
    ],
  ),
);
  }

  // Common Primary Button Builder with Linear Gradient
  Widget _buildPrimaryButton({required String text, required IconData icon, VoidCallback? onPressed}) {
    final bool isDisabled = onPressed == null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: isDisabled
                ? [const Color(0xFFC9C9C9), const Color(0xFFBDBDBD)]
                : (_otpSent ? [const Color(0xFFFF8A2A), const Color(0xFFF4511E)] : [const Color(0xFFFFA63A), const Color(0xFFF26A1A)]),
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: const Color(0xFFF26A1A).withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 34), // Adjust text to balance out the icon container
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            Container(
              height: 34,
              width: 34,
              margin: const EdgeInsets.only(right: 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: const Color(0xFFFF6A00),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
