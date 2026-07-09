import 'dart:convert';

import 'package:http/http.dart' as http;

class LoginService {
  static const String _baseUrl = 'https://welfogapi.welfog.com/api/v2';

  Future<SendOtpResult> sendOtp(String phoneNumber) async {
    final uri = Uri.parse(
      '$_baseUrl/buyerverifynumber',
    ).replace(queryParameters: {'phone': phoneNumber});

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return const SendOtpResult(errorMessage: 'Unable to send OTP. Please try again.');
      }

      final dynamic data = _decodeSafely(response.body);
      final status = (data is Map<String, dynamic>)
          ? (data['account_status']?.toString() ?? '')
          : '';

      if (status == 'banned') {
        final msg = data is Map<String, dynamic>
            ? (data['message']?.toString() ?? 'Your account is suspended.')
            : 'Your account is suspended.';
        return SendOtpResult(
          errorMessage: msg,
          accountStatus: 'banned',
        );
      }

      if (status == 'deleted') {
        final deletedDate = data is Map<String, dynamic>
            ? (data['deleted_date']?.toString() ?? '')
            : '';
        return SendOtpResult(
          errorMessage: 'Account was deleted. Please contact support.',
          accountStatus: 'deleted',
          deletedDate: deletedDate,
        );
      }

      return const SendOtpResult(accountStatus: 'active');
    } catch (_) {
      return const SendOtpResult(errorMessage: 'Unable to send OTP. Please try again.');
    }
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

    final account = data['account']?.toString() ?? 'login';

    if (accessToken.isEmpty || userId.isEmpty) {
      return const VerifyOtpResult(
        errorMessage: 'Login data missing from server response.',
      );
    }

    return VerifyOtpResult(
      accessToken: accessToken,
      userId: userId,
      userName: userName,
      account: account,
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
    this.account = '',
  });

  final String? errorMessage;
  final String accessToken;
  final String userId;
  final String userName;
  final String account;
}

class SendOtpResult {
  const SendOtpResult({
    this.errorMessage,
    this.accountStatus,
    this.deletedDate,
  });

  final String? errorMessage;
  final String? accountStatus;
  final String? deletedDate;
}

