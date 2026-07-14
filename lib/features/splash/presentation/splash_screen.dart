import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/storage/session_store.dart';
import '../../home/presentation/home_screen.dart';
import '../../login/presentation/login_screen.dart';
import '../../../core/services/push_notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const routeName = AppRoutes.splash;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.instance.initialize();
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      final loggedIn = await SessionStore.isLoggedIn();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        loggedIn ? HomeScreen.routeName : LoginScreen.routeName,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Image.asset(
            'assets/images/splash.png',
            width: 200,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
