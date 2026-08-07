import 'user_model.dart';
import 'message_model.dart';

class ConversationModel {
  final String id;
  final bool isGroup;
  final String? groupName;
  final String? groupAvatar;
  final String? groupDescription;
  final UserModel? groupAdmin;
  final List<UserModel> participants;
  final MessageModel? lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool isOtherOnline;
  final String? categoryTag; // 'SUPPORT', 'SELLER', 'ORDER'

  ConversationModel({
    required this.id,
    required this.isGroup,
    this.groupName,
    this.groupAvatar,
    this.groupDescription,
    this.groupAdmin,
    required this.participants,
    this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.isOtherOnline = false,
    this.categoryTag,
  });

  UserModel? getOtherParticipant(String currentUserId) {
    if (isGroup) return null;
    return participants.firstWhere(
      (p) => p.id != currentUserId,
      orElse: () => participants.isNotEmpty
          ? participants.first
          : UserModel(id: 'unknown', name: 'User'),
    );
  }

  String getDisplayName(String currentUserId) {
    if (isGroup) return groupName ?? 'Group Chat';
    final other = getOtherParticipant(currentUserId);
    return other?.name ?? 'Chat';
  }

  String? getDisplayAvatar(String currentUserId) {
    if (isGroup) return groupAvatar;
    final other = getOtherParticipant(currentUserId);
    return other?.avatar;
  }

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final partsJson = json['participants'] as List? ?? [];
    final participantsList = partsJson
        .map((p) => p is Map<String, dynamic> ? UserModel.fromJson(p) : UserModel(id: p.toString(), name: 'User'))
        .toList();

    MessageModel? lastMsg;
    if (json['lastMessage'] is Map<String, dynamic>) {
      lastMsg = MessageModel.fromJson(json['lastMessage'] as Map<String, dynamic>);
    }

    UserModel? adminUser;
    if (json['groupAdmin'] is Map<String, dynamic>) {
      adminUser = UserModel.fromJson(json['groupAdmin'] as Map<String, dynamic>);
    }

    return ConversationModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      isGroup: json['isGroup'] == true || json['is_group'] == true,
      groupName: json['groupName']?.toString() ?? json['group_name']?.toString(),
      groupAvatar: json['groupAvatar']?.toString() ?? json['group_avatar']?.toString(),
      groupDescription: json['groupDescription']?.toString() ?? json['group_description']?.toString(),
      groupAdmin: adminUser,
      participants: participantsList,
      lastMessage: lastMsg,
      lastMessageAt: json['lastMessageAt'] != null
          ? (DateTime.tryParse(json['lastMessageAt'].toString()) ?? DateTime.now())
          : (lastMsg?.createdAt ?? DateTime.now()),
      unreadCount: (json['unreadCount'] ?? json['unread_count'] ?? 0) as int,
      isOtherOnline: json['isOtherOnline'] == true || json['is_other_online'] == true,
      categoryTag: json['categoryTag']?.toString() ?? json['category_tag']?.toString() ?? json['tag']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'isGroup': isGroup,
      'groupName': groupName,
      'groupAvatar': groupAvatar,
      'groupDescription': groupDescription,
      'groupAdmin': groupAdmin?.toJson(),
      'participants': participants.map((p) => p.toJson()).toList(),
      'lastMessage': lastMessage?.toJson(),
      'lastMessageAt': lastMessageAt.toIso8601String(),
      'unreadCount': unreadCount,
      'isOtherOnline': isOtherOnline,
      'categoryTag': categoryTag,
    };
  }
}
