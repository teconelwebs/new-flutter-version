import 'dart:convert';

import 'package:http/http.dart' as http;

const _mainBaseUrl = 'https://welfogapi.welfog.com/api/v2';

class OtpSendResult {
  final bool success;
  final String? message;
  final String? accountStatus;

  const OtpSendResult({
    required this.success,
    this.message,
    this.accountStatus,
  });
}

/// Login OTP APIs reused for play-profile mobile verification.
class AuthApi {
  AuthApi({required this.deviceId});

  final String deviceId;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (deviceId.isNotEmpty) 'x-android-id': deviceId,
      };

  Future<OtpSendResult> sendOtp(String phone) async {
    final response = await http.get(
      Uri.parse('$_mainBaseUrl/buyerverifynumber').replace(
        queryParameters: {'phone': phone},
      ),
      headers: _headers,
    );

    Map<String, dynamic>? data;
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return OtpSendResult(
        success: false,
        message: data?['message']?.toString() ?? 'Unable to send OTP. Please try again.',
      );
    }

    final status = data?['account_status']?.toString();
    if (status == 'banned') {
      return OtpSendResult(
        success: false,
        accountStatus: status,
        message: data?['message']?.toString() ??
            'This number is suspended. Please contact support.',
      );
    }
    if (status == 'deleted') {
      return OtpSendResult(
        success: false,
        accountStatus: status,
        message: data?['message']?.toString() ??
            'This number was deleted. Please use another number.',
      );
    }

    return const OtpSendResult(success: true);
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    final response = await http.get(
      Uri.parse('$_mainBaseUrl/usercheckVerifyOtp').replace(
        queryParameters: {'phone': phone, 'otp': otp},
      ),
      headers: _headers,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) return false;

    final body = jsonDecode(response.body);
    if (body is! Map) return false;
    return body['result'] == true;
  }
}

String normalizeIndianMobile(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length > 10 && digits.startsWith('91')) {
    digits = digits.substring(digits.length - 10);
  }
  return digits;
}

bool isValidIndianMobile(String value) {
  return RegExp(r'^[6-9]\d{9}$').hasMatch(normalizeIndianMobile(value));
}

String formatMobileDisplay(String value) {
  final digits = normalizeIndianMobile(value);
  if (digits.length != 10) return value.trim();
  return '+91 $digits';
}
