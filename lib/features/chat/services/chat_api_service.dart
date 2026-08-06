import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/axios_instance.dart';
import '../data/models/conversation_model.dart';
import '../data/models/message_model.dart';

class ChatApiService {
  static final ChatApiService instance = ChatApiService._internal();
  ChatApiService._internal();

  String? _customBaseUrl;

  void setBaseUrl(String url) {
    var trimmed = url.trim();
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    _customBaseUrl = trimmed;
  }

  String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      if (!_customBaseUrl!.endsWith('/api/chat')) {
        return '$_customBaseUrl/api/chat';
      }
      return _customBaseUrl!;
    }

    final fourth = AxiosInstance.baseUrls['FOURTH'] ?? 'https://unnecessitous-domitila-unbudging.ngrok-free.dev/api';
    var clean = fourth.trim();
    if (clean.endsWith('/api')) {
      clean = clean.substring(0, clean.length - 4);
    }
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return '$clean/api/chat';
  }

  Future<Map<String, String>> _getHeaders([Map<String, String>? custom]) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (custom != null) {
      headers.addAll(custom);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      var deviceId = prefs.getString('x-device-id') ?? '';
      if (deviceId.isEmpty) {
        final randomStr = String.fromCharCodes(
          List.generate(8, (_) => (DateTime.now().microsecond % 26) + 97),
        );
        deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}_$randomStr';
        await prefs.setString('x-device-id', deviceId);
      }

      headers['x-device-id'] = deviceId;
      headers['x-android-id'] = deviceId;
      headers['x-ios-idfv'] = deviceId;
    } catch (e) {
      debugPrint('💬 [ChatApi] Error attaching device headers: $e');
    }

    return headers;
  }

  /// 1. Get or Create 1-on-1 Conversation
  Future<ConversationModel> getOrCreateOneToOneConversation({
    required String userId,
    required String targetUserId,
  }) async {
    final uri = Uri.parse('$baseUrl/conversations/one-to-one');
    final reqHeaders = await _getHeaders();
    final reqBody = jsonEncode({
      'userId': userId,
      'targetUserId': targetUserId,
    });

    debugPrint('💬 [ChatApi] POST $uri');
    debugPrint('💬 [ChatApi] Headers: $reqHeaders');
    debugPrint('💬 [ChatApi] Body: $reqBody');

    final response = await http
        .post(uri, headers: reqHeaders, body: reqBody)
        .timeout(const Duration(seconds: 12));

    debugPrint('💬 [ChatApi] Response (${response.statusCode}): ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      final data = json['data'] ?? json['conversation'] ?? json;
      return ConversationModel.fromJson(data);
    } else {
      String msg = response.body;
      try {
        final errJson = jsonDecode(response.body);
        if (errJson['message'] != null) msg = errJson['message'];
      } catch (_) {}
      throw Exception(msg);
    }
  }

  /// 2. Create Group Conversation
  Future<ConversationModel> createGroupConversation({
    required String creatorId,
    required String groupName,
    String? groupAvatar,
    String? groupDescription,
    required List<String> participantIds,
  }) async {
    final uri = Uri.parse('$baseUrl/conversations/group');
    final reqHeaders = await _getHeaders();
    final reqBody = jsonEncode({
      'creatorId': creatorId,
      'groupName': groupName,
      'groupAvatar': groupAvatar,
      'groupDescription': groupDescription,
      'participantIds': participantIds,
    });

    debugPrint('💬 [ChatApi] POST $uri');
    debugPrint('💬 [ChatApi] Body: $reqBody');

    final response = await http
        .post(uri, headers: reqHeaders, body: reqBody)
        .timeout(const Duration(seconds: 12));

    debugPrint('💬 [ChatApi] Response (${response.statusCode}): ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      final data = json['data'] ?? json['conversation'] ?? json;
      return ConversationModel.fromJson(data);
    } else {
      String msg = response.body;
      try {
        final errJson = jsonDecode(response.body);
        if (errJson['message'] != null) msg = errJson['message'];
      } catch (_) {}
      throw Exception(msg);
    }
  }

  /// 3. Get User Conversations List
  Future<List<ConversationModel>> getConversations(String userId) async {
    final uri = Uri.parse('$baseUrl/conversations?userId=$userId');
    final reqHeaders = await _getHeaders();

    debugPrint('💬 [ChatApi] GET $uri');
    final response = await http.get(uri, headers: reqHeaders).timeout(const Duration(seconds: 12));
    debugPrint('💬 [ChatApi] Response (${response.statusCode}): ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      final List list = json['data'] ?? json['conversations'] ?? (json is List ? json : []);
      return list.map((item) => ConversationModel.fromJson(item)).toList();
    } else {
      String msg = response.body;
      try {
        final errJson = jsonDecode(response.body);
        if (errJson['message'] != null) msg = errJson['message'];
      } catch (_) {}
      throw Exception(msg);
    }
  }

  /// 4. Get Paginated Messages History
  Future<List<MessageModel>> getMessages(
    String conversationId, {
    required String userId,
    int page = 1,
    int limit = 30,
  }) async {
    final uri = Uri.parse('$baseUrl/conversations/$conversationId/messages?userId=$userId&page=$page&limit=$limit');
    final reqHeaders = await _getHeaders();

    debugPrint('💬 [ChatApi] GET $uri');
    final response = await http.get(uri, headers: reqHeaders).timeout(const Duration(seconds: 12));
    debugPrint('💬 [ChatApi] Response (${response.statusCode}): ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      final List list = json['data'] ?? json['messages'] ?? (json is List ? json : []);
      return list.map((item) => MessageModel.fromJson(item)).toList();
    } else {
      String msg = response.body;
      try {
        final errJson = jsonDecode(response.body);
        if (errJson['message'] != null) msg = errJson['message'];
      } catch (_) {}
      throw Exception(msg);
    }
  }

  /// 5. Upload File / Attachment
  Future<Map<String, dynamic>> uploadMedia({
    required String filePath,
    Uint8List? fileBytes,
    required String fileName,
  }) async {
    final uri = Uri.parse('$baseUrl/upload');
    final request = http.MultipartRequest('POST', uri);
    final reqHeaders = await _getHeaders();
    request.headers.addAll(reqHeaders);

    if (fileBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
      ));
    } else {
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: fileName,
      ));
    }

    debugPrint('💬 [ChatApi] POST multipart $uri (file: $fileName)');
    final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);
    debugPrint('💬 [ChatApi] Response (${response.statusCode}): ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      String msg = response.body;
      try {
        final errJson = jsonDecode(response.body);
        if (errJson['message'] != null) msg = errJson['message'];
      } catch (_) {}
      throw Exception(msg);
    }
  }

  /// 6. Soft Delete Conversation
  Future<bool> deleteConversation(String conversationId, String userId, {String action = 'for_me'}) async {
    final uri = Uri.parse('$baseUrl/conversations/$conversationId');
    final reqHeaders = await _getHeaders();
    final response = await http
        .delete(
          uri,
          headers: reqHeaders,
          body: jsonEncode({
            'userId': userId,
            'action': action,
          }),
        )
        .timeout(const Duration(seconds: 12));
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  /// 7. Soft Delete Message
  Future<bool> deleteMessage(String messageId, String userId, {String action = 'for_me'}) async {
    final uri = Uri.parse('$baseUrl/messages/$messageId');
    final reqHeaders = await _getHeaders();
    final response = await http
        .delete(
          uri,
          headers: reqHeaders,
          body: jsonEncode({
            'userId': userId,
            'action': action,
          }),
        )
        .timeout(const Duration(seconds: 12));
    return response.statusCode >= 200 && response.statusCode < 300;
  }
}
