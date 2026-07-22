import 'package:flutter/material.dart';
import 'package:welfog_flutter_play/welfog_flutter_play.dart';

import '../data/account_api_service.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen>
    with SingleTickerProviderStateMixin {
  final _api = AccountApiService();
  List<BlockedUser> _blockedUsers = [];
  bool _loading = true;
  String? _unblockingId;
  String? _toast;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _loadBlockedUsers();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() => _loading = true);
    try {
      final list = await _api.fetchBlockedUsers();
      if (!mounted) return;
      setState(() {
        _blockedUsers = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showToast(String msg) {
    setState(() => _toast = msg);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _toast == msg) setState(() => _toast = null);
    });
  }

  Future<void> _handleUnblock(BlockedUser user) async {
    // Only one unblock at a time — ignore rapid taps.
    if (_unblockingId != null) return;

    setState(() => _unblockingId = user.id);

    try {
      final success = await _api.unblockUser(user.id);
      if (!success) {
        throw Exception('Unblock failed');
      }
      PlaySessionRegistry.markIdsUnblocked(user.relatedIds);
      await PlaySessionRegistry.syncBlockedListAfterExternalChange();
      if (!mounted) return;
      setState(() {
        _blockedUsers.removeWhere((u) => u.id == user.id);
      });
      final label =
          user.username.isNotEmpty ? '@${user.username}' : 'User';
      _showToast('Unblocked $label');
    } catch (_) {
      if (mounted) {
        _showToast('Unable to unblock user at this time.');
      }
    } finally {
      if (mounted) {
        setState(() => _unblockingId = null);
      }
    }
  }

  Widget _toastWidget() {
    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            _toast!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoader() {
    return AnimatedBuilder(
      animation: _fadeController,
      builder: (context, child) {
        final opacity = 0.3 + (_fadeController.value * 0.4);
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          itemBuilder: (ctx, index) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0E0E0),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 120,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E0E0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 80,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E0E0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 80,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 50,
                    color: Color(0xFF9CA3AF),
                  ),
                  Icon(
                    Icons.block_rounded,
                    size: 24,
                    color: Color(0xFFEF4444),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Blocked Users',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When you block someone, they will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _unblockingId != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Blocked Users',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFFEEEEEE),
            height: 1.0,
          ),
        ),
      ),
      body: Stack(
        children: [
          _loading
              ? _buildShimmerLoader()
              : RefreshIndicator(
                  color: const Color(0xFFFB5404),
                  onRefresh: isBusy ? () async {} : _loadBlockedUsers,
                  child: _blockedUsers.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.55,
                              child: _buildEmptyState(),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _blockedUsers.length,
                          itemBuilder: (ctx, index) {
                            final user = _blockedUsers[index];
                            final hasImage =
                                user.profilePicture.trim().isNotEmpty;
                            final isUnblocking = _unblockingId == user.id;
                            final canTap = !isBusy;

                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: const Color(0xFFF3F4F6),
                                    backgroundImage: hasImage
                                        ? NetworkImage(user.profilePicture)
                                        : null,
                                    child: !hasImage
                                        ? const Icon(Icons.person,
                                            color: Color(0xFF999999), size: 24)
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.username.isNotEmpty
                                              ? '@${user.username}'
                                              : 'Unknown User',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1F2937),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (user.name.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            user.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF6B7280),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: canTap
                                        ? () => _handleUnblock(user)
                                        : null,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          const Color(0xFFFB5404),
                                      disabledForegroundColor:
                                          const Color(0xFFFB5404)
                                              .withValues(alpha: 0.45),
                                      side: BorderSide(
                                        color: canTap
                                            ? const Color(0xFFFB5404)
                                            : const Color(0xFFFB5404)
                                                .withValues(alpha: 0.35),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 6),
                                    ),
                                    child: isUnblocking
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<
                                                      Color>(
                                                Color(0xFFFB5404),
                                              ),
                                            ),
                                          )
                                        : const Text(
                                            'Unblock',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
          if (_toast != null) _toastWidget(),
        ],
      ),
    );
  }
}
