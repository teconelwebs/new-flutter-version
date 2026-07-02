class ReelComment {
  final String id;
  final String text;
  final String createdAt;
  final List<String> likes;
  final String? parentCommentId;
  final ReelCommentUser? user;
  final List<ReelComment> replies;

  ReelComment({
    required this.id,
    required this.text,
    required this.createdAt,
    this.likes = const [],
    this.parentCommentId,
    this.user,
    this.replies = const [],
  });

  ReelComment copyWith({
    List<String>? likes,
    List<ReelComment>? replies,
  }) {
    return ReelComment(
      id: id,
      text: text,
      createdAt: createdAt,
      likes: likes ?? this.likes,
      parentCommentId: parentCommentId,
      user: user,
      replies: replies ?? this.replies,
    );
  }

  factory ReelComment.fromJson(Map<String, dynamic> json) {
    final repliesRaw = json['replies'];
    return ReelComment(
      id: json['_id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      likes: (json['likes'] as List?)?.map((e) => e.toString()).toList() ?? [],
      parentCommentId: json['parentComment']?.toString(),
      user: json['user'] is Map<String, dynamic>
          ? ReelCommentUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      replies: repliesRaw is List
          ? repliesRaw
              .whereType<Map<String, dynamic>>()
              .map(ReelComment.fromJson)
              .toList()
          : [],
    );
  }
}

class ReelCommentUser {
  final String id;
  final String username;
  final String? profilePicture;

  ReelCommentUser({
    required this.id,
    required this.username,
    this.profilePicture,
  });

  factory ReelCommentUser.fromJson(Map<String, dynamic> json) {
    return ReelCommentUser(
      id: json['_id']?.toString() ?? json['userid']?.toString() ?? '',
      username: json['username']?.toString() ?? json['name']?.toString() ?? 'User',
      profilePicture: json['profilePicture']?.toString(),
    );
  }
}

int countCommentsRecursive(List<ReelComment> comments) {
  var n = comments.length;
  for (final c in comments) {
    n += countCommentsRecursive(c.replies);
  }
  return n;
}
