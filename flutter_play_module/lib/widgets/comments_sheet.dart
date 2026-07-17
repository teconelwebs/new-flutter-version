import 'package:flutter/material.dart';

import '../models/comment.dart';
import '../services/reels_api.dart';
import '../utils/app_routes.dart';
import '../utils/flutter_nav.dart';
import '../utils/profile_thumbnail_cache.dart';

const _emojiSuggestions = ['❤️', '🙌', '🔥', '👏', '😢', '😍', '😮', '😂'];

String _timeAgo(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final date = DateTime.tryParse(iso);
  if (date == null) return '';
  final seconds = DateTime.now().difference(date).inSeconds;
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  if (hours < 24) return '${hours}h';
  final days = hours ~/ 24;
  if (days < 7) return '${days}d';
  final weeks = days ~/ 7;
  if (weeks < 52) return '${weeks}w';
  final years = days ~/ 365;
  return '${years}y';
}

class CommentsSheet extends StatefulWidget {
  final ReelsApi api;
  final String reelId;
  final BuildContext hostContext;
  final VoidCallback? onChanged;

  const CommentsSheet({
    super.key,
    required this.api,
    required this.reelId,
    required this.hostContext,
    this.onChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required ReelsApi api,
    required String reelId,
    VoidCallback? onChanged,
  }) {
    final height = MediaQuery.sizeOf(context).height * 0.62;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => lightSheetWrapper(
        child: SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: CommentsSheet(
              api: api,
              reelId: reelId,
              hostContext: context,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _composerKey = GlobalKey<_CommentComposerState>();
  List<ReelComment> _comments = [];
  bool _loading = true;
  bool _sending = false;
  String? _replyToId;
  String? _replyToName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _loading = true);
    final list = await widget.api.fetchComments(widget.reelId);
    if (mounted) {
      setState(() {
        _comments = list;
        _loading = false;
      });
    }
  }

  ReelComment? _findComment(String commentId) {
    for (final comment in _comments) {
      if (comment.id == commentId) return comment;
      for (final reply in comment.replies) {
        if (reply.id == commentId) return reply;
      }
    }
    return null;
  }

  List<ReelComment> _replaceCommentLikes(
    List<ReelComment> comments,
    String commentId,
    List<String> likes,
  ) {
    return comments.map((comment) {
      if (comment.id == commentId) {
        return comment.copyWith(likes: likes);
      }
      if (comment.replies.isNotEmpty) {
        return comment.copyWith(
          replies: _replaceCommentLikes(comment.replies, commentId, likes),
        );
      }
      return comment;
    }).toList();
  }

  Future<void> _toggleCommentLike(String commentId) async {
    final target = _findComment(commentId);
    if (target == null) return;

    final viewerId = widget.api.viewerId;
    final previousLikes = List<String>.from(target.likes);
    final optimisticLikes = List<String>.from(previousLikes);
    if (optimisticLikes.contains(viewerId)) {
      optimisticLikes.remove(viewerId);
    } else {
      optimisticLikes.add(viewerId);
    }

    setState(() {
      _comments = _replaceCommentLikes(_comments, commentId, optimisticLikes);
    });

    try {
      await widget.api.likeComment(commentId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _comments = _replaceCommentLikes(_comments, commentId, previousLikes);
      });
    }
  }

  void _startReply(ReelComment comment) {
    final name = comment.user?.username ?? 'User';
    setState(() {
      _replyToId = comment.id;
      _replyToName = name;
    });
    _composerKey.currentState?.startReply(name);
  }

  void _clearReply() {
    setState(() {
      _replyToId = null;
      _replyToName = null;
    });
    _composerKey.currentState?.clearReply();
  }

  void _openProfile(String userId) {
    if (userId.isEmpty) return;
    AppRoutes.openProfile(widget.hostContext, userId);
  }

