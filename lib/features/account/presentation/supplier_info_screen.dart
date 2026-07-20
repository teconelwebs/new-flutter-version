import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/constants/app_routes.dart';

class SupplierInfoScreen extends StatelessWidget {
  const SupplierInfoScreen({super.key});

  /// Shows a custom rationale bottom sheet explaining WHY camera
  /// permission is needed before triggering the system prompt (on non-iOS).
  /// On iOS, requests permission natively and directly navigates.
  void _requestCameraAndNavigate(BuildContext context) async {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      Navigator.of(context).pushNamed(AppRoutes.connectSupplier);
      return;
    }

    // Check current permission status using MobileScannerController
    final controller = MobileScannerController();

    final bool granted = await _showPermissionRationale(context);

    // Dispose the temp controller we only used for permission check
    await controller.dispose();

    if (!granted) return;

    if (context.mounted) {
      Navigator.of(context).pushNamed(AppRoutes.connectSupplier);
    }
  }

  /// Shows the custom bottom sheet explaining camera usage.
  /// Returns true if user taps "Allow Camera Access".
  Future<bool> _showPermissionRationale(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PermissionRationaleSheet(),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Custom Header Back Button
              Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 24),
                ),
              ),

              // Center Graphic
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Image.asset(
                      'assets/images/IMG.png',
                      width: size.width * 0.8,
                      height: size.width * 0.8,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              // Title and Description
              Padding(
                padding: EdgeInsets.symmetric(horizontal: size.width * 0.06),
                child: Column(
                  children: [
                    Text(
                      'Connect with Supplier',
                      style: TextStyle(
                        fontSize: size.width * 0.065,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111111),
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Scan the supplier\u2019s QR code to sync videos and easily use them in your product listings.',
                      style: TextStyle(
                        fontSize: size.width * 0.042,
                        color: const Color(0xFF555555),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // Bottom Button Container
              Padding(
                padding: EdgeInsets.only(
                  left: size.width * 0.06,
                  right: size.width * 0.06,
                  bottom: size.height * 0.03,
                ),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        // ignore: deprecated_member_use
                        color: const Color(0xFFFF6A00).withOpacity(0.3),
                        offset: const Offset(0, 8),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _requestCameraAndNavigate(context),
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 22),
                    label: const Text(
                      'Continue to Scan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6A00),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom bottom sheet that clearly explains WHY camera access
/// is needed before the iOS system permission popup appears.
class _PermissionRationaleSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // Camera icon with orange glow
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: const Color(0xFFFF6A00).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              color: Color(0xFFFF6A00),
              size: 38,
            ),
          ),
          const SizedBox(height: 20),

          // Title
          const Text(
            'Camera Access Required',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111111),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Main explanation
          const Text(
            'To connect your account with the Supplier Panel, we need your camera to scan the supplier\'s QR code.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF555555),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // What we use it for
          const _PermissionPoint(
            icon: Icons.qr_code_rounded,
            title: 'Scan Supplier QR Code',
            subtitle: 'One-time scan to link your supplier panel account',
          ),
          const SizedBox(height: 12),
          const _PermissionPoint(
            icon: Icons.link_rounded,
            title: 'Secure Connection',
            subtitle: 'Camera is only used during the QR scan — never recorded',
          ),
          const SizedBox(height: 12),
          const _PermissionPoint(
            icon: Icons.video_library_rounded,
            title: 'Sync Supplier Videos',
            subtitle: 'Access supplier product videos for your listings after connecting',
          ),
          const SizedBox(height: 32),

          // Allow button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6A00),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Allow Camera Access',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Not now button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Not Now',
                style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single row explaining one aspect of why the permission is needed.
class _PermissionPoint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PermissionPoint({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: const Color(0xFFFF6A00).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFFFF6A00), size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF888888),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
