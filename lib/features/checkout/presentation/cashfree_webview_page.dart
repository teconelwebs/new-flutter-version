import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CashfreeWebViewPage extends StatefulWidget {
  final String sessionId;
  final String orderId;

  const CashfreeWebViewPage({
    super.key,
    required this.sessionId,
    required this.orderId,
  });

  @override
  State<CashfreeWebViewPage> createState() => _CashfreeWebViewPageState();
}

class _CashfreeWebViewPageState extends State<CashfreeWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
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
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            // Check if redirecting back to our backend
            if (url.contains('welfog.com') &&
                url != 'https://api.welfog.com/' &&
                url != 'https://api.welfog.com' &&
                url != 'https://welfogapi.welfog.com/' &&
                url != 'https://welfogapi.welfog.com') {
              // Navigation intercepted. Close the webview and trigger callback verification.
              Navigator.of(context).pop(true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    // Load the HTML string with Cashfree JS SDK v3 checkout
    final html = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      body { margin:0; font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Arial; }
      #status { padding:16px; color:#333; font-size:14px; }
    </style>
    <script src="https://sdk.cashfree.com/js/v3/cashfree.js"></script>
</head>
<body>
    <div id="status">Opening Cashfree checkout...</div>
    <script>
      (function () {
        function setStatus(t) {
          var el = document.getElementById("status");
          if (el) el.innerText = t;
        }
        try {
          var sessionId = "${widget.sessionId}";
          if (!sessionId) {
            setStatus("Missing paymentSessionId.");
            return;
          }
          var cashfree = Cashfree({ mode: "production" });
          setStatus("Launching checkout...");
          cashfree.checkout({ paymentSessionId: sessionId });
        } catch (e) {
          setStatus("Failed to launch checkout: " + (e && e.message ? e.message : String(e)));
          console.log("Cashfree web error", e);
        }
      })();
    </script>
</body>
</html>
''';

    _controller.loadHtmlString(html, baseUrl: 'https://api.welfog.com');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cashfree Payment'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF008083),
              ),
            ),
        ],
      ),
    );
  }
}