  Future<void> _confirmDelete(ReelComment comment) async {
    if (comment.user?.id != widget.api.viewerId) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Comment',
          style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF111827)),
        ),
        content: const Text(
          'Are you sure you want to delete this comment?',
          style: TextStyle(color: Color(0xFF6B7280), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _deleteComment(comment.id);
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await widget.api.deleteComment(commentId);
      if (!mounted) return;
      await _load(showSpinner: false);
      widget.onChanged?.call();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete comment. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _send(String rawText) async {
    var text = rawText.trim();
    if (text.isEmpty || _sending) return;

    if (_replyToName != null && !text.startsWith('@')) {
      text = '@$_replyToName $text';
    }

    setState(() => _sending = true);
    try {
      final added = await widget.api.addComment(
        widget.reelId,
        text,
        parentId: _replyToId,
      );
      if (!mounted) return;
      if (added != null) {
        _composerKey.currentState?.clearInput();
        _clearReply();
        await _load(showSpinner: false);
        widget.onChanged?.call();
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = countCommentsRecursive(_comments);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            total > 0 ? '$total Comments' : 'Comments',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFfb5404)))
                : _comments.isEmpty
                    ? const Center(
                        child: Text(
                          'No comments yet. Be the first!',
                          style: TextStyle(color: Colors.black45, fontSize: 14),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 4, 10, 8),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: _comments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (_, i) => _CommentThread(
                          comment: _comments[i],
                          api: widget.api,
                          onReply: _startReply,
                          onLike: _toggleCommentLike,
                          onProfileTap: _openProfile,
                          onDelete: _confirmDelete,
                        ),
                      ),
          ),
          _CommentComposer(
            key: _composerKey,
            sending: _sending,
            replyToName: _replyToName,
            onSend: _send,
            onClearReply: _clearReply,
          ),
        ],
      ),
    );
  }
}

class _CommentComposer extends StatefulWidget {
  final bool sending;
  final String? replyToName;
  final ValueChanged<String> onSend;
  final VoidCallback onClearReply;

  const _CommentComposer({
    super.key,
    required this.sending,
    required this.replyToName,
    required this.onSend,
    required this.onClearReply,
  });

