import 'user_model.dart';

enum MessageType {
  text,
  image,
  video,
  audio,
  document,
  pdf,
  zip,
  excel,
  word,
  powerpoint,
  json,
  csv,
  file;

  static MessageType fromString(String? type) {
    if (type == null) return MessageType.text;
    switch (type.toLowerCase()) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'audio':
        return MessageType.audio;
      case 'document':
      case 'doc':
        return MessageType.document;
      case 'pdf':
        return MessageType.pdf;
      case 'zip':
        return MessageType.zip;
      case 'excel':
      case 'xls':
      case 'xlsx':
        return MessageType.excel;
      case 'word':
      case 'docx':
        return MessageType.word;
      case 'powerpoint':
      case 'ppt':
      case 'pptx':
        return MessageType.powerpoint;
      case 'json':
        return MessageType.json;
      case 'csv':
        return MessageType.csv;
      case 'file':
        return MessageType.file;
      default:
        return MessageType.text;
    }
  }

  String toValueString() => name;
}

class MessageModel {
  final String id;
  final String conversationId;
  final UserModel sender;
  final MessageType type;
  final String text;
  final String? mediaUrl;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final String status; // 'sent', 'delivered', 'seen'
  final List<String> deliveredTo;
  final List<String> seenBy;
  final MessageModel? replyTo;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.type,
    required this.text,
    this.mediaUrl,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.status = 'sent',
    this.deliveredTo = const [],
    this.seenBy = const [],
    this.replyTo,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final senderJson = json['sender'];
    UserModel senderUser;
    if (senderJson is Map<String, dynamic>) {
      senderUser = UserModel.fromJson(senderJson);
    } else if (senderJson is String) {
      senderUser = UserModel(id: senderJson, name: 'User');
    } else {
      senderUser = UserModel(id: 'unknown', name: 'User');
    }

    MessageModel? replyMsg;
    if (json['replyTo'] is Map<String, dynamic>) {
      replyMsg = MessageModel.fromJson(json['replyTo'] as Map<String, dynamic>);
    }

    return MessageModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      conversationId: (json['conversationId'] ?? json['conversation_id'] ?? json['conversation'] ?? '').toString(),
      sender: senderUser,
      type: MessageType.fromString(json['type']?.toString()),
      text: (json['text'] ?? '').toString(),
      mediaUrl: json['mediaUrl']?.toString() ?? json['media_url']?.toString(),
      fileName: json['fileName']?.toString() ?? json['file_name']?.toString(),
      fileSize: json['fileSize'] is int
          ? json['fileSize'] as int
          : (json['file_size'] is int ? json['file_size'] as int : null),
      mimeType: json['mimeType']?.toString() ?? json['mime_type']?.toString(),
      status: (json['status'] ?? 'sent').toString(),
      deliveredTo: (json['deliveredTo'] as List?)?.map((e) => e.toString()).toList() ?? [],
      seenBy: (json['seenBy'] as List?)?.map((e) => e.toString()).toList() ?? [],
      replyTo: replyMsg,
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'conversationId': conversationId,
      'sender': sender.toJson(),
      'type': type.toValueString(),
      'text': text,
      'mediaUrl': mediaUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'status': status,
      'deliveredTo': deliveredTo,
      'seenBy': seenBy,
      'replyTo': replyTo?.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
