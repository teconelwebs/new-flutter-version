import 'dart:async';
import 'package:flutter/foundation.dart';
// ignore: library_prefixes
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../../core/network/axios_instance.dart';
import '../data/models/message_model.dart';
import '../data/models/conversation_model.dart';

class ChatSocketService {
  static final ChatSocketService instance = ChatSocketService._internal();
  ChatSocketService._internal();

  IO.Socket? _socket;
  String? _currentUserId;
  String? _activeConversationId;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  String? get currentUserId => _currentUserId;

  // Event controllers
  final _newMessageController = StreamController<MessageModel>.broadcast();
  final _presenceChangeController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingStatusController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageDeliveredController = StreamController<Map<String, dynamic>>.broadcast();
  final _messagesSeenController = StreamController<Map<String, dynamic>>.broadcast();
  final _conversationUpdatedController = StreamController<ConversationModel>.broadcast();

  Stream<MessageModel> get onNewMessage => _newMessageController.stream;
  Stream<Map<String, dynamic>> get onPresenceChange => _presenceChangeController.stream;
  Stream<Map<String, dynamic>> get onTypingStatus => _typingStatusController.stream;
  Stream<Map<String, dynamic>> get onMessageDelivered => _messageDeliveredController.stream;
  Stream<Map<String, dynamic>> get onMessagesSeen => _messagesSeenController.stream;
  Stream<ConversationModel> get onConversationUpdated => _conversationUpdatedController.stream;

