import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class ReportsWebView extends StatefulWidget {
  final VoidCallback? onBack;

  const ReportsWebView({super.key, this.onBack});

  @override
  State<ReportsWebView> createState() => _ReportsWebViewState();
}

class _ReportsWebViewState extends State<ReportsWebView> {
  WebViewController? _controller;
  String? _error;
  bool _sessionExchanged = false;
  bool _pageLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await AuthService().fetchSessionToken();
    if (!mounted) return;
    if (token == null) {
      setState(() => _error = 'Could not obtain session token');
      return;
    }

    final sessionUri = Uri.parse(
      '$traccarBaseUrl/api/session?token=${Uri.encodeComponent(token)}',
    );
    final reportsUri = Uri.parse('$traccarBaseUrl/reports?hideSidebar=1');

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            if (!_sessionExchanged && url.contains('/api/session')) {
              _sessionExchanged = true;
              _controller?.loadRequest(reportsUri);
              return;
            }
            if (_sessionExchanged && mounted) {
              setState(() => _pageLoaded = true);
            }
          },
        ),
      )
      ..loadRequest(sessionUri);

    setState(() => _controller = controller);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBack,
                ),
                Text(l10n.reports,
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  setState(() => _error = null);
                  _load();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        if (_controller != null) WebViewWidget(controller: _controller!),
        if (!_pageLoaded)
          const ColoredBox(
            color: Colors.white,
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
