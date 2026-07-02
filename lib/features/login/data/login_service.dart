import 'dart:convert';

import 'package:http/http.dart' as http;

class LoginService {
  static const String _baseUrl = 'https://welfogapi.welfog.com/api/v2';

  Future<String?> sendOtp(String phoneNumber) async {
    final uri = Uri.parse(
      '$_baseUrl/buyerverifynumber',
    ).replace(queryParameters: {'phone': phoneNumber});

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      return 'Unable to send OTP. Please try again.';
    }

    final dynamic data = _decodeSafely(response.body);
    final status = (data is Map<String, dynamic>)
        ? (data['account_status']?.toString() ?? '')
        : '';

    if (status == 'banned') {
      return data is Map<String, dynamic>
          ? (data['message']?.toString() ?? 'Your account is suspended.')
          : 'Your account is suspended.';
    }

    if (status == 'deleted') {
      return 'Account was deleted. Please contact support.';
    }

    return null;
  }

  Future<VerifyOtpResult> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/usercheckVerifyOtp',
    ).replace(queryParameters: {'phone': phoneNumber, 'otp': otp});

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      return const VerifyOtpResult(
        errorMessage: 'OTP verification failed. Please try again.',
      );
    }

    final dynamic data = _decodeSafely(response.body);
    if (data is! Map<String, dynamic> || data['result'] != true) {
      return const VerifyOtpResult(errorMessage: 'Invalid OTP. Please try again.');
    }

    final accessToken = data['access_token']?.toString() ?? '';
    final userMap = data['user'];
    final userId = userMap is Map<String, dynamic>
        ? userMap['id']?.toString() ?? ''
        : '';
    final userName = userMap is Map<String, dynamic>
        ? userMap['name']?.toString() ?? ''
        : '';

    if (accessToken.isEmpty || userId.isEmpty) {
      return const VerifyOtpResult(
        errorMessage: 'Login data missing from server response.',
      );
    }

    return VerifyOtpResult(
      accessToken: accessToken,
      userId: userId,
      userName: userName,
    );
  }

  dynamic _decodeSafely(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}

class VerifyOtpResult {
  const VerifyOtpResult({
    this.errorMessage,
    this.accessToken = '',
    this.userId = '',
    this.userName = '',
  });

  final String? errorMessage;
  final String accessToken;
  final String userId;
  final String userName;
}
