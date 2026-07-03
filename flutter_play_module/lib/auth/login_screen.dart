import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  // State
  String _phoneNumber = "";
  String _otp = "";
  bool _otpSent = false;
  bool _loading = false;
  int _resendTimer = 0;
  Timer? _timer;

  // Controllers
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _otpFocus = FocusNode();

  // Animations
  late AnimationController _logoAnimController;
  late Animation<double> _logoTranslateY;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  late AnimationController _cardAnimController;
  late Animation<double> _cardTranslateY;
  late Animation<double> _cardOpacity;

  // Constants (replace with your actual API urls)
  final String mainAPI = "https://api.welfog.com/api";
  final String secondAPI = "https://welfogapi.welfog.com/api";

  @override
  void initState() {
    super.initState();

    // Logo Animation Setup
    _logoAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _logoTranslateY = Tween<double>(begin: -30, end: 0).animate(
      CurvedAnimation(parent: _logoAnimController, curve: Curves.easeOutExpo),
    );
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoAnimController, curve: Curves.easeOutExpo),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoAnimController, curve: Curves.easeOutExpo),
    );

    // Card Animation Setup
    _cardAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _cardTranslateY = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(parent: _cardAnimController, curve: Curves.easeOutExpo),
    );
    _cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardAnimController, curve: Curves.easeOutExpo),
    );

    // Start sequence
    _logoAnimController.forward().then((_) {
      _cardAnimController.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocus.dispose();
    _otpFocus.dispose();
    _logoAnimController.dispose();
    _cardAnimController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        timer.cancel();
      }
    });
  }

  String _generateTempId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomNum = math.Random().nextInt(1000000);
    return "TEMP_${timestamp}_$randomNum";
  }

  void _showToast(String title, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (message.isNotEmpty) Text(message),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleGuestMode() async {
    // Equivalent to await enterGuestMode();
    Navigator.pushReplacementNamed(context, '/(tabs)');
  }

  Future<void> _sendOtp() async {
    if (_phoneNumber.length != 10 || int.tryParse(_phoneNumber) == null) {
      _showToast("Invalid Phone Number", "Please enter a valid 10-digit mobile number.", isError: true);
      return;
    }

    setState(() => _loading = true);
    FocusScope.of(context).unfocus(); // Dismiss keyboard

    try {
      final response = await http.get(Uri.parse('$mainAPI/buyerverifynumber?phone=$_phoneNumber'));
      final data = jsonDecode(response.body);
      final accountStatus = data['account_status']?.toString();

      if (accountStatus == "active") {
        setState(() => _otpSent = true);
        _startResendTimer();
        _showToast("OTP Sent", "OTP sent to +91 $_phoneNumber");
      } else if (accountStatus == "banned") {
        _showToast("Account Suspended", data['message'] ?? "Your account has been banned by the admin. Please contact support.", isError: true);
      } else if (accountStatus == "deleted") {
        Navigator.pushNamed(context, '/ProfileScreen/AccountDeleted', arguments: {
          'phone': _phoneNumber,
          'deleted_date': data['deleted_date'] ?? "",
        });
      } else {
        // Fallback logic
        if (response.statusCode == 200) {
          setState(() => _otpSent = true);
          _startResendTimer();
          _showToast("OTP Sent", "OTP sent to +91 $_phoneNumber");
        } else {
          _showToast("Failed to send OTP", data['message'] ?? "Please try again.", isError: true);
        }
      }
    } catch (e) {
      _showToast("Failed to send OTP", "Unable to send OTP. Please try again.", isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != 6) {
      _showToast("Invalid OTP", "", isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      final response = await http.get(Uri.parse('$mainAPI/usercheckVerifyOtp?phone=$_phoneNumber&otp=$_otp'));
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['result'] == true) {
        final userId = data['user']['id'];
        final tmpid = _generateTempId();
        
        final prefs = await SharedPreferences.getInstance();

        // Clear caches identically
        await prefs.remove('play_profile_id');
        await prefs.remove('play_profile_user_name');
        await prefs.remove('play_profile_name');
        await prefs.remove('cached_user_id');
        await prefs.remove('fourth_userid');
        await prefs.remove('loginid');

        // Set new data
        await prefs.setString("access_token", data['access_token'] ?? "");
        await prefs.setString("loginuser", data['user']['name'] ?? "");
        await prefs.setString("user_id", userId.toString());
        await prefs.setString("isLoggedIn", "true");
        await prefs.setString("is_logged_in", "true");
        await prefs.setString("account", data['account'] ?? "login");
        await prefs.setString("temp_user_id", tmpid);

        // Expo Push Token Logic (Assuming token is available via local state/prefs)
        // Dummy block to represent push token saving
        /*
        final pushToken = ...;
        if (pushToken != null) {
          await http.post(Uri.parse('$secondAPI/notification/save-token'), body: {...});
        }
        */

        // Small delay equivalent to JS setTimeout
        await Future.delayed(const Duration(milliseconds: 100));
        await prefs.setString("post_login_check", "true");

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/(tabs)');
        }
      } else {
        _showToast("Verification Failed", "Invalid OTP. Please try again.", isError: true);
      }
    } catch (e) {
      _showToast("Login Failed", "Verification Error", isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetForm() {
    setState(() {
      _otp = "";
      _phoneNumber = "";
      _otpSent = false;
      _resendTimer = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final insets = MediaQuery.of(context).padding;
    final isSmallDevice = size.height < 700;

    final topPadding = math.min(
      96.0,
      math.max(isSmallDevice ? 22.0 : 34.0, (insets.top) + size.height * 0.06),
    );
    final bottomSpacing = math.min(190.0, math.max(110.0, size.height * 0.22));

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Background Effects (Absolute Positioning like React Native)
          Positioned(
            top: -28, left: -22,
            child: Opacity(
              opacity: 0.9,
              child: Image.asset("assets/vector/effect_img1.png", width: 220, height: 190, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 8, right: -30,
            child: Opacity(
              opacity: 0.9,
              child: Image.asset("assets/vector/effect_img2.png", width: 190, height: 190, fit: BoxFit.contain),
            ),
          ),

          // Floating Icons
          Positioned(top: 192, left: 36, child: Opacity(opacity: 0.16, child: Image.asset("assets/icons/login/icon2.png", width: 48, height: 48))),
          Positioned(top: 192, right: 34, child: Opacity(opacity: 0.14, child: Image.asset("assets/icons/login/icon3.png", width: 44, height: 44))),
          Positioned(top: 252, left: -14, child: Opacity(opacity: 0.12, child: Image.asset("assets/icons/login/icon4.png", width: 56, height: 56))),
          Positioned(top: 206, right: -14, child: Opacity(opacity: 0.10, child: Image.asset("assets/icons/login/icon4.png", width: 52, height: 52))),
          Positioned(top: 164, right: 110, child: Opacity(opacity: 0.12, child: Image.asset("assets/icons/login/icon5.png", width: 44, height: 44))),

          // Bottom Art & Veil
          Positioned(
            bottom: 20, left: 0, right: 0,
            child: Opacity(
              opacity: 0.2, // 20.58 in RN code maps to 0.2 here roughly
              child: Image.asset("assets/vector/flash_img_1.png", height: 340, width: double.infinity, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            bottom: 20, left: 0, right: 0,
            child: Container(
              height: 340,
              color: Colors.white.withOpacity(0.28),
            ),
          ),

          // Main Content
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, topPadding, 20, 12 + bottomSpacing + insets.bottom),
              child: Column(
                children: [
                  Expanded(child: Container()), // Spacer equivalent
                  
                  // Animated Logo
                  AnimatedBuilder(
                    animation: _logoAnimController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.translate(
                          offset: Offset(0, _logoTranslateY.value),
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: Column(
                              children: [
                                Image.asset("assets/images/Untitleddesign.png", width: 240, height: 120, fit: BoxFit.contain),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(height: 1, width: 54, color: const Color(0xFFD9D9D9)),
                                    const SizedBox(width: 10),
                                    const Text("Shop More, Save More", style: TextStyle(fontSize: 12, color: Color(0xFF7A7A7A), fontWeight: FontWeight.w500)),
                                    const SizedBox(width: 10),
                                    Container(height: 1, width: 54, color: const Color(0xFFD9D9D9)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),

                  // Animated Card
                  AnimatedBuilder(
                    animation: _cardAnimController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _cardOpacity.value,
                        child: Transform.translate(
                          offset: Offset(0, _cardTranslateY.value),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text("Welcome to ", style: TextStyle(fontSize: 22, color: Color(0xFF111827))),
                                    const Text("Welfog", style: TextStyle(fontSize: 22, color: Color(0xFF0B7E7B))),
                                    const SizedBox(width: 6),
                                    Image.asset("assets/icons/login/icon1.png", width: 26, height: 26),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                if (!_otpSent) ...[
                                  // Phone Input
                                  GestureDetector(
                                    onTap: () => FocusScope.of(context).requestFocus(_phoneFocus),
                                    child: Container(
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
                                            decoration: const BoxDecoration(
                                              border: Border(right: BorderSide(color: Color(0xFFEFEFEF))),
                                            ),
                                            child: const Center(child: Text("+91", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827)))),
                                          ),
                                          const SizedBox(width: 10),
                                          const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF9AA0A6)),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: TextField(
                                              controller: _phoneController,
                                              focusNode: _phoneFocus,
                                              keyboardType: TextInputType.phone,
                                              maxLength: 10,
                                              style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                                              decoration: const InputDecoration(
                                                counterText: "",
                                                border: InputBorder.none,
                                                hintText: "Enter mobile number",
                                                hintStyle: TextStyle(color: Color(0xFFA9A9A9)),
                                              ),
                                              onChanged: (val) => _phoneNumber = val,
                                              onSubmitted: (_) => _sendOtp(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    height: 2,
                                    margin: const EdgeInsets.only(top: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2A8C7A).withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  
                                  // Send OTP Button
                                  GestureDetector(
                                    onTap: _loading ? null : _sendOtp,
                                    child: Container(
                                      height: 56,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        gradient: LinearGradient(
                                          colors: _loading ? [const Color(0xFFC9C9C9), const Color(0xFFBDBDBD)] : [const Color(0xFFFFA63A), const Color(0xFFF26A1A)],
                                        ),
                                        boxShadow: const [BoxShadow(color: Color.fromRGBO(242, 106, 26, 0.25), blurRadius: 18, offset: Offset(0, 6))],
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _loading ? "Sending OTP..." : "Send OTP",
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                                            ),
                                          ),
                                          Container(
                                            margin: const EdgeInsets.only(right: 11),
                                            height: 34,
                                            width: 34,
                                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                            child: const Icon(Icons.arrow_forward, size: 18, color: Color(0xFFFF6A00)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.shield_outlined, size: 16, color: Color(0xFF33A38A)),
                                      SizedBox(width: 8),
                                      Text("We ensure your data is safe and secure", style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ] else ...[
                                  // OTP Verification Flow
                                  Text("Enter OTP sent to +91 $_phoneNumber", style: const TextStyle(fontSize: 13, color: Color(0xFF374151), fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 10),
                                  GestureDetector(
                                    onTap: () => FocusScope.of(context).requestFocus(_otpFocus),
                                    child: Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFD1D5DB)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.key_outlined, size: 18, color: Color(0xFF9AA0A6)),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: TextField(
                                              controller: _otpController,
                                              focusNode: _otpFocus,
                                              keyboardType: TextInputType.number,
                                              maxLength: 6,
                                              style: const TextStyle(fontSize: 14, color: Color(0xFF111827), letterSpacing: 1.5),
                                              decoration: const InputDecoration(
                                                counterText: "",
                                                border: InputBorder.none,
                                                hintText: "Enter 6-digit OTP",
                                                hintStyle: TextStyle(color: Color(0xFFA0A0A0)),
                                              ),
                                              onChanged: (val) => _otp = val.replaceAll(RegExp(r'\D'), ''),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // Verify OTP Button
                                  GestureDetector(
                                    onTap: _loading ? null : _verifyOtp,
                                    child: Container(
                                      height: 56,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        gradient: LinearGradient(
                                          colors: _loading ? [const Color(0xFFC9C9C9), const Color(0xFFBDBDBD)] : [const Color(0xFFFF8A2A), const Color(0xFFF4511E)],
                                        ),
                                        boxShadow: const [BoxShadow(color: Color.fromRGBO(242, 106, 26, 0.25), blurRadius: 18, offset: Offset(0, 6))],
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _loading ? "Verifying..." : "Verify OTP",
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                                            ),
                                          ),
                                          Container(
                                            margin: const EdgeInsets.only(right: 11),
                                            height: 34,
                                            width: 34,
                                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                            child: const Icon(Icons.check, size: 18, color: Color(0xFFFF6A00)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      GestureDetector(
                                        onTap: _resendTimer > 0 ? null : _sendOtp,
                                        child: Text(
                                          _resendTimer > 0 ? "Resend OTP in ${_resendTimer}s" : "Resend OTP",
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _resendTimer > 0 ? const Color(0xFF9CA3AF) : const Color(0xFFF4511E)),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _resetForm,
                                        child: const Text("Change Number", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFF4511E))),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  Expanded(child: Container()),

                  // Footer
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12, color: Color(0xFF374151), height: 1.5),
                        children: [
                          const TextSpan(text: "By continuing, you agree to our "),
                          WidgetSpan(child: GestureDetector(onTap: () => launchUrl(Uri.parse("https://www.welfog.com/page/terms-and-conditions")), child: const Text("Terms & Conditions", style: TextStyle(color: Color(0xFF0A6B69), fontWeight: FontWeight.w800)))),
                          const TextSpan(text: ", "),
                          WidgetSpan(child: GestureDetector(onTap: () => launchUrl(Uri.parse("https://www.welfog.com/page/privacy-policy")), child: const Text("Privacy Policy", style: TextStyle(color: Color(0xFF0A6B69), fontWeight: FontWeight.w800)))),
                          const TextSpan(text: ", and "),
                          WidgetSpan(child: GestureDetector(onTap: () => launchUrl(Uri.parse("https://www.welfog.com/page/anti-phishing-defense-policy")), child: const Text("Anti-Phishing", style: TextStyle(color: Color(0xFF0A6B69), fontWeight: FontWeight.w800)))),
                          const TextSpan(text: "."),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Skip Button - Moved to the end of the Stack to ensure clickability
          Positioned(
            top: insets.top + 12,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleGuestMode,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color.fromRGBO(10, 107, 105, 0.18)),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 6))],
                  ),
                  child: Row(
                    children: const [
                      Text("Skip", style: TextStyle(color: Color(0xFF0A6B69), fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 16, color: Color(0xFF0A6B69)),
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
}




