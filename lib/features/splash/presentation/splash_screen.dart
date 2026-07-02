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
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
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
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A63E8), Color(0xFF04B1E7)],
          ),
        ),
        child: FadeTransition(
          opacity: _fade,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.white,
                child: Icon(Icons.storefront_rounded, size: 40),
              ),
              SizedBox(height: 18),
              Text(
                'Welfog',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Shop smarter. Play better.',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
