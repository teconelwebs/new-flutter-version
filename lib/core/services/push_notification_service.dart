import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:welfog_flutter_play/welfog_flutter_play.dart' as play;

import '../constants/app_routes.dart';
import '../navigation/app_navigator.dart';
import '../../features/checkout/presentation/order_success_screen.dart';

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
  bool _homeReady = false;
  void Function(Map<String, dynamic> data)? _onNotificationTapped;
  Map<String, dynamic>? pendingNotificationData;

  /// Recently handled message ids — stops duplicate banners / double navigation.
  final Set<String> _recentMessageIds = {};
  DateTime? _lastRoutedAt;
  String? _lastRoutedFingerprint;

  void Function(Map<String, dynamic> data)? get onNotificationTapped =>
      _onNotificationTapped;

  set onNotificationTapped(void Function(Map<String, dynamic> data)? callback) {
    _onNotificationTapped = callback;
    if (callback != null) {
      flushPendingNavigation();
    }
  }

  /// Call once Home (or main shell) is on screen and can accept routes.
  void markHomeReady() {
    _homeReady = true;
    flushPendingNavigation();
  }

  void markHomeNotReady() {
    _homeReady = false;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    if (Isolate.current.debugName != 'main' ||
        PlatformDispatcher.instance.views.isEmpty) {
      debugPrint(
        "🔔 Skipping PushNotificationService.initialize in background isolate (${Isolate.current.debugName}) or non-UI context.",
      );
      return;
    }

    try {
      final fcm = _fcm;
      if (fcm == null) {
        debugPrint(
          "PushNotificationService: Firebase not initialized. Skipping setup.",
        );
        return;
      }

      // IMPORTANT (iOS): do NOT also show system foreground banners.
      // We render one local notification ourselves so taps carry full data
      // and the same alert is not shown twice.
      await fcm.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
      );
      const initSettings =
          InitializationSettings(android: androidInit, iOS: iosInit);

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          try {
            final Map<String, dynamic> data =
                Map<String, dynamic>.from(jsonDecode(payload) as Map);
            debugPrint("🔔 Local notification tapped: $data");
            _queueOrRoute(data);
          } catch (e) {
            debugPrint("Error parsing notification tap payload: $e");
          }
        },
      );

      if (Platform.isAndroid) {
        const channel = AndroidNotificationChannel(
          'welfog_default_channel',
          'Default Notifications',
          description:
              'Order, promotional, and Play (follow/like/comment) notifications.',
          importance: Importance.max,
          playSound: true,
        );
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
          "FCM foreground: id=${message.messageId} title=${message.notification?.title}, data=${message.data}",
        );
        _showForegroundNotification(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint(
          "FCM opened from background: id=${message.messageId} data=${message.data}",
        );
        _queueOrRoute(_normalizeMessageData(message));
      });

      // Cold start from FCM
      final initialMessage = await fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
          "FCM initial message found: id=${initialMessage.messageId} data=${initialMessage.data}",
        );
        _storePending(_normalizeMessageData(initialMessage));
      }

      // Cold start from a local notification — only if we don't already have FCM data.
      final NotificationAppLaunchDetails? launchDetails =
          await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails != null &&
          launchDetails.didNotificationLaunchApp &&
          launchDetails.notificationResponse?.payload != null) {
        try {
          final Map<String, dynamic> data = Map<String, dynamic>.from(
            jsonDecode(launchDetails.notificationResponse!.payload!) as Map,
          );
          debugPrint("Local notification launch payload found: $data");
          if (pendingNotificationData == null ||
              pendingNotificationData!.isEmpty) {
            _storePending(data);
          }
        } catch (e) {
          debugPrint("Error parsing launch notification payload: $e");
        }
      }

      fcm.onTokenRefresh.listen((token) {
        debugPrint("FCM token refreshed: ${token.substring(0, 12)}...");
        syncTokenWithBackend(force: true);
      });

      _initialized = true;

      final token = await getFcmToken();
      if (token != null) {
        debugPrint(
          "\n🔑 ================================================\n"
          "🔑 MY DEVICE FCM TOKEN:\n"
          "🔑 $token\n"
          "🔑 ================================================\n",
        );
      } else {
        debugPrint("🔔 FCM TOKEN IS NULL (Check APNs / Play Services)\n");
      }
    } catch (e, st) {
      debugPrint("PushNotificationService initialization warning/failed: $e");
      debugPrint("$st");
    }
  }

  /// Re-check cold-start message after UI is up (iOS sometimes misses early read).
  Future<void> refreshInitialMessage() async {
    try {
      final fcm = _fcm;
      if (fcm == null) return;
      final initialMessage = await fcm.getInitialMessage();
      if (initialMessage == null) return;
      debugPrint(
        "FCM initial message (refresh): id=${initialMessage.messageId} data=${initialMessage.data}",
      );
      _queueOrRoute(_normalizeMessageData(initialMessage));
    } catch (e) {
      debugPrint("refreshInitialMessage error: $e");
    }
  }

  void flushPendingNavigation() {
    final data = pendingNotificationData;
    if (data == null) return;
    if (appNavigatorKey.currentState == null) {
      debugPrint("🔔 flushPending skipped — navigator not ready yet");
      return;
    }
    pendingNotificationData = null;
    debugPrint("🔔 flushPending → routing stored notification");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeNotification(data);
    });
  }

  void _storePending(Map<String, dynamic> data) {
    pendingNotificationData = data;
  }

  void _queueOrRoute(Map<String, dynamic> data) {
    final normalized = _normalizeDataMap(data);
    final navReady = appNavigatorKey.currentState != null;
    debugPrint(
      "🔔 queueOrRoute homeReady=$_homeReady navReady=$navReady data=$normalized",
    );
    // Do NOT require _homeReady — checkout can dispose Home briefly.
    // As long as the root navigator exists we can open My Orders.
    if (!navReady) {
      debugPrint("🔔 Navigator missing — storing pending notification");
      _storePending(normalized);
      return;
    }
    _routeNotification(normalized);
  }

  Map<String, dynamic> _normalizeMessageData(RemoteMessage message) {
    final merged = <String, dynamic>{
      ...message.data,
      if (message.messageId != null) 'messageId': message.messageId,
      if (message.notification?.title != null)
        'title': message.notification!.title,
      if (message.notification?.body != null)
        'body': message.notification!.body,
    };
    return _normalizeDataMap(merged);
  }

  Map<String, dynamic> _normalizeDataMap(Map<String, dynamic> raw) {
    final out = <String, dynamic>{};
    raw.forEach((key, value) {
      out[key.toString()] = value;
    });

    // Some backends nest custom fields inside a JSON "data" string.
    final nested = out['data'];
    if (nested is String && nested.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(nested);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            out.putIfAbsent(k.toString(), () => v);
          });
        }
      } catch (_) {}
    } else if (nested is Map) {
      nested.forEach((k, v) {
        out.putIfAbsent(k.toString(), () => v);
      });
    }

    return out;
  }

  /// Case-insensitive lookup for backend keys like `Type` vs `type`.
  dynamic _dataValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (data.containsKey(key)) return data[key];
    }
    final lowerMap = <String, dynamic>{};
    data.forEach((k, v) {
      lowerMap[k.toLowerCase()] = v;
    });
    for (final key in keys) {
      final hit = lowerMap[key.toLowerCase()];
      if (hit != null) return hit;
    }
    return null;
  }

  static const _playSocialTypes = {
    'follow',
    'like',
    'comment',
    'comment_reply',
    'comment_like',
  };

  bool _isPlaySocialType(String typeStr) =>
      _playSocialTypes.contains(typeStr.trim().toLowerCase());

  /// FCM data values are often strings; treat null / "null" / empty as missing.
  String _cleanId(dynamic value) {
    if (value == null) return '';
    if (value is Map) {
      return _cleanId(value['id'] ?? value['_id']);
    }
    final s = value.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null' || s == 'undefined') {
      return '';
    }
    return s;
  }

  String _contentFingerprint(Map<String, dynamic> data) {
    final type = (_dataValue(data, [
              'notificationFor',
              'notification_for',
              'type',
              'Type',
              'play_type',
              'playType',
              'target',
              'screen',
            ]) ??
            '')
        .toString()
        .toLowerCase();

    // Play social: fingerprint on type + reel/sender so order ids don't collide.
    if (_isPlaySocialType(type)) {
      final reel = _cleanId(
        _dataValue(data, ['reel', 'reelId', 'reel_id']),
      );
      final sender = _cleanId(
        _dataValue(data, [
          'senderObjectId',
          'sender_object_id',
          'senderUserId',
          'sender_user_id',
        ]),
      );
      final comment = _cleanId(
        _dataValue(data, ['comment', 'commentId', 'comment_id']),
      );
      return 'play|$type|$reel|$sender|$comment';
    }

    final id = (_dataValue(data, [
              'linkId',
              'oid',
              'orderId',
              'order_id',
              'id',
              'order_code',
              'orderCode',
            ]) ??
            '')
        .toString();
    final title = (data['title'] ?? '').toString();
    final body = (data['body'] ?? data['message'] ?? '').toString();
    return '$type|$id|$title|$body';
  }

  bool _isDuplicateRoute(Map<String, dynamic> data) {
    final fingerprint = _contentFingerprint(data);
    final now = DateTime.now();
    if (_lastRoutedFingerprint == fingerprint &&
        _lastRoutedAt != null &&
        now.difference(_lastRoutedAt!) < const Duration(seconds: 4)) {
      return true;
    }
    _lastRoutedAt = now;
    _lastRoutedFingerprint = fingerprint;
    return false;
  }

  final Set<String> _recentContentFingerprints = {};

  bool _shouldSkipDuplicateContent(Map<String, dynamic> data, {String? messageId}) {
    if (messageId != null && messageId.isNotEmpty) {
      if (_recentMessageIds.contains(messageId)) return true;
      _recentMessageIds.add(messageId);
      if (_recentMessageIds.length > 40) {
        _recentMessageIds.remove(_recentMessageIds.first);
      }
    }

    // Server often sends 2 FCM messages for one order (different messageIds).
    final contentKey = _contentFingerprint(data);
    if (_recentContentFingerprints.contains(contentKey)) {
      debugPrint("🔔 Skipping duplicate content notification: $contentKey");
      return true;
    }
    _recentContentFingerprints.add(contentKey);
    if (_recentContentFingerprints.length > 40) {
      _recentContentFingerprints.remove(_recentContentFingerprints.first);
    }
    return false;
  }

  Future<void> _routeNotification(Map<String, dynamic> data) async {
    if (_isDuplicateRoute(data)) {
      debugPrint("🔔 Duplicate notification route ignored: $data");
      return;
    }

    for (var attempt = 0; attempt < 30; attempt++) {
      final nav = appNavigatorKey.currentState;
      if (nav != null) {
        try {
          final routed = _pushRoute(nav, data);
          if (routed) {
            debugPrint("🔔 Notification routed successfully (attempt $attempt)");
            return;
          }
        } catch (e, st) {
          debugPrint("🔔 Notification route error: $e\n$st");
        }
      } else {
        debugPrint("🔔 Waiting for navigator... attempt $attempt");
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    _storePending(data);
    debugPrint("🔔 Notification route deferred (navigator not ready): $data");
  }

  bool _pushRoute(NavigatorState nav, Map<String, dynamic> data) {
    debugPrint("🔔 [Notification Routing] Received payload data: $data");

    final typeForRouting = _dataValue(data, [
      'notificationFor',
      'notification_for',
      'type',
      'Type',
      'play_type',
      'playType',
      'target',
      'screen',
      'click_action',
    ]);
    final typeStr = (typeForRouting ?? '').toString().trim().toLowerCase();

    final trackingId = _dataValue(data, [
      'oid',
      'orderId',
      'order_id',
      'id',
      'linkId',
      'order_code',
      'orderCode',
    ]);
    final oidStr = _cleanId(trackingId);
    debugPrint(
      "🔔 [Notification Routing] Parsed typeStr: '$typeStr', oidStr: '$oidStr'",
    );

    // Play social (follow / like / comment*) — exact types only so order
    // notifications never get swallowed by contains('like').
    if (_isPlaySocialType(typeStr)) {
      final ok = _routePlaySocialNotification(nav, data, typeStr);
      if (!ok) {
        debugPrint(
          "🔔 Play social type='$typeStr' missing target ids — skipping nav",
        );
      }
      // Type was recognized; always consume so we don't retry / fall to orders.
      return true;
    }

    // Explicit marketing / catalog types before order fallback.
    switch (typeStr) {
      case 'home':
        nav.pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
        return true;
      case 'top_deals':
        nav.pushNamed(AppRoutes.todayDeals);
        return true;
      case 'category':
        final categoryId = _dataValue(
            data, ['linkId', 'categoryId', 'id', 'slug']);
        if (categoryId != null && _cleanId(categoryId).isNotEmpty) {
          nav.pushNamed(
            AppRoutes.searchResults,
            arguments: {'query': '', 'categoryId': _cleanId(categoryId)},
          );
        } else {
          nav.pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
        }
        return true;
      case 'product':
        final productIdentifier =
            _dataValue(data, ['linkId', 'productId', 'slug', 'id']);
        if (productIdentifier != null &&
            _cleanId(productIdentifier).isNotEmpty) {
          nav.pushNamed(
            AppRoutes.product,
            arguments: _cleanId(productIdentifier),
          );
          return true;
        }
        break;
    }

    final looksLikeOrder = typeStr.contains('order') ||
        typeStr.contains('track') ||
        typeStr.contains('purchase') ||
        typeStr.contains('payment') ||
        typeStr.contains('delivery') ||
        typeStr == 'my_orders' ||
        typeStr == 'myorders' ||
        (typeForRouting == null && oidStr.isNotEmpty) ||
        typeStr.isEmpty;

    if (looksLikeOrder) {
      _openOrdersScreen(nav);
      return true;
    }

    _openOrdersScreen(nav);
    return true;
  }

  /// Routes Play FCM payloads to profile / reel screens (Android + iOS).
  ///
  /// Expected data shape:
  /// ```json
  /// {
  ///   "recipientUserId": "1195",
  ///   "senderUserId": "1742",
  ///   "recipientObjectId": "...",
  ///   "senderObjectId": "...",
  ///   "type": "follow|like|comment|comment_reply|comment_like",
  ///   "reel": "..."|null,
  ///   "comment": "..."|null,
  ///   "message": "..."
  /// }
  /// ```
  bool _routePlaySocialNotification(
    NavigatorState nav,
    Map<String, dynamic> data,
    String typeStr,
  ) {
    debugPrint("🔔 [Play Social] routing type=$typeStr");

    if (typeStr == 'follow') {
      // Prefer mongo ObjectId — OtherProfileScreen resolves via play API.
      final profileId = _cleanId(
        _dataValue(data, [
          'senderObjectId',
          'sender_object_id',
          'senderUserId',
          'sender_user_id',
          'senderId',
          'sender_id',
          'userId',
          'user_id',
        ]),
      );
      if (profileId.isEmpty) {
        debugPrint("🔔 [Play Social] follow missing sender id");
        return false;
      }
      debugPrint("🔔 [Play Social] → OtheruserProfile/$profileId");
      nav.pushNamed('/OtheruserProfile/$profileId');
      return true;
    }

    // like | comment | comment_reply | comment_like → open that reel
    final reelId = _cleanId(
      _dataValue(data, ['reel', 'reelId', 'reel_id']),
    );
    if (reelId.isEmpty) {
      debugPrint("🔔 [Play Social] $typeStr missing reel id");
      return false;
    }

    final commentId = _cleanId(
      _dataValue(data, ['comment', 'commentId', 'comment_id']),
    );
    final route = commentId.isNotEmpty
        ? '/sepreel/$reelId?commentId=$commentId'
        : '/sepreel/$reelId';
    debugPrint("🔔 [Play Social] → $route");
    nav.pushNamed(route);
    return true;
  }

  /// Clears checkout/success stack so Orders is not wiped by OrderSuccess timer.
  void _openOrdersScreen(NavigatorState nav) {
    try {
      OrderSuccessScreen.cancelActiveTimer();
    } catch (err) {
      debugPrint("Error cancelling success screen timer: $err");
    }

    nav.pushNamedAndRemoveUntil(
      AppRoutes.orders,
      (route) => false,
      arguments: {'fromNotification': true},
    );
  }

  Future<void> requestPermissions() async {
    try {
      final fcm = _fcm;
      if (fcm == null) return;

      await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (Platform.isAndroid) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint("Error requesting notification permissions: $e");
    }
  }

  Future<String?> getFcmToken() async {
    try {
      final fcm = _fcm;
      if (fcm == null) return null;

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
    final data = _normalizeMessageData(message);
    final messageId = message.messageId;
    if (_shouldSkipDuplicateContent(data, messageId: messageId)) {
      debugPrint("🔔 Skipping duplicate foreground message: $messageId");
      return;
    }

    final notification = message.notification;

    final title = notification?.title?.toString() ??
        data['title']?.toString() ??
        'Welfog';
    final body = notification?.body?.toString() ??
        data['body']?.toString() ??
        data['message']?.toString() ??
        '';

    if ((notification == null) &&
        (data['title'] == null &&
            data['body'] == null &&
            data['message'] == null)) {
      return;
    }

    // Stable id from order/content so a second FCM for the same order
    // updates/replaces the first banner instead of stacking another one.
    final stableId = _notificationIdForContent(data, title, body);

    await _showLocal(
      id: stableId,
      title: title,
      body: body.isEmpty ? 'You have a new update' : body,
      payload: jsonEncode(data),
    );
  }

  int _notificationIdForContent(
    Map<String, dynamic> data,
    String title,
    String body,
  ) {
    final fingerprint = _contentFingerprint(data);
    if (fingerprint.replaceAll('|', '').isNotEmpty) {
      return fingerprint.hashCode & 0x7fffffff;
    }
    return (title.hashCode ^ body.hashCode) & 0x7fffffff;
  }

  Future<void> _showLocal({
    required int id,
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
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

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
        debugPrint(
            "💾 Checking token registration status on server: $statusUrl");
        final checkRes = await http.get(statusUrl);

        if (checkRes.statusCode == 200) {
          final Map<String, dynamic> checkData = jsonDecode(checkRes.body);
          if (checkData['status'] == 'active' ||
              checkData['registered'] == true) {
            shouldRegister = false;
            debugPrint("💾 Server reports token is already active/registered.");
          } else {
            shouldRegister = true;
            debugPrint(
                "💾 Server reports token is inactive or not registered.");
          }
        } else {
          shouldRegister = true;
          debugPrint(
              "💾 Server status check failed (status: ${checkRes.statusCode}). Forcing register.");
        }
      }

      if (!shouldRegister) {
        debugPrint(
            "💾 FCM sync skipped: Token is already saved locally and registered on server.");
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
      if (saveRes.statusCode >= 200 && saveRes.statusCode < 300) {
        try {
          final Map<String, dynamic> resData = jsonDecode(saveRes.body);
          if (resData['status'] == 200 || resData['status'] == null) {
            await prefs.setString('last_push_token', token);
          } else {
            debugPrint("❌ SERVER REJECTED TOKEN SYNC:\n"
                "❌ Body: ${saveRes.body}\n");
          }
        } catch (_) {
          await prefs.setString('last_push_token', token);
          debugPrint(
              "💾 Error parsing response body, but saved token locally anyway.");
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
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),
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
          _buildPoint(Icons.local_shipping_outlined,
              'Real-time order and delivery tracking'),
          _buildPoint(Icons.local_offer_outlined,
              'Exclusive deals and discount offers'),
          _buildPoint(Icons.chat_bubble_outline_rounded,
              'Instant updates on customer support'),
          const SizedBox(height: 28),
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
