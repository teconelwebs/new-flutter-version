import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../utils/app_routes.dart';
import '../utils/play_session.dart';
import '../widgets/profile_widgets.dart';

class FollowListScreen extends StatefulWidget {
  final String type;
  final String profileUserId;
  final bool isOwnProfile;

  const FollowListScreen({
    super.key,
    required this.type,
    required this.profileUserId,
    this.isOwnProfile = false,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  List<FollowUser> _users = [];
  bool _loading = true;
  String? _error;
  bool _initialized = false;
  String? _processingUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.profileUserId.isEmpty) {
      setState(() {
        _loading = false;
        _users = [];
        _error = 'User not found';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final api = PlaySession.apiOf(context);
    try {
      await PlaySessionRegistry.ensureBlockedListLoaded(api);
      final users = await api.fetchFollowList(widget.profileUserId, widget.type);
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _userKey(FollowUser user) => user.id.isNotEmpty ? user.id : (user.userid ?? '');

  String _targetApiId(FollowUser user) {
    if (user.id.isNotEmpty) return user.id;
    return user.userid ?? '';
  }

  bool _isUserBlocked(FollowUser user) {
    return PlaySessionRegistry.isAnyIdBlocked([
      user.id,
      if (user.userid != null) user.userid!,
    ]);
  }

  Future<void> _handleUnblock(FollowUser user) async {
    if (_processingUserId != null) return;

    final targetId = _targetApiId(user);
    if (targetId.isEmpty) return;

    final api = PlaySession.apiOf(context);
    setState(() => _processingUserId = _userKey(user));

    try {
      await PlaySessionRegistry.scope?.refreshViewerFromSession();
      final result = await api.unblockUser(targetId);
      if (!mounted) return;
      if (result.ok) {
        PlaySessionRegistry.markProfileUnblocked(
          id: user.id.isNotEmpty ? user.id : targetId,
          userid: user.userid,
        );
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message.isNotEmpty ? result.message : 'User unblocked',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message.isNotEmpty
                  ? result.message
                  : 'Unable to unblock user',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _processingUserId = null);
    }
  }

  void _removeFromList(FollowUser user) {
    final key = _userKey(user);
    setState(() {
      _users = _users.where((u) => _userKey(u) != key).toList();
    });
  }

  Future<void> _handleRemove(FollowUser user) async {
    if (!widget.isOwnProfile || _processingUserId != null) return;

    final targetId = _targetApiId(user);
    if (targetId.isEmpty) return;

    final api = PlaySession.apiOf(context);
    if (targetId == api.viewerId) return;

    setState(() => _processingUserId = _userKey(user));

    try {
      if (widget.type == 'followers') {
        await api.removeFollower(targetId);
      } else {
        await api.toggleFollow(targetId, follow: false);
        PlaySessionRegistry.setFollowState(
          following: false,
          id: user.id,
          userid: user.userid,
        );
      }
      if (!mounted) return;
      _removeFromList(user);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _processingUserId = null);
    }
  }

  Future<void> _openUser(FollowUser user) async {
    final api = PlaySession.apiOf(context);
    final target = user.id.isNotEmpty ? user.id : (user.userid ?? '');
    if (target.isEmpty) return;
    if (target == api.viewerId) {
      await Navigator.pushNamed(context, AppRoutes.myProfile, arguments: api);
    } else {
      await Navigator.pushNamed(
        context,
        '${AppRoutes.otherProfile}?id=${Uri.encodeComponent(target)}',
        arguments: api,
      );
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == 'following' ? 'Following' : 'Followers';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: _loading
          ? const FollowListSkeleton()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Color(0xFF666666))),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFfb5404)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFFfb5404),
                  onRefresh: _load,
                  child: _users.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Text(
                                'No $title yet',
                                style: const TextStyle(color: Color(0xFF666666), fontSize: 15),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          itemCount: _users.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            final userKey = _userKey(user);
                            final isProcessing = _processingUserId == userKey;
                            final isBlocked = _isUserBlocked(user);

                            return ListTile(
                              onTap: () => _openUser(user),
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFFF3F4F6),
                                backgroundImage: user.profilePicture != null && user.profilePicture!.isNotEmpty
                                    ? NetworkImage(user.profilePicture!)
                                    : null,
                                child: user.profilePicture == null || user.profilePicture!.isEmpty
                                    ? const Icon(Icons.person, color: Color(0xFF9CA3AF))
                                    : null,
                              ),
                              title: Text(
                                user.username,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isBlocked ? const Color(0xFF9CA3AF) : const Color(0xFF1A1A1A),
                                ),
                              ),
                              subtitle: isBlocked
                                  ? const Text(
                                      'Blocked',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                                    )
                                  : null,
                              trailing: isBlocked
                                  ? OutlinedButton(
                                      onPressed: isProcessing ? null : () => _handleUnblock(user),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFfb5404),
                                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                                        backgroundColor: const Color(0xFFF9FAFB),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        minimumSize: const Size(80, 36),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                      child: isProcessing
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Color(0xFFfb5404),
                                              ),
                                            )
                                          : const Text(
                                              'Unblock',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    )
                                  : widget.isOwnProfile
                                      ? IconButton(
                                          onPressed: isProcessing ? null : () => _handleRemove(user),
                                          icon: isProcessing
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Color(0xFFEF4444),
                                                  ),
                                                )
                                              : Icon(
                                                  widget.type == 'followers'
                                                      ? Icons.person_remove_outlined
                                                      : Icons.person_remove,
                                                  color: const Color(0xFFEF4444),
                                                  size: 24,
                                                ),
                                          tooltip: widget.type == 'followers' ? 'Remove follower' : 'Unfollow',
                                        )
                                      : null,
                            );
                          },
                        ),
                ),
    );
  }
}
