import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_routes.dart';

class OrderSuccessScreen extends StatefulWidget {
  final String orderId;

  const OrderSuccessScreen({super.key, required this.orderId});

  static void cancelActiveTimer() {
    _OrderSuccessScreenState.activeState?._cancelTimer();
  }

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with SingleTickerProviderStateMixin {
  static _OrderSuccessScreenState? activeState;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    activeState = this;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _rotateAnimation = Tween<double>(begin: -0.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _animController.forward();

    _redirectTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _redirectTimer = null;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.home,
          (route) => false,
        );
      }
    });
  }

  void _cancelTimer() {
    if (_redirectTimer != null) {
      debugPrint("🔔 OrderSuccessScreen redirect timer cancelled.");
      _redirectTimer?.cancel();
      _redirectTimer = null;
    }
  }

  @override
  void dispose() {
    if (activeState == this) {
      activeState = null;
    }
    _cancelTimer();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bool isSmallScreen = mediaQuery.size.height < 700;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _cancelTimer();
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.home,
          (route) => false,
        );
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0D9488), // Teal-Green primary
                Color(0xFF0F766E), // Emerald-Green secondary
                Color(0xFF115E59), // Deep dark teal
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  
                  // Animated Success Checkmark Icon
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Transform.rotate(
                          angle: _rotateAnimation.value * 2 * 3.14159,
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      width: isSmallScreen ? 110 : 130,
                      height: isSmallScreen ? 110 : 130,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            // ignore: deprecated_member_use
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            // ignore: deprecated_member_use
                            color: Colors.white.withOpacity(0.2),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: isSmallScreen ? 110 : 130,
                        color: const Color(0xFF0D9488),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Success Title
                  const Text(
                    'Order Placed Successfully!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Subtitle
                  const Text(
                    'Thank you for shopping with us.\nYour items will be delivered soon.',
                    style: TextStyle(
                      // ignore: deprecated_member_use
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const Spacer(flex: 2),
                  
                  // Action Buttons
                  Column(
                    children: [
                      // Continue Shopping Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0F766E),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          onPressed: () {
                            _cancelTimer();
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              AppRoutes.home,
                              (route) => false,
                            );
                          },
                          child: const Text(
                            'Continue Shopping',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Track Order Button
                      if (widget.orderId.isNotEmpty)
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white, width: 2),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            onPressed: () {
                              _cancelTimer();
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                AppRoutes.home,
                                (route) => false,
                              );
                              Navigator.of(context).pushNamed(AppRoutes.orders);
                            },
                            child: const Text(
                              'View Order Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
