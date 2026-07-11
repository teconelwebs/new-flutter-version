import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NoInternetWidget extends StatefulWidget {
  final VoidCallback onRetry;
  final String title;
  final String message;

  const NoInternetWidget({
    super.key,
    required this.onRetry,
    this.title = 'No Internet Connection',
    this.message = 'Please check your connection and try again.',
  });

  @override
  State<NoInternetWidget> createState() => _NoInternetWidgetState();
}

class _NoInternetWidgetState extends State<NoInternetWidget> {
  Timer? _autoRetryTimer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _startAutoRetryTimer();
  }

  @override
  void dispose() {
    _autoRetryTimer?.cancel();
    super.dispose();
  }

  void _startAutoRetryTimer() {
    _autoRetryTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_checking || !mounted) return;
      _checking = true;
      try {
        if (kIsWeb) {
          timer.cancel();
          widget.onRetry();
        } else {
          final result = await InternetAddress.lookup('google.com')
              .timeout(const Duration(seconds: 2));
          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            timer.cancel();
            widget.onRetry();
          }
        }
      } catch (_) {
        // Still no internet
      } finally {
        _checking = false;
      }
    });
  }

  String _getCleanTitle() {
    final lower = widget.title.toLowerCase();
    if (lower.contains('error') || lower.contains('connection') || lower.contains('fail')) {
      return 'No Internet Connection';
    }
    return widget.title;
  }

  String _getCleanMessage() {
    final lower = widget.message.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('httpstatuscode') ||
        lower.contains('http') ||
        lower.contains('connection failed') ||
        lower.contains('network') ||
        lower.contains('connect') ||
        lower.contains('exception') ||
        lower.contains('clientexception')) {
      return 'Please check your connection and try again.';
    }
    return widget.message;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF6F1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 72,
                color: Color(0xFFFB5404),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              _getCleanTitle(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _getCleanMessage(),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: widget.onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFB5404),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Try Again',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
