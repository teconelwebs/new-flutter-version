import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/account_api_service.dart';

class PolicyScreen extends StatefulWidget {
  final String slug;

  const PolicyScreen({super.key, required this.slug});

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  final _api = AccountApiService();
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;
  String? _updatedAt;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white);
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _api.fetchPolicyPage(widget.slug);
      if (data == null) {
        setState(() {
          _error = 'Failed to load policy content.';
          _loading = false;
        });
        return;
      }

      final content = data['content'] as String? ?? '';
      _updatedAt = data['updated_at'] as String?;

      final html = '''
        <!DOCTYPE html>
        <html>
          <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
              * {
                max-width: 100%;
                box-sizing: border-box;
              }
              body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                font-size: 14px;
                line-height: 1.6;
                color: #333333;
                padding: 16px;
                margin: 0;
                background-color: #ffffff;
                overflow-x: hidden;
                word-wrap: break-word;
              }
              html {
                overflow-x: hidden;
              }
              h1, h2, h3, h4, h5, h6 {
                color: #1a1a1a;
                font-weight: 700;
                margin-top: 20px;
                margin-bottom: 12px;
                word-wrap: break-word;
                overflow-wrap: break-word;
              }
              h1 { font-size: 20px; }
              h2 { font-size: 18px; }
              h3 { font-size: 16px; }
              p {
                margin-bottom: 12px;
                color: #333333;
                word-wrap: break-word;
                overflow-wrap: break-word;
              }
              ul, ol {
                margin-bottom: 12px;
                padding-left: 20px;
                word-wrap: break-word;
                overflow-wrap: break-word;
              }
              li {
                margin-bottom: 8px;
                color: #333333;
                word-wrap: break-word;
                overflow-wrap: break-word;
              }
              strong {
                font-weight: 600;
                color: #1a1a1a;
              }
              img, table {
                max-width: 100%;
                height: auto;
              }
              table {
                width: 100%;
                table-layout: fixed;
              }
            </style>
          </head>
          <body>
            $content
          </body>
        </html>
      ''';

      await _controller.loadHtmlString(html);

      setState(() {
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Failed to load policy content.';
        _loading = false;
      });
    }
  }

  String _formatSlug(String slug) {
    if (slug.isEmpty) return '';
    return slug
        .split('-')
        .map((word) => word.substring(0, 1).toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = months[date.month - 1];
      final day = date.day.toString().padLeft(2, '0');
      final year = date.year;
      final hourVal = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '$month $day, $year $hourVal:$minute $period';
    } catch (_) {
      return dateStr;
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A1A), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _formatSlug(widget.slug),
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(
            color: const Color(0xFFE5E7EB),
            height: 0.5,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFB5404)),
            ),
            SizedBox(height: 12),
            Text(
              'Loading content...',
              style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 48),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _fetch,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFB5404),
                  side: const BorderSide(color: Color(0xFFFB5404)),
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_updatedAt != null) ...[
          Container(
            color: const Color(0xFFF9FAFB),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.access_time_filled_rounded, color: Color(0xFF666666), size: 16),
                const SizedBox(width: 8),
                Text(
                  'Last Updated: ${_formatDate(_updatedAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(color: const Color(0xFFE5E7EB), height: 0.5),
        ],
        Expanded(
          child: WebViewWidget(controller: _controller),
        ),
      ],
    );
  }
}
