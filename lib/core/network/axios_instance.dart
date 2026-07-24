import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AxiosClient {
  final String baseURL;
  final Duration timeout;

  AxiosClient({
    required this.baseURL,
    this.timeout = const Duration(seconds: 10),
  });

  /// Helper to get or dynamically create a persistent device identifier.
  Future<String> _getOrCreateDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('x-device-id');
      if (deviceId == null) {
        final random = Random();
        final randomStr = String.fromCharCodes(
          List.generate(
              8, (_) => random.nextInt(26) + 97), // random a-z characters
        );
        deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}_$randomStr';
        await prefs.setString('x-device-id', deviceId);
      }
      return deviceId;
    } catch (e) {
      debugPrint('Error getting device ID: $e');
      return 'device_fallback_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Appends standard device and platform identification headers.
  Future<Map<String, String>> _buildHeaders(
      Map<String, String>? userHeaders) async {
    final headers = <String, String>{};
    if (userHeaders != null) {
      headers.addAll(userHeaders);
    }

    final deviceId = await _getOrCreateDeviceId();
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        headers['x-android-id'] = deviceId;
      } else if (Platform.isIOS) {
        headers['x-ios-idfv'] = deviceId;
      } else {
        headers['x-device-id'] = deviceId;
      }
    } else {
      headers['x-device-id'] = deviceId;
    }

    return headers;
  }

  /// Perform a GET request.
  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    final uri = Uri.parse('$baseURL$path');
    final finalHeaders = await _buildHeaders(headers);
    return http.get(uri, headers: finalHeaders).timeout(timeout);
  }

  /// Perform a POST request.
  Future<http.Response> post(String path,
      {Object? body, Map<String, String>? headers}) async {
    final uri = Uri.parse('$baseURL$path');
    final finalHeaders = await _buildHeaders(headers);

    Object? finalBody = body;
    if (body is Map) {
      finalBody = jsonEncode(body);
      if (!finalHeaders.containsKey('Content-Type') &&
          !finalHeaders.containsKey('content-type')) {
        finalHeaders['Content-Type'] = 'application/json';
      }
    }

    return http
        .post(uri, headers: finalHeaders, body: finalBody)
        .timeout(timeout);
  }

  /// Perform a PUT request.
  Future<http.Response> put(String path,
      {Object? body, Map<String, String>? headers}) async {
    final uri = Uri.parse('$baseURL$path');
    final finalHeaders = await _buildHeaders(headers);

    Object? finalBody = body;
    if (body is Map) {
      finalBody = jsonEncode(body);
      if (!finalHeaders.containsKey('Content-Type') &&
          !finalHeaders.containsKey('content-type')) {
        finalHeaders['Content-Type'] = 'application/json';
      }
    }

    return http
        .put(uri, headers: finalHeaders, body: finalBody)
        .timeout(timeout);
  }

  /// Perform a DELETE request.
  Future<http.Response> delete(String path,
      {Object? body, Map<String, String>? headers}) async {
    final uri = Uri.parse('$baseURL$path');
    final finalHeaders = await _buildHeaders(headers);

    Object? finalBody = body;
    if (body is Map) {
      finalBody = jsonEncode(body);
      if (!finalHeaders.containsKey('Content-Type') &&
          !finalHeaders.containsKey('content-type')) {
        finalHeaders['Content-Type'] = 'application/json';
      }
    }

    return http
        .delete(uri, headers: finalHeaders, body: finalBody)
        .timeout(timeout);
  }
}

class AxiosInstance {
  static const baseUrls = {
    'MAIN': "https://welfogapi.welfog.com/api/v2",
    'SECOND': "https://welfogapi.welfog.com/api",
    'THIRD': "https://supplier.cruxmall.com",

    // Toggle these URLs for local vs live development of the fourth API
    // 'FOURTH': "https://unnecessitous-domitila-unbudging.ngrok-free.dev/api",
    // 'FOURTH': "http://192.168.1.12:4000/api",
    'FOURTH': "https://api.welfog.com/api",

    'FIFTH': "https://supplier.welfog.com/api/"
  };

  static final mainAPI = AxiosClient(baseURL: baseUrls['MAIN']!);
  static final secondAPI = AxiosClient(baseURL: baseUrls['SECOND']!);
  static final thirdAPI = AxiosClient(baseURL: baseUrls['THIRD']!);
  static final fourthAPI = AxiosClient(baseURL: baseUrls['FOURTH']!);
  static final fifthAPI = AxiosClient(baseURL: baseUrls['FIFTH']!);
}