  @override
  State<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<_CommentComposer> {
  final _input = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void startReply(String name) {
    _input.text = '@$name ';
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    _focusNode.requestFocus();
  }

  void clearReply() {
    _input.clear();
  }

  void clearInput() {
    _input.clear();
  }

  void _appendEmoji(String emoji) {
    final value = _input.value;
    final text = value.text;
    final selection = value.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final updated = text.replaceRange(start, end, emoji);
    _input.value = value.copyWith(
      text: updated,
      selection: TextSelection.collapsed(offset: start + emoji.length),
      composing: TextRange.empty,
    );
    _focusNode.requestFocus();
  }

  void _handleSend() {
    widget.onSend(_input.text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.replyToName != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: const Color(0xFFF9FAFB),
            child: Row(
              children: [
                Text(
                  'Replying to ',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                Text(
                  '@${widget.replyToName}',
                  style: const TextStyle(
                    color: Color(0xFF0095F6),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onClearReply,
                  child: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        _EmojiSuggestionBar(onEmojiTap: _appendEmoji),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    focusNode: _focusNode,
                    enabled: !widget.sending,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    minLines: 1,
                    maxLines: 6,
                    enableIMEPersonalizedLearning: false,
                    autocorrect: true,
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                    cursorColor: const Color(0xFFfb5404),
                    decoration: InputDecoration(
                      hintText: widget.replyToName != null
                          ? 'Reply to @${widget.replyToName}...'
                          : 'Add a comment...',
                      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: widget.sending
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFFfb5404),
                            ),
                          ),
                        )
                      : IconButton(
                          onPressed: _handleSend,
                          icon: const Icon(Icons.send_rounded, color: Color(0xFFfb5404)),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmojiSuggestionBar extends StatelessWidget {
  final ValueChanged<String> onEmojiTap;

  const _EmojiSuggestionBar({required this.onEmojiTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _emojiSuggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final emoji = _emojiSuggestions[i];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onEmojiTap(emoji),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(emoji, style: const TextStyle(fontSize: 22, height: 1.1)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CommentThread extends StatefulWidget {
  final ReelComment comment;
  final ReelsApi api;
  final void Function(ReelComment) onReply;
  final Future<void> Function(String commentId) onLike;
  final void Function(String userId) onProfileTap;
  final Future<void> Function(ReelComment comment) onDelete;

  const _CommentThread({
    required this.comment,
    required this.api,
    required this.onReply,
    required this.onLike,
    required this.onProfileTap,
    required this.onDelete,
  });

  @override
  State<_CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends State<_CommentThread> {
  bool _repliesExpanded = true;

  @override
  Widget build(BuildContext context) {
    final replies = widget.comment.replies;
    final hasReplies = replies.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentRow(
          comment: widget.comment,
          api: widget.api,
          isReply: false,
          onReply: () => widget.onReply(widget.comment),
          onLike: () => widget.onLike(widget.comment.id),
          onProfileTap: widget.onProfileTap,
          onDelete: () => widget.onDelete(widget.comment),
        ),
        if (hasReplies && !_repliesExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 46, top: 2, bottom: 4),
            child: GestureDetector(
              onTap: () => setState(() => _repliesExpanded = true),
              child: Text(
                'View ${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (hasReplies && _repliesExpanded) ...[
          ...replies.map(
            (reply) => Padding(
              padding: const EdgeInsets.only(left: 46, top: 10),
              child: _CommentRow(
                comment: reply,
                api: widget.api,
                isReply: true,
                onReply: () => widget.onReply(reply),
                onLike: () => widget.onLike(reply.id),
                onProfileTap: widget.onProfileTap,
                onDelete: () => widget.onDelete(reply),
              ),
            ),
          ),
          if (replies.length > 1)
            Padding(
              padding: const EdgeInsets.only(left: 46, top: 4),
              child: GestureDetector(
                onTap: () => setState(() => _repliesExpanded = false),
                child: const Text(
                  'Hide replies',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _CommentRow extends StatelessWidget {
  final ReelComment comment;
  final ReelsApi api;
  final bool isReply;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final void Function(String userId) onProfileTap;
  final VoidCallback onDelete;

  const _CommentRow({
    required this.comment,
    required this.api,
    required this.isReply,
    required this.onReply,
    required this.onLike,
    required this.onProfileTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final user = comment.user;
    final avatarSize = isReply ? 28.0 : 36.0;
    final isLiked = comment.likes.contains(api.viewerId);
    final likeCount = comment.likes.length;
    final userId = user?.id ?? '';
    final canDelete = userId.isNotEmpty && userId == api.viewerId;

    return GestureDetector(
      onLongPress: canDelete ? onDelete : null,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: userId.isNotEmpty ? () => onProfileTap(userId) : null,
            child: CircleAvatar(
              radius: avatarSize / 2,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: user?.profilePicture != null && user!.profilePicture!.isNotEmpty
                  ? ProfileThumbnailCache.avatarProvider(
                      user.profilePicture!,
                      MediaQuery.devicePixelRatioOf(context),
                      logicalDiameter: avatarSize,
                    )
                  : null,
              child: user?.profilePicture == null || user!.profilePicture!.isEmpty
                  ? Text(
                      (user?.username ?? 'U').substring(0, 1).toUpperCase(),
                      style: TextStyle(fontSize: isReply ? 11 : 13, color: Colors.black54),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: userId.isNotEmpty ? () => onProfileTap(userId) : null,
                        child: Text(
                          user?.username ?? 'User',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: isReply ? 13 : 14,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _timeAgo(comment.createdAt),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: isReply ? 11 : 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                _CommentBodyText(text: comment.text, isReply: isReply),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: onReply,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      'Reply',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: isReply ? 11 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onLike,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      size: isReply ? 15 : 17,
                      color: isLiked ? const Color(0xFFEF4444) : Colors.grey.shade500,
                    ),
                  ),
                ),
                if (likeCount > 0)
                  Text(
                    '$likeCount',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentBodyText extends StatelessWidget {
  final String text;
  final bool isReply;

  const _CommentBodyText({required this.text, required this.isReply});

  @override
  Widget build(BuildContext context) {
    final mention = RegExp(r'^@(\S+)\s*').firstMatch(text);
    final fontSize = isReply ? 13.0 : 14.0;

    if (mention != null) {
      final mentionText = mention.group(0) ?? '';
      final rest = text.substring(mention.end);
      return RichText(
        text: TextSpan(
          style: TextStyle(
            color: Colors.black87,
            fontSize: fontSize,
            height: 1.35,
          ),
          children: [
            TextSpan(
              text: mentionText,
              style: const TextStyle(
                color: Color(0xFF0095F6),
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: rest),
          ],
        ),
      );
    }

    return Text(
      text,
      style: TextStyle(
        color: Colors.black87,
        fontSize: fontSize,
        height: 1.35,
      ),
    );
  }
}
