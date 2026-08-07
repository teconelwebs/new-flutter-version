import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_routes.dart';
import '../data/models/conversation_model.dart';
import '../services/chat_api_service.dart';
import '../services/chat_socket_service.dart';
import 'chat_room_screen.dart';
import 'create_group_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  static const routeName = AppRoutes.conversations;

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<ConversationModel> _conversations = [];
  bool _loading = true;
  String _selectedFilter = 'All';
  String _searchQuery = '';
  String _currentUserId = 'guest';

  StreamSubscription? _subNewMsg;
  StreamSubscription? _subPresence;
  StreamSubscription? _subConvUpdated;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserAndConversations();
  }

  Future<void> _loadUserAndConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedUserId = prefs.getString('cached_user_id') ?? '';
    final savedUserId = prefs.getString('user_id') ?? '';
    final savedPlayId = prefs.getString('play_user_id') ?? '';

    String resolvedId = 'guest';
    if (cachedUserId.isNotEmpty) {
      resolvedId = cachedUserId;
    } else if (savedUserId.isNotEmpty) {
      resolvedId = savedUserId;
    } else if (savedPlayId.isNotEmpty) {
      resolvedId = savedPlayId;
    }
    _currentUserId = resolvedId;
    debugPrint('💬 [ConversationsScreen] Loaded User ID: $_currentUserId');

    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    // Init Socket.IO connection
    ChatSocketService.instance.init(userId: _currentUserId);
    _setupSocketListeners();

    _fetchConversations();
  }

  void _setupSocketListeners() {
    _subNewMsg?.cancel();
    _subPresence?.cancel();
    _subConvUpdated?.cancel();

    _subNewMsg = ChatSocketService.instance.onNewMessage.listen((msg) {
      _fetchConversations(silent: true);
    });

    _subPresence = ChatSocketService.instance.onPresenceChange.listen((data) {
      final userId = data['userId']?.toString();
      final isOnline = data['isOnline'] == true;
      if (userId != null && mounted) {
        setState(() {
          _conversations = _conversations.map((c) {
            final other = c.getOtherParticipant(_currentUserId);
            if (other != null && other.id == userId) {
              return ConversationModel(
                id: c.id,
                isGroup: c.isGroup,
                groupName: c.groupName,
                groupAvatar: c.groupAvatar,
                groupDescription: c.groupDescription,
                groupAdmin: c.groupAdmin,
                participants: c.participants,
                lastMessage: c.lastMessage,
                lastMessageAt: c.lastMessageAt,
                unreadCount: c.unreadCount,
                isOtherOnline: isOnline,
                categoryTag: c.categoryTag,
              );
            }
            return c;
          }).toList();
        });
      }
    });

    _subConvUpdated = ChatSocketService.instance.onConversationUpdated.listen((updatedConv) {
      _fetchConversations(silent: true);
    });
  }

  Future<void> _fetchConversations({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _loading = true);
    }
    try {
      debugPrint('💬 [ConversationsScreen] Fetching conversations for $_currentUserId...');
      final list = await ChatApiService.instance.getConversations(_currentUserId);
      debugPrint('💬 [ConversationsScreen] Loaded ${list.length} conversations');
      if (mounted) {
        setState(() {
          _conversations = list;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('💬 [ConversationsScreen] Error fetching conversations: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _subNewMsg?.cancel();
    _subPresence?.cancel();
    _subConvUpdated?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<ConversationModel> get _filteredConversations {
    return _conversations.where((conv) {
      final title = conv.getDisplayName(_currentUserId).toLowerCase();
      final matchesSearch = _searchQuery.isEmpty || title.contains(_searchQuery.toLowerCase());
      
      if (!matchesSearch) return false;

      if (_selectedFilter == 'Unread') {
        return conv.unreadCount > 0;
      } else if (_selectedFilter == 'Support') {
        return conv.categoryTag?.toUpperCase() == 'SUPPORT' || title.contains('support');
      } else if (_selectedFilter == 'Sellers') {
        return conv.categoryTag?.toUpperCase() == 'SELLER' || title.contains('store') || title.contains('shop');
      }
      return true;
    }).toList();
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return mins <= 1 ? '1m' : '${mins}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dateTime.weekday - 1];
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  void _showNewChatDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Start a Chat',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add_rounded, color: Color(0xFF1A1A1A)),
              ),
              title: const Text('New 1-on-1 Chat', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Chat with seller, buyer or creator'),
              onTap: () {
                Navigator.pop(context);
                _showStart1On1Dialog();
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group_add_rounded, color: Color(0xFF1A1A1A)),
              ),
              title: const Text('Create New Group', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Create a group chat with multiple members'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, CreateGroupScreen.routeName).then((_) {
                  _fetchConversations();
                });
              },
            ),
          ],
        ),
      );
    },
  );
}

  void _showStart1On1Dialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Start 1-on-1 Chat'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    enabled: !isLoading,
                    decoration: const InputDecoration(
                      hintText: 'Enter User ID or Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (isLoading) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(color: Color(0xFF1A1A1A)),
                  ],
                ],
              ),
              actions: [
                if (!isLoading)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel'),
                  ),
                if (!isLoading)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1A1A)),
                    onPressed: () async {
                      final targetId = controller.text.trim();
                      if (targetId.isEmpty) return;

                      setDialogState(() => isLoading = true);
                      try {
                        final conv = await ChatApiService.instance.getOrCreateOneToOneConversation(
                          userId: _currentUserId,
                          targetUserId: targetId,
                        );
                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                        }
                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatRoomScreen(conversation: conv),
                            ),
                          ).then((_) => _fetchConversations());
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error starting chat: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Start', style: TextStyle(color: Colors.white)),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header: Title + Plus Action Button
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 16, top: 16, bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chats',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                      letterSpacing: -0.5,
                    ),
                  ),
                  InkWell(
                    onTap: _showNewChatDialog,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEEEE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 22,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEDED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Search chats, orders...',
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Filter Chips Row
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildFilterPill('All'),
                  const SizedBox(width: 8),
                  _buildFilterPill('Unread'),
                  const SizedBox(width: 8),
                  _buildFilterPill('Support'),
                  const SizedBox(width: 8),
                  _buildFilterPill('Sellers'),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Conversations List
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF1A1A1A),
                onRefresh: () => _fetchConversations(),
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A1A1A)))
                    : _filteredConversations.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 100),
                              Center(
                                child: Text(
                                  'No chats found',
                                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(top: 8, bottom: 20),
                            itemCount: _filteredConversations.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final conv = _filteredConversations[index];
                              return _buildConversationTile(conv);
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String label) {
    final bool isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1A1A1A) : Colors.transparent,
            width: 1,
          ),
          boxShadow: isSelected
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildConversationTile(ConversationModel conv) {
    final name = conv.getDisplayName(_currentUserId);
    final avatar = conv.getDisplayAvatar(_currentUserId);
    final isOnline = conv.isOtherOnline;
    final lastMsgText = conv.lastMessage?.text ?? 'No messages yet';
    final timeStr = conv.lastMessage != null
        ? _formatTime(conv.lastMessage!.createdAt)
        : '';
    final unreadCount = conv.unreadCount;

    // Detect tag badge (SUPPORT, SELLER, ORDER)
    String? tagBadge = conv.categoryTag;
    if (tagBadge == null || tagBadge.isEmpty) {
      final nameLower = name.toLowerCase();
      if (nameLower.contains('support')) tagBadge = 'SUPPORT';
      else if (nameLower.contains('store') || nameLower.contains('official') || nameLower.contains('audio')) tagBadge = 'SELLER';
      else if (nameLower.contains('delivery') || nameLower.contains('partner') || nameLower.contains('order')) tagBadge = 'ORDER';
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(conversation: conv),
          ),
        ).then((_) => _fetchConversations(silent: true));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar with online status dot
            Stack(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF262626),
                  ),
                  child: avatar != null && avatar.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatar,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'C',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'C',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                ),
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 14),

            // Name + Tag Badge + Last Message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      if (tagBadge != null && tagBadge.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tagBadge.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6B7280),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMsgText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: unreadCount > 0 ? const Color(0xFF111827) : const Color(0xFF6B7280),
                      fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Time & Unread Count Badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                if (unreadCount > 0)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFF111827),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
