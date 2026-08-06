class UserModel {
  final String id;
  final String name;
  final String? avatar;
  final bool isOnline;
  final String? lastSeen;
  final String? roleTag; // e.g. 'SUPPORT', 'SELLER', 'ORDER'

  UserModel({
    required this.id,
    required this.name,
    this.avatar,
    this.isOnline = false,
    this.lastSeen,
    this.roleTag,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? json['username'] ?? json['user_name'] ?? 'User').toString(),
      avatar: json['avatar']?.toString() ?? json['profilePicture']?.toString() ?? json['user_avatar']?.toString(),
      isOnline: json['isOnline'] == true || json['is_online'] == true,
      lastSeen: json['lastSeen']?.toString(),
      roleTag: json['roleTag']?.toString() ?? json['role_tag']?.toString() ?? json['tag']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'avatar': avatar,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
      'roleTag': roleTag,
    };
  }
}