  void init({required String userId, String? baseUrl}) {
    if (_socket != null && _currentUserId == userId && _isConnected) {
      return;
    }

    _currentUserId = userId;

    String defaultUri = 'https://unnecessitous-domitila-unbudging.ngrok-free.dev';
    final fourth = AxiosInstance.baseUrls['FOURTH'];
    if (fourth != null && fourth.isNotEmpty) {
      var clean = fourth.trim();
      if (clean.endsWith('/api')) {
        clean = clean.substring(0, clean.length - 4);
      }
      if (clean.endsWith('/')) {
        clean = clean.substring(0, clean.length - 1);
      }
      defaultUri = clean;
    }

    final serverUri = baseUrl ?? defaultUri;

    disconnect();

    try {
      _socket = IO.io(
        serverUri,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .setQuery({'userId': userId})
            .enableAutoConnect()
            .enableReconnection()
            .build(),
      );

      _socket?.onConnect((_) {
        debugPrint('💬 [ChatSocket] Connected successfully for user $userId');
        _isConnected = true;
        _socket?.emit('authenticate', {'userId': userId});
        if (_activeConversationId != null) {
          debugPrint('💬 [ChatSocket] Rejoining active conversation: $_activeConversationId');
          _socket?.emit('join_conversation', {'conversationId': _activeConversationId});
        }
      });

      _socket?.onDisconnect((_) {
        debugPrint('💬 [ChatSocket] Disconnected');
        _isConnected = false;
      });

      _socket?.onConnectError((err) {
        debugPrint('💬 [ChatSocket] ConnectError: $err');
        _isConnected = false;
      });

      // Listeners
      _socket?.on('presence_change', (data) {
        debugPrint('💬 [ChatSocket] Recv presence_change: $data');
        if (data is Map<String, dynamic>) {
          _presenceChangeController.add(data);
        } else if (data is Map) {
          _presenceChangeController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket?.on('new_message', (data) {
        debugPrint('💬 [ChatSocket] Recv new_message: $data');
        try {
          if (data is Map<String, dynamic>) {
            _newMessageController.add(MessageModel.fromJson(data));
          } else if (data is Map) {
            _newMessageController.add(MessageModel.fromJson(Map<String, dynamic>.from(data)));
          }
        } catch (e) {
          debugPrint('💬 [ChatSocket] new_message parse error: $e');
        }
      });

      _socket?.on('conversation_updated', (data) {
        debugPrint('💬 [ChatSocket] Recv conversation_updated: $data');
        try {
          if (data is Map<String, dynamic>) {
            _conversationUpdatedController.add(ConversationModel.fromJson(data));
          } else if (data is Map) {
            _conversationUpdatedController.add(ConversationModel.fromJson(Map<String, dynamic>.from(data)));
          }
        } catch (e) {
          debugPrint('💬 [ChatSocket] conversation_updated parse error: $e');
        }
      });

      _socket?.on('user_typing', (data) {
        debugPrint('💬 [ChatSocket] Recv user_typing: $data');
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          map['isTyping'] = true;
          _typingStatusController.add(map);
        }
      });

      _socket?.on('user_stopped_typing', (data) {
        debugPrint('💬 [ChatSocket] Recv user_stopped_typing: $data');
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          map['isTyping'] = false;
          _typingStatusController.add(map);
        }
      });

      _socket?.on('message_delivered', (data) {
        debugPrint('💬 [ChatSocket] Recv message_delivered: $data');
        if (data is Map) {
          _messageDeliveredController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket?.on('messages_seen', (data) {
        debugPrint('💬 [ChatSocket] Recv messages_seen: $data');
        if (data is Map) {
          _messagesSeenController.add(Map<String, dynamic>.from(data));
        }
      });
    } catch (e) {
      debugPrint('💬 [ChatSocket] init error: $e');
    }
  }

  void joinConversation(String conversationId) {
    _activeConversationId = conversationId;
    if (_socket != null) {
      debugPrint('💬 [ChatSocket] Emit join_conversation: $conversationId');
      _socket?.emit('join_conversation', {'conversationId': conversationId});
    }
  }

  void leaveConversation(String conversationId) {
    if (_activeConversationId == conversationId) {
      _activeConversationId = null;
    }
    if (_socket != null) {
      debugPrint('💬 [ChatSocket] Emit leave_conversation: $conversationId');
      _socket?.emit('leave_conversation', {'conversationId': conversationId});
    }
  }

  void sendMessage({
    required String conversationId,
    required String type,
    required String text,
    String? mediaUrl,
    String? fileName,
    int? fileSize,
    String? mimeType,
    String? replyToId,
  }) {
    if (_socket != null && _currentUserId != null) {
      final payload = {
        'conversationId': conversationId,
        'senderId': _currentUserId,
        'type': type,
        'text': text,
        'mediaUrl': mediaUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'mimeType': mimeType,
        'replyTo': replyToId,
      };
      debugPrint('💬 [ChatSocket] Emit send_message: $payload');
      _socket?.emit('send_message', payload);
    }
  }

  void startTyping(String conversationId, String username) {
    if (_socket != null && _currentUserId != null) {
      debugPrint('💬 [ChatSocket] Emit typing_start: $conversationId');
      _socket?.emit('typing_start', {
        'conversationId': conversationId,
        'userId': _currentUserId,
        'username': username,
      });
    }
  }

  void stopTyping(String conversationId) {
    if (_socket != null && _currentUserId != null) {
      debugPrint('💬 [ChatSocket] Emit typing_stop: $conversationId');
      _socket?.emit('typing_stop', {
        'conversationId': conversationId,
        'userId': _currentUserId,
      });
    }
  }

  void markDelivered(String messageId, String conversationId) {
    if (_socket != null && _currentUserId != null) {
      debugPrint('💬 [ChatSocket] Emit mark_delivered: msg=$messageId, conv=$conversationId');
      _socket?.emit('mark_delivered', {
        'messageId': messageId,
        'conversationId': conversationId,
        'userId': _currentUserId,
      });
    }
  }

  void markSeen(String conversationId) {
    if (_socket != null && _currentUserId != null) {
      debugPrint('💬 [ChatSocket] Emit mark_seen: $conversationId');
      _socket?.emit('mark_seen', {
        'conversationId': conversationId,
        'userId': _currentUserId,
      });
    }
  }

  void disconnect() {
    debugPrint('💬 [ChatSocket] Disconnecting socket client');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }
}
