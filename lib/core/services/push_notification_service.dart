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

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final fcm = _fcm;
      if (fcm == null) {
        debugPrint(
          "PushNotificationService: Firebase not initialized. Skipping setup.",
        );
        return;
      }

      // 1. Request user permission
      final settings = await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint(
        "Push permission status: ${settings.authorizationStatus}",
      );

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
      debugPrint("PushNotificationService initialized successfully.");

      // Log token so we can verify in device logs
      final token = await getFcmToken();
      if (token != null) {
        debugPrint("FCM token ready: ${token.substring(0, 12)}...");
      } else {
        debugPrint("FCM token is null (check APNs / Play Services).");
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
      bool shouldRegister = force || lastToken != token;

      if (!shouldRegister) {
        final statusUrl = Uri.parse(
          'https://welfogapi.welfog.com/api/notification/token-status?user_id=$userId&device_id=$deviceId',
        );
        final checkRes = await http.get(statusUrl);

        if (checkRes.statusCode == 200) {
          final Map<String, dynamic> checkData = jsonDecode(checkRes.body);
          if (checkData['status'] == 'active' ||
              checkData['registered'] == true) {
            shouldRegister = false;
          } else {
            shouldRegister = true;
          }
        } else {
          shouldRegister = true;
        }
      }

      if (!shouldRegister) {
        debugPrint("FCM sync: token already active on server");
        return;
      }

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
        "FCM sync save status=${saveRes.statusCode} body=${saveRes.body}",
      );
      if (saveRes.statusCode >= 200 && saveRes.statusCode < 300) {
        await prefs.setString('last_push_token', token);
      }
    } catch (e) {
      debugPrint("FCM Sync Error: $e");
    }
  }
}
