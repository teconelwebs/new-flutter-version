import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:welfog_flutter_play/welfog_flutter_play.dart' as play;

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  FirebaseMessaging? get _fcm {
    if (!_firebaseReady) {
      debugPrint(
        "FirebaseMessaging instance not available: Firebase app not initialized",
      );
      return null;
    }
    try {
      return FirebaseMessaging.instance;
    } catch (e) {
      debugPrint("FirebaseMessaging instance not available: $e");
      return null;
    }
  }

  bool _initialized = false;
  void Function(Map<String, dynamic> data)? onNotificationTapped;

  Future<void> initialize({BuildContext? context}) async {
    if (_initialized) return;

    try {
      final fcm = _fcm;
      if (fcm == null) {
        debugPrint(
          "PushNotificationService: Firebase not initialized. Skipping setup.",
        );
        return;
      }

      bool shouldPrompt = true;

      // On iOS, skip requesting notification permissions as requested
      if (Platform.isIOS) {
        shouldPrompt = false;
      }

      if (shouldPrompt) {
        // 1. Request user permission
        final settings = await fcm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        debugPrint(
          "\n🔔 ================================================\n"
          "🔔 PUSH PERMISSION STATUS: ${settings.authorizationStatus}\n"
          "🔔 ================================================\n",
        );
      }

      // iOS: show system banners while app is in foreground
      await fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 2. Initialize local notifications (Android foreground + taps)
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings =
          InitializationSettings(android: androidInit, iOS: iosInit);

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && onNotificationTapped != null) {
            try {
              final Map<String, dynamic> data = jsonDecode(payload);
              onNotificationTapped!(data);
            } catch (e) {
              debugPrint("Error parsing notification tap payload: $e");
            }
          }
        },
      );

      if (Platform.isAndroid) {
        const channel = AndroidNotificationChannel(
          'welfog_default_channel',
          'Default Notifications',
          description:
              'This channel is used for order and promotional notifications.',
          importance: Importance.max,
          playSound: true,
        );
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);

        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }

      // 3. Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
          "FCM foreground: title=${message.notification?.title}, data=${message.data}",
        );
        _showForegroundNotification(message);
      });

      // 4. Background tap (app in background, not terminated)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint("FCM opened from background: ${message.data}");
        if (onNotificationTapped != null) {
          onNotificationTapped!(message.data);
        }
      });

      // 5. Cold start from notification
      final initialMessage = await fcm.getInitialMessage();
      if (initialMessage != null && onNotificationTapped != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onNotificationTapped!(initialMessage.data);
        });
      }

      // 6. Token refresh → keep backend in sync
      fcm.onTokenRefresh.listen((token) {
        debugPrint("FCM token refreshed: ${token.substring(0, 12)}...");
        syncTokenWithBackend(force: true);
      });

      _initialized = true;
      debugPrint(
        "\n🔔 ================================================\n"
        "🔔 PushNotificationService initialized successfully.\n"
        "🔔 ================================================\n",
      );

      // Log token so we can verify in device logs
      final token = await getFcmToken();
      if (token != null) {
        debugPrint(
          "\n🔑 ================================================\n"
          "🔑 MY DEVICE FCM TOKEN:\n"
          "🔑 $token\n"
          "🔑 ================================================\n",
        );
      } else {
        debugPrint(
          "\n🔔 ================================================\n"
          "🔔 FCM TOKEN IS NULL (Check APNs / Play Services)\n"
          "🔔 ================================================\n",
        );
      }
    } catch (e, st) {
      debugPrint("PushNotificationService initialization warning/failed: $e");
      debugPrint("$st");
    }
  }

  Future<String?> getFcmToken() async {
    try {
      final fcm = _fcm;
      if (fcm == null) return null;

      // iOS needs an APNs token before FCM token is available.
      if (Platform.isIOS) {
        String? apns = await fcm.getAPNSToken();
        for (var i = 0; i < 10 && apns == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          apns = await fcm.getAPNSToken();
        }
        if (apns == null) {
          debugPrint(
            "APNs token still null — push may fail on simulator or without Push capability.",
          );
        }
      }

      return await fcm.getToken();
    } catch (e) {
      debugPrint("Error getting FCM Token: $e");
      return null;
    }
  }

  void _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) {
      // Data-only messages: still surface a basic local notification if title exists
      final title = message.data['title']?.toString();
      final body = message.data['body']?.toString() ??
          message.data['message']?.toString();
      if (title == null && body == null) return;
      await _showLocal(
        title: title ?? 'Welfog',
        body: body ?? '',
        payload: jsonEncode(message.data),
      );
      return;
    }

    await _showLocal(
      title: notification.title ?? 'Welfog',
      body: notification.body ?? '',
      payload: jsonEncode(message.data),
    );
  }

  Future<void> _showLocal({
    required String title,
    required String body,
    required String payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'welfog_default_channel',
      'Default Notifications',
      channelDescription:
          'This channel is used for order and promotional notifications.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      id: title.hashCode ^ body.hashCode,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Sync push token with server database.
  Future<void> syncTokenWithBackend({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString("user_id");
      if (userId == null || userId.isEmpty) {
        debugPrint("FCM sync skipped: no user_id");
        return;
      }

      final String? token = await getFcmToken();
      if (token == null || token.isEmpty) {
        debugPrint("FCM sync skipped: no token");
        return;
      }

      final String deviceId = await play.DeviceIdStore.getOrCreate();
      final String platform = Platform.isAndroid ? "android" : "ios";

      final lastToken = prefs.getString('last_push_token');
      
      debugPrint(
        "\n💾 ================================================\n"
        "💾 LOCAL DEVICE TOKEN CHECK:\n"
        "💾 Saved Local Token: ${lastToken ?? 'NONE (Empty/Not Stored)'}\n"
        "💾 Current Device FCM Token: $token\n"
        "💾 Is Token Stored and Matched? ${lastToken == token ? 'YES (Matched)' : 'NO (Needs Sync/Missing)'}\n"
        "💾 ================================================\n",
      );

      bool shouldRegister = force || lastToken != token;

      if (!shouldRegister) {
        final statusUrl = Uri.parse(
          'https://welfogapi.welfog.com/api/notification/token-status?user_id=$userId&device_id=$deviceId',
        );
        debugPrint("💾 Checking token registration status on server: $statusUrl");
        final checkRes = await http.get(statusUrl);

        if (checkRes.statusCode == 200) {
          final Map<String, dynamic> checkData = jsonDecode(checkRes.body);
          if (checkData['status'] == 'active' ||
              checkData['registered'] == true) {
            shouldRegister = false;
            debugPrint("💾 Server reports token is already active/registered.");
          } else {
            shouldRegister = true;
            debugPrint("💾 Server reports token is inactive or not registered.");
          }
        } else {
          shouldRegister = true;
          debugPrint("💾 Server status check failed (status: ${checkRes.statusCode}). Forcing register.");
        }
      }

      if (!shouldRegister) {
        debugPrint("💾 FCM sync skipped: Token is already saved locally and registered on server.");
        return;
      }

      debugPrint("💾 Fetching and saving new token to backend server...");

      final saveUrl =
          Uri.parse('https://welfogapi.welfog.com/api/notification/save-token');
      final saveRes = await http.post(
        saveUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'device_id': deviceId,
          'push_token': token,
          'platform': platform,
          'app_version': '1.2.0',
        }),
      );
      debugPrint(
        "\n🚀 ================================================\n"
        "🚀 FCM TOKEN SYNC DETAILS:\n"
        "🚀 URL: $saveUrl\n"
        "🚀 User ID: $userId\n"
        "🚀 Device ID: $deviceId\n"
        "🚀 Response Status Code: ${saveRes.statusCode}\n"
        "🚀 Response Body: ${saveRes.body}\n"
        "🚀 ================================================\n",
      );
      if (saveRes.statusCode >= 200 && saveRes.statusCode < 300) {
        try {
          final Map<String, dynamic> resData = jsonDecode(saveRes.body);
          if (resData['status'] == 200 || resData['status'] == null) {
            await prefs.setString('last_push_token', token);
            debugPrint(
              "\n💾 ================================================\n"
              "💾 LOCAL STORAGE SUCCESS:\n"
              "💾 FCM Token has been saved to SharedPreferences.\n"
              "💾 Key: last_push_token\n"
              "💾 Value: $token\n"
              "💾 ================================================\n",
            );
          } else {
            debugPrint(
              "\n❌ ================================================\n"
              "❌ SERVER REJECTED TOKEN SYNC:\n"
              "❌ Body: ${saveRes.body}\n"
              "❌ ================================================\n",
            );
          }
        } catch (_) {
          await prefs.setString('last_push_token', token);
          debugPrint("💾 Error parsing response body, but saved token locally anyway.");
        }
      }
    } catch (e) {
      debugPrint("FCM Sync Error: $e");
    }
  }
}

class NotificationPermissionRationaleSheet extends StatelessWidget {
  const NotificationPermissionRationaleSheet({super.key});

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

          // Bell icon with orange glow
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: const Color(0xFFFF6A00).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Color(0xFFFF6A00),
              size: 38,
            ),
          ),
          const SizedBox(height: 20),

          // Title
          const Text(
            'Enable Notifications',
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
            'Stay updated with your orders, delivery status, and exclusive offers.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF555555),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Benefit points
          _buildPoint(Icons.local_shipping_outlined, 'Real-time order and delivery tracking'),
          _buildPoint(Icons.local_offer_outlined, 'Exclusive deals and discount offers'),
          _buildPoint(Icons.chat_bubble_outline_rounded, 'Instant updates on customer support'),
          const SizedBox(height: 28),

          // Action buttons
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFB5404),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Allow Notifications',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Maybe Later',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoint(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFFB5404)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF333333),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
