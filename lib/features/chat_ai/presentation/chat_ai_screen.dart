import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/storage/session_store.dart';

class ChatAiScreen extends StatefulWidget {
  final String? userId;
  final bool isModal;

  const ChatAiScreen({super.key, this.userId, this.isModal = false});

  @override
  State<ChatAiScreen> createState() => _ChatAiScreenState();
}

class _ChatAiScreenState extends State<ChatAiScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _resolvedUserId = 'guest';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("Chat AI WebView Error: ${error.description}");
          },
        ),
      );
    
    _loadUserIdAndUrl();
  }

  Future<void> _loadUserIdAndUrl() async {
    String? id = widget.userId;
    if (id == null || id.isEmpty) {
      // Try from SessionStore
      final loggedIn = await SessionStore.isLoggedIn();
      if (loggedIn) {
        id = await SessionStore.getUserId();
      }
      
      // Fallback to SharedPreferences if SessionStore is empty
      if (id == null || id.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        id = prefs.getString('user_id') ?? '';
      }
    }

    if (id != null && id.isNotEmpty) {
      _resolvedUserId = id;
    }

    final chatUrl = 'https://ai.welfog.com/?user_id=$_resolvedUserId&chat_id=81a964ab89882e1292d67409a5faa8e9';
    
    if (mounted) {
      _controller.loadRequest(Uri.parse(chatUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            widget.isModal ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
            color: Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Welfog AI Assistant',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
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
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF6A00),
              ),
            ),
        ],
      ),
    );
  }
}
