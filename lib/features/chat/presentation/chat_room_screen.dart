import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models/conversation_model.dart';
import '../data/models/message_model.dart';
import '../services/chat_api_service.dart';
import '../services/chat_socket_service.dart';

class ChatRoomScreen extends StatefulWidget {
  final ConversationModel conversation;

  const ChatRoomScreen({
    super.key,
    required this.conversation,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  late ConversationModel _conversation;
  List<MessageModel> _messages = [];
  bool _loading = true;
  String _currentUserId = 'guest';

  bool _isOtherTyping = false;
  String _typingUsername = '';
  bool _isOtherOnline = false;

  MessageModel? _replyToMessage;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;

  StreamSubscription? _subNewMsg;
  StreamSubscription? _subPresence;
  StreamSubscription? _subTyping;
  StreamSubscription? _subDelivered;
  StreamSubscription? _subSeen;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _isOtherOnline = _conversation.isOtherOnline;
    _initChat();
  }

  Future<void> _initChat() async {
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

    ChatSocketService.instance.init(userId: _currentUserId);
    ChatSocketService.instance.joinConversation(_conversation.id);
    ChatSocketService.instance.markSeen(_conversation.id);

    _listenSockets();
    _fetchMessagesHistory();
  }

  void _listenSockets() {
    _subNewMsg?.cancel();
    _subPresence?.cancel();
    _subTyping?.cancel();
    _subDelivered?.cancel();
    _subSeen?.cancel();

    _subNewMsg = ChatSocketService.instance.onNewMessage.listen((msg) {
      if (msg.conversationId == _conversation.id) {
        if (mounted) {
          setState(() {
            _messages.add(msg);
          });
          _scrollToBottom();
          ChatSocketService.instance.markSeen(_conversation.id);
        }
      }
    });

    _subPresence = ChatSocketService.instance.onPresenceChange.listen((data) {
      final userId = data['userId']?.toString();
      final isOnline = data['isOnline'] == true;
      final other = _conversation.getOtherParticipant(_currentUserId);
      if (other != null && other.id == userId && mounted) {
        setState(() {
          _isOtherOnline = isOnline;
        });
      }
    });

    _subTyping = ChatSocketService.instance.onTypingStatus.listen((data) {
      final convId = data['conversationId']?.toString();
      final userId = data['userId']?.toString();
      final isTyping = data['isTyping'] == true;
      final uname = data['username']?.toString() ?? 'Someone';

      if (convId == _conversation.id && userId != _currentUserId && mounted) {
        setState(() {
          _isOtherTyping = isTyping;
          _typingUsername = uname;
        });
      }
    });

    _subDelivered = ChatSocketService.instance.onMessageDelivered.listen((data) {
      final msgId = data['messageId']?.toString();
      if (msgId != null && mounted) {
        setState(() {
          _messages = _messages.map((m) {
            if (m.id == msgId) {
              return MessageModel(
                id: m.id,
                conversationId: m.conversationId,
                sender: m.sender,
                type: m.type,
                text: m.text,
                mediaUrl: m.mediaUrl,
                fileName: m.fileName,
                fileSize: m.fileSize,
                mimeType: m.mimeType,
                status: 'delivered',
                deliveredTo: m.deliveredTo,
                seenBy: m.seenBy,
                replyTo: m.replyTo,
                createdAt: m.createdAt,
              );
            }
            return m;
          }).toList();
        });
      }
    });

    _subSeen = ChatSocketService.instance.onMessagesSeen.listen((data) {
      final convId = data['conversationId']?.toString();
      if (convId == _conversation.id && mounted) {
        setState(() {
          _messages = _messages.map((m) {
            if (m.sender.id == _currentUserId) {
              return MessageModel(
                id: m.id,
                conversationId: m.conversationId,
                sender: m.sender,
                type: m.type,
                text: m.text,
                mediaUrl: m.mediaUrl,
                fileName: m.fileName,
                fileSize: m.fileSize,
                mimeType: m.mimeType,
                status: 'seen',
                deliveredTo: m.deliveredTo,
                seenBy: m.seenBy,
                replyTo: m.replyTo,
                createdAt: m.createdAt,
              );
            }
            return m;
          }).toList();
        });
      }
    });
  }

  Future<void> _fetchMessagesHistory() async {
    try {
      final list = await ChatApiService.instance.getMessages(
        _conversation.id,
        userId: _currentUserId,
      );
      if (mounted) {
        setState(() {
          _messages = list;
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error fetching history: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onTypingChanged(String text) {
    if (text.isNotEmpty) {
      ChatSocketService.instance.startTyping(_conversation.id, 'User');
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        ChatSocketService.instance.stopTyping(_conversation.id);
      });
    } else {
      ChatSocketService.instance.stopTyping(_conversation.id);
    }
  }

  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    ChatSocketService.instance.stopTyping(_conversation.id);

    ChatSocketService.instance.sendMessage(
      conversationId: _conversation.id,
      type: 'text',
      text: text,
      replyToId: _replyToMessage?.id,
    );

    setState(() {
      _replyToMessage = null;
    });
  }

  Future<void> _pickAndSendMedia(String source) async {
    final picker = ImagePicker();
    XFile? file;
    String type = 'image';

    if (source == 'camera') {
      file = await picker.pickImage(source: ImageSource.camera);
    } else if (source == 'gallery_image') {
      file = await picker.pickImage(source: ImageSource.gallery);
    } else if (source == 'gallery_video') {
      file = await picker.pickVideo(source: ImageSource.gallery);
      type = 'video';
    } else if (source == 'document') {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (res != null && res.files.isNotEmpty) {
        final f = res.files.first;
        await _uploadAndSendMessage(
          filePath: f.path ?? '',
          bytes: f.bytes,
          fileName: f.name,
          type: _determineFileType(f.extension),
        );
      }
      return;
    }

    if (file != null) {
      await _uploadAndSendMessage(
        filePath: file.path,
        fileName: file.name,
        type: type,
      );
    }
  }

  String _determineFileType(String? ext) {
    if (ext == null) return 'file';
    switch (ext.toLowerCase()) {
      case 'pdf': return 'pdf';
      case 'zip': return 'zip';
      case 'doc':
      case 'docx': return 'word';
      case 'xls':
      case 'xlsx': return 'excel';
      case 'ppt':
      case 'pptx': return 'powerpoint';
      case 'csv': return 'csv';
      case 'json': return 'json';
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'm4a': return 'audio';
      case 'mp4':
      case 'mov': return 'video';
      case 'jpg':
      case 'jpeg':
      case 'png': return 'image';
      default: return 'document';
    }
  }

  Future<void> _uploadAndSendMessage({
    required String filePath,
    Uint8List? bytes,
    required String fileName,
    required String type,
  }) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading attachment...'), duration: Duration(seconds: 2)),
      );

      final uploadRes = await ChatApiService.instance.uploadMedia(
        filePath: filePath,
        fileBytes: bytes,
        fileName: fileName,
      );

      final fileUrl = uploadRes['fileUrl']?.toString() ?? uploadRes['url']?.toString() ?? '';
      final fileSize = uploadRes['fileSize'] as int? ?? 0;
      final mimeType = uploadRes['mimeType']?.toString() ?? '';

      ChatSocketService.instance.sendMessage(
        conversationId: _conversation.id,
        type: type,
        text: fileName,
        mediaUrl: fileUrl,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
        replyToId: _replyToMessage?.id,
      );

      setState(() {
        _replyToMessage = null;
      });
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  void _showAttachmentPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAttachmentOption(
                    icon: Icons.camera_alt_rounded,
                    color: const Color(0xFFEF4444),
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndSendMedia('camera');
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.image_rounded,
                    color: const Color(0xFF3B82F6),
                    label: 'Photos',
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndSendMedia('gallery_image');
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.videocam_rounded,
                    color: const Color(0xFF10B981),
                    label: 'Videos',
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndSendMedia('gallery_video');
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.insert_drive_file_rounded,
                    color: const Color(0xFF8B5CF6),
                    label: 'Document',
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndSendMedia('document');
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF4B5563)),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(MessageModel msg) {
    final isMe = msg.sender.id == _currentUserId;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: Color(0xFF1A1A1A)),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _replyToMessage = msg;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Delete for me'),
                onTap: () async {
                  Navigator.pop(context);
                  await ChatApiService.instance.deleteMessage(msg.id, _currentUserId, action: 'for_me');
                  setState(() {
                    _messages.removeWhere((m) => m.id == msg.id);
                  });
                },
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                  title: const Text('Delete for everyone'),
                  onTap: () async {
                    Navigator.pop(context);
                    await ChatApiService.instance.deleteMessage(msg.id, _currentUserId, action: 'for_everyone');
                    setState(() {
                      _messages.removeWhere((m) => m.id == msg.id);
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    ChatSocketService.instance.leaveConversation(_conversation.id);
    _subNewMsg?.cancel();
    _subPresence?.cancel();
    _subTyping?.cancel();
    _subDelivered?.cancel();
    _subSeen?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _showGroupDetailsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFF1A1A1A),
                        backgroundImage: _conversation.groupAvatar != null && _conversation.groupAvatar!.isNotEmpty
                            ? CachedNetworkImageProvider(_conversation.groupAvatar!)
                            : null,
                        child: _conversation.groupAvatar == null || _conversation.groupAvatar!.isEmpty
                            ? Text(
                                _conversation.groupName?.isNotEmpty == true ? _conversation.groupName![0].toUpperCase() : 'G',
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _conversation.groupName ?? 'Group Chat',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                            ),
                            if (_conversation.groupDescription != null && _conversation.groupDescription!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _conversation.groupDescription!,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Members (${_conversation.participants.length})',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4B5563)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _conversation.participants.length,
                    itemBuilder: (context, index) {
                      final member = _conversation.participants[index];
                      final isAdmin = _conversation.groupAdmin?.id == member.id;
                      final isMe = member.id == _currentUserId;

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFE5E7EB),
                          backgroundImage: member.avatar != null && member.avatar!.isNotEmpty
                              ? CachedNetworkImageProvider(member.avatar!)
                              : null,
                          child: member.avatar == null || member.avatar!.isEmpty
                              ? Text(
                                  member.name.isNotEmpty ? member.name[0].toUpperCase() : 'U',
                                  style: const TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        title: Text(
                          isMe ? 'You' : member.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        trailing: isAdmin
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: const Text(
                                  'Admin',
                                  style: TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              )
                            : null,
                        onTap: isMe
                            ? null
                            : () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/OtheruserProfile/${member.id}');
                              },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleAppBarTap() {
    if (_conversation.isGroup) {
      _showGroupDetailsSheet(context);
    } else {
      final other = _conversation.getOtherParticipant(_currentUserId);
      if (other != null && other.id != 'unknown') {
        Navigator.pushNamed(context, '/OtheruserProfile/${other.id}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _conversation.getDisplayName(_currentUserId);
    final avatar = _conversation.getDisplayAvatar(_currentUserId);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A1A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleAppBarTap,
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF1A1A1A),
                    backgroundImage: avatar != null && avatar.isNotEmpty
                        ? CachedNetworkImageProvider(avatar)
                        : null,
                    child: avatar == null || avatar.isEmpty
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'C',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  if (_isOtherOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _isOtherTyping
                          ? (_conversation.isGroup && _typingUsername.isNotEmpty
                              ? '$_typingUsername is typing...'
                              : 'typing...')
                          : (_isOtherOnline ? 'Online' : 'Offline'),
                      style: TextStyle(
                        fontSize: 12,
                        color: _isOtherTyping ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF),
                        fontWeight: _isOtherTyping ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A1A1A)))
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'No messages yet. Say hello!',
                          style: TextStyle(color: Color(0xFF9CA3AF)),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg.sender.id == _currentUserId;
                          return _buildMessageBubble(msg, isMe);
                        },
                      ),
          ),

          // Reply Preview Box
          if (_replyToMessage != null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 36,
                    color: const Color(0xFF1A1A1A),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to ${_replyToMessage!.sender.name}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                        ),
                        Text(
                          _replyToMessage!.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      setState(() {
                        _replyToMessage = null;
                      });
                    },
                  ),
                ],
              ),
            ),

          // Bottom Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_rounded, color: Color(0xFF4B5563), size: 26),
                    onPressed: _showAttachmentPicker,
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _textController,
                        onChanged: _onTypingChanged,
                        style: const TextStyle(fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendTextMessage,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A1A1A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel msg, bool isMe) {
    return GestureDetector(
      onLongPress: () => _showMessageOptions(msg),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/OtheruserProfile/${msg.sender.id}');
                },
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF9CA3AF),
                  backgroundImage: msg.sender.avatar != null && msg.sender.avatar!.isNotEmpty
                      ? CachedNetworkImageProvider(msg.sender.avatar!)
                      : null,
                  child: msg.sender.avatar == null || msg.sender.avatar!.isEmpty
                      ? Text(
                          msg.sender.name.isNotEmpty ? msg.sender.name[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender name in group chat
                  if (!isMe && _conversation.isGroup)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/OtheruserProfile/${msg.sender.id}');
                        },
                        child: Text(
                          msg.sender.name,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ),

                  // Reply content if any
                  if (msg.replyTo != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.white12 : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${msg.replyTo!.sender.name}: ${msg.replyTo!.text}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe ? Colors.white70 : const Color(0xFF4B5563),
                        ),
                      ),
                    ),

                  // Message Content Body by Type
                  _buildMessageBody(msg, isMe),

                  const SizedBox(height: 4),

                  // Time & Ticks
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${msg.createdAt.hour}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white70 : const Color(0xFF9CA3AF),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _buildStatusTicks(msg.status),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBody(MessageModel msg, bool isMe) {
    final textColor = isMe ? Colors.white : const Color(0xFF111827);

    switch (msg.type) {
      case MessageType.image:
        final hasMedia = msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasMedia)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 200,
                  height: 200,
                  color: Colors.grey[200],
                  child: CachedNetworkImage(
                    imageUrl: msg.mediaUrl!,
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: Color(0xFFfb5404), strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) {
                      debugPrint('💬 [Chat] Image load failed: $error for URL: ${msg.mediaUrl}');
                      return Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (msg.text.isNotEmpty && msg.text != msg.fileName) ...[
              const SizedBox(height: 6),
              Text(msg.text, style: TextStyle(color: textColor, fontSize: 14)),
            ],
          ],
        );

      case MessageType.video:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 48),
              ),
            ),
            const SizedBox(height: 4),
            Text(msg.text, style: TextStyle(color: textColor, fontSize: 13)),
          ],
        );

      case MessageType.audio:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded, color: isMe ? Colors.white : const Color(0xFF1A1A1A), size: 28),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: isMe ? Colors.white38 : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('Audio', style: TextStyle(color: textColor, fontSize: 12)),
          ],
        );

      case MessageType.document:
      case MessageType.pdf:
      case MessageType.excel:
      case MessageType.word:
      case MessageType.powerpoint:
      case MessageType.zip:
      case MessageType.json:
      case MessageType.csv:
      case MessageType.file:
        return GestureDetector(
          onTap: () {
            if (msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty) {
              launchUrl(Uri.parse(msg.mediaUrl!), mode: LaunchMode.externalApplication);
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getFileIcon(msg.type), color: isMe ? Colors.white : const Color(0xFF1A1A1A), size: 32),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg.fileName ?? msg.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      msg.type.name.toUpperCase(),
                      style: TextStyle(
                        color: isMe ? Colors.white70 : const Color(0xFF6B7280),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      default:
        return Text(
          msg.text,
          style: TextStyle(color: textColor, fontSize: 14, height: 1.3),
        );
    }
  }

  IconData _getFileIcon(MessageType type) {
    switch (type) {
      case MessageType.pdf: return Icons.picture_as_pdf_rounded;
      case MessageType.excel: return Icons.table_chart_rounded;
      case MessageType.word: return Icons.description_rounded;
      case MessageType.powerpoint: return Icons.slideshow_rounded;
      case MessageType.zip: return Icons.folder_zip_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  Widget _buildStatusTicks(String status) {
    if (status == 'seen') {
      return const Icon(Icons.done_all_rounded, color: Color(0xFF60A5FA), size: 14);
    } else if (status == 'delivered') {
      return const Icon(Icons.done_all_rounded, color: Colors.white70, size: 14);
    } else {
      return const Icon(Icons.check_rounded, color: Colors.white70, size: 14);
    }
  }
}
