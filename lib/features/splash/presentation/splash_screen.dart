import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/storage/session_store.dart';
import '../../home/presentation/home_screen.dart';
import '../../login/presentation/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const routeName = AppRoutes.splash;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Controller for staggered animations
  late final AnimationController _animController;
  
  // Staggered Animation steps
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoSlide;
  late final Animation<double> _subtitleOpacity;

  // Progress animation state
  double _loadingProgress = 0.0;
  Timer? _progressTimer;

  String _getLoadingText() {
    final int elapsedMs = (_loadingProgress * 3500).toInt();
    if (elapsedMs < 800) {
      return "Getting things ready…";
    } else if (elapsedMs < 1600) {
      return "Loading deals & Play…";
    } else if (elapsedMs < 2400) {
      return "Almost there…";
    } else {
      return "Welcome to Welfog";
    }
  }

  @override
  void initState() {
    super.initState();

    // 1. Setup Staggered Logo Animations
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _logoSlide = Tween<double>(begin: 15.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
      ),
    );

    _animController.forward();

    // 2. Setup smooth filling progress timer (ticks every 30ms -> total duration 3.5 seconds)
    const int stepDurationMs = 30;
    const double stepSize = 30.0 / 3500.0;

    _progressTimer = Timer.periodic(const Duration(milliseconds: stepDurationMs), (timer) {
      if (!mounted) return;
      setState(() {
        _loadingProgress += stepSize;
        if (_loadingProgress >= 1.0) {
          _loadingProgress = 1.0;
          _progressTimer?.cancel();
          _transitionToNextScreen();
        }
      });
    });

    // No explicit rotating text timer needed - updated dynamically based on progress percent
  }

  Future<void> _transitionToNextScreen() async {
    final loggedIn = await SessionStore.isLoggedIn();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      loggedIn ? HomeScreen.routeName : LoginScreen.routeName,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _progressTimer?.cancel();
    // No text timer to cancel
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Ambient glows
          // Center Peach Glow (directly behind logo & subtitle)
          Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    // ignore: deprecated_member_use
                    const Color(0xFFFFEAD9).withOpacity(0.55),
                    // ignore: deprecated_member_use
                    const Color(0xFFFFFAED).withOpacity(0.12),
                    // ignore: deprecated_member_use
                    Colors.white.withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          // Bottom Cyan/Teal Glow
          Positioned(
            bottom: -150,
            left: screenWidth * 0.15,
            right: screenWidth * 0.15,
            child: Container(
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    // ignore: deprecated_member_use
                    const Color(0xFFE2FAF6).withOpacity(0.45),
                    // ignore: deprecated_member_use
                    const Color(0xFFF0FCFA).withOpacity(0.12),
                    // ignore: deprecated_member_use
                    Colors.white.withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // Central Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _logoSlide.value),
                        child: child,
                      ),
                    );
                  },
                  child: Image.asset(
                    'assets/images/welf.png',
                    width: 240,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _subtitleOpacity.value,
                      child: child,
                    );
                  },
                  child: const Text(
                    "Shop deals. Watch Play.\nAll in one app.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4B5563),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Loading area
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Orange & Teal circular loader
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color.lerp(const Color(0xFFFB5404), const Color(0xFF0B7E7B), _loadingProgress) ?? const Color(0xFFFB5404),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Smooth linear progress bar
                Container(
                  width: 140,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _loadingProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFB5404), Color(0xFF0B7E7B)],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Rotating texts with smooth fade switcher
                SizedBox(
                  height: 20,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: child,
                    ),
                    child: Text(
                      _getLoadingText(),
                      key: ValueKey<String>(_getLoadingText()),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9CA3AF),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
