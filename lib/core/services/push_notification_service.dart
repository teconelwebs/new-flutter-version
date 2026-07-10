import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:welfog_flutter_play/welfog_flutter_play.dart' as play;

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  FirebaseMessaging? get _fcm {
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
        debugPrint("PushNotificationService: Firebase not initialized. Skipping setup.");
        return;
      }
      // 1. Request user permission
      await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // 2. Initialize local notifications for Android foreground displaying
      const androidInit = AndroidInitializationSettings('ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

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

      // Create local Android channel
      if (Platform.isAndroid) {
        const channel = AndroidNotificationChannel(
          'welfog_default_channel',
          'Default Notifications',
          description: 'This channel is used for order and promotional notifications.',
          importance: Importance.max,
          playSound: true,
        );
        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }

      // 3. Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showForegroundNotification(message);
      });

      // 4. Background message listener (App in background, not terminated)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (onNotificationTapped != null) {
          onNotificationTapped!(message.data);
        }
      });

      // 5. Initial message check (App terminated cold start)
      final initialMessage = await fcm.getInitialMessage();
      if (initialMessage != null && onNotificationTapped != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onNotificationTapped!(initialMessage.data);
        });
      }

      _initialized = true;
      debugPrint("PushNotificationService initialized successfully.");
    } catch (e) {
      debugPrint("PushNotificationService initialization warning/failed: $e");
    }
  }

  Future<String?> getFcmToken() async {
    try {
      final fcm = _fcm;
      if (fcm == null) return null;
      return await fcm.getToken();
    } catch (e) {
      debugPrint("Error getting FCM Token: $e");
      return null;
    }
  }

  void _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'welfog_default_channel',
      'Default Notifications',
      channelDescription: 'This channel is used for order and promotional notifications.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: details,
      payload: jsonEncode(message.data),
    );
  }

  /// Sync push token with server database
  Future<void> syncTokenWithBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString("user_id");
      if (userId == null || userId.isEmpty) {
        return;
      }

      final String? token = await getFcmToken();
      if (token == null || token.isEmpty) {
        return;
      }

      final String deviceId = await play.DeviceIdStore.getOrCreate();
      final String platform = Platform.isAndroid ? "android" : "ios";

      // Query token status
      final statusUrl = Uri.parse(
        'https://welfogapi.welfog.com/api/notification/token-status?user_id=$userId&device_id=$deviceId',
      );
      final checkRes = await http.get(statusUrl);
      
      bool shouldRegister = true;
      if (checkRes.statusCode == 200) {
        final Map<String, dynamic> checkData = jsonDecode(checkRes.body);
        if (checkData['status'] == 'active' || checkData['registered'] == true) {
          shouldRegister = false;
        }
      }

      if (shouldRegister) {
        final saveUrl = Uri.parse('https://welfogapi.welfog.com/api/notification/save-token');
        await http.post(
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
      }
    } catch (e) {
      debugPrint("FCM Sync Error: $e");
    }
  }
}
