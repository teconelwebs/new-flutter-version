import 'package:flutter/material.dart';
import '../state/cart_state.dart';

class ViewCartBanner extends StatefulWidget {
  final VoidCallback onTap;

  const ViewCartBanner({
    super.key,
    required this.onTap,
  });

  @override
  State<ViewCartBanner> createState() => _ViewCartBannerState();
}

class _ViewCartBannerState extends State<ViewCartBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.5), // Start below the screen
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack, // Premium bounce effect
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: CartState.cartCountNotifier,
      builder: (context, cartCount, _) {
        if (cartCount <= 0) {
          return const SizedBox.shrink();
        }
        final screenWidth = MediaQuery.sizeOf(context).width;
        final targetWidth = (screenWidth * 0.35).clamp(155.0, 240.0);

        return SlideTransition(
          position: _offsetAnimation,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Align(
              alignment: Alignment.center,
              child: Container(
                width: targetWidth,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Material(
                  color: const Color(0xFFFB5404), // Brand orange matching navigation
                  borderRadius: BorderRadius.circular(24),
                  elevation: 4,
                  // ignore: deprecated_member_use
                  shadowColor: Colors.black.withOpacity(0.3),
                  child: InkWell(
                    onTap: widget.onTap,
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Unique, proper orange cart icon inside a white circle badge
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shopping_cart_rounded,
                              color: Color(0xFFFB5404), // Proper orange cart icon
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'View Cart',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$cartCount ${cartCount == 1 ? "Item" : "Items"}',
                                  style: TextStyle(
                                    // ignore: deprecated_member_use
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
