import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/storage/session_store.dart';

class ChatAiScreen extends StatefulWidget {
  final String? userId;
  final bool isModal;
  final VoidCallback? onClose;

  const ChatAiScreen({
    super.key,
    this.userId,
    this.isModal = false,
    this.onClose,
  });

  @override
  State<ChatAiScreen> createState() => _ChatAiScreenState();
}

class _ChatAiScreenState extends State<ChatAiScreen> {
  static const _prefsChatIdKey = 'ai_chat_last_chat_id';
  static const _aiBaseUrl = 'https://ai.welfog.com/';

  late final WebViewController _controller;
  bool _isLoading = true;
  bool _didLoadUrl = false;
  String _resolvedUserId = 'guest';
  String? _lastChatId;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
            _persistChatIdFromUrl(url);
          },
          onUrlChange: (UrlChange change) {
            final url = change.url;
            if (url != null) _persistChatIdFromUrl(url);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("Chat AI WebView Error: ${error.description}");
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            debugPrint("Chat AI WebView navigating to: $url");

            // 1. Intercept custom app scheme links (e.g. app://product/slug)
            if (url.startsWith('app://product/')) {
              final slug = url.replaceFirst('app://product/', '').trim();
              if (slug.isNotEmpty) {
                Navigator.of(context).pushNamed(
                  AppRoutes.product,
                  arguments: slug,
                );
                return NavigationDecision.prevent;
              }
            }

            // 2. Intercept standard website links
            final lowerUrl = url.toLowerCase();
            if (lowerUrl.contains('/products/') ||
                lowerUrl.contains('/product/')) {
              try {
                final uri = Uri.parse(url);
                final segments =
                    uri.pathSegments.where((s) => s.isNotEmpty).toList();
                if (segments.isNotEmpty) {
                  final slug = segments.last;
                  Navigator.of(context).pushNamed(
                    AppRoutes.product,
                    arguments: slug,
                  );
                  return NavigationDecision.prevent;
                }
              } catch (e) {
                debugPrint("Error parsing product URL: $e");
              }
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterNavigation',
        onMessageReceived: (JavaScriptMessage message) {
          final slug = message.message.trim();
          debugPrint("Received navigation command from JS Channel: $slug");
          if (slug.isNotEmpty) {
            Navigator.of(context).pushNamed(
              AppRoutes.product,
              arguments: slug,
            );
          }
        },
      );

    _loadUserIdAndUrl();
  }

  @override
  void didUpdateWidget(covariant ChatAiScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If logged-in user changes, reload AI session for that user.
    final nextId = widget.userId?.trim() ?? '';
    final prevId = oldWidget.userId?.trim() ?? '';
    if (nextId.isNotEmpty &&
        nextId != prevId &&
        nextId != _resolvedUserId &&
        nextId != 'guest') {
      _resolvedUserId = nextId;
      _reloadForCurrentUser();
    }
  }

  Future<void> _persistChatIdFromUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final chatId = (uri.queryParameters['chat_id'] ??
              uri.queryParameters['chatId'] ??
              '')
          .trim();
      if (chatId.isEmpty || chatId == _lastChatId) return;
      _lastChatId = chatId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsChatIdKey, chatId);
    } catch (_) {}
  }

  Future<void> _loadUserIdAndUrl() async {
    String? id = widget.userId;
    if (id == null || id.isEmpty) {
      final loggedIn = await SessionStore.isLoggedIn();
      if (loggedIn) {
        id = await SessionStore.getUserId();
      }

      if (id == null || id.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        id = prefs.getString('user_id') ?? '';
      }
    }

    // ignore: dead_null_aware_expression
    final resolved = (id ?? '').trim();
    if (resolved.isNotEmpty) {
      _resolvedUserId = resolved;
    }

    final prefs = await SharedPreferences.getInstance();
    _lastChatId = prefs.getString(_prefsChatIdKey);

    if (!mounted || _didLoadUrl) return;
    _didLoadUrl = true;
    _controller.loadRequest(Uri.parse(_buildChatUrl()));
  }

  String _buildChatUrl() {
    final params = <String, String>{
      'user_id': _resolvedUserId,
    };
    final chatId = _lastChatId?.trim();
    if (chatId != null && chatId.isNotEmpty) {
      params['chat_id'] = chatId;
    }
    return Uri.parse(_aiBaseUrl).replace(queryParameters: params).toString();
  }

  Future<void> _reloadForCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    _lastChatId = prefs.getString(_prefsChatIdKey);
    if (!mounted) return;
    await _controller.loadRequest(Uri.parse(_buildChatUrl()));
  }

  void _handleClose() {
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isModal,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.isModal) {
          _handleClose();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(
              widget.isModal
                  ? Icons.close_rounded
                  : Icons.arrow_back_ios_new_rounded,
              color: Colors.black,
            ),
            onPressed: _handleClose,
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
      ),
    );
  }
}
