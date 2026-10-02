import 'dart:convert';
import 'dart:io';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
  InAppWebViewController? _controller;
  String? _error;
  bool _pageLoaded = false;
  WebUri? _initialUri;
  String? _userAgent;

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

    try {
      final cookies = await _exchangeSessionCookies(token);
      final cookieManager = CookieManager.instance();
      for (final c in cookies) {
        await cookieManager.setCookie(
          url: WebUri(traccarBaseUrl),
          name: c.name,
          value: c.value,
          path: c.path ?? '/',
          domain: c.domain,
          isSecure: c.secure,
          isHttpOnly: c.httpOnly,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not exchange session');
      return;
    }

    final defaultUa = await InAppWebViewController.getDefaultUserAgent();
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _userAgent = '$defaultUa ${packageInfo.packageName}';
      _initialUri = WebUri('$traccarBaseUrl/reports');
    });
  }

  Future<List<io.Cookie>> _exchangeSessionCookies(String token) async {
    final client = io.HttpClient();
    try {
      final uri = Uri.parse(
        '$traccarBaseUrl/api/session?token=${Uri.encodeComponent(token)}',
      );
      final request = await client.getUrl(uri);
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      return response.cookies;
    } finally {
      client.close();
    }
  }

  Future<void> _print() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.printCurrentPage();
  }

  Future<void> _handleDownload(DownloadStartRequest request) async {
    final url = request.url;
    final urlStr = url.toString();
    final suggestedName = request.suggestedFilename?.trim();
    final isUsableSuggested =
        suggestedName != null && suggestedName.isNotEmpty && suggestedName != 'Unknown';

    try {
      final Uint8List bytes;
      String fileName;

      if (urlStr.startsWith('blob:')) {
        final result = await _readBlobFromWebView(urlStr);
        bytes = result.bytes;
        final mimeExt = _extensionForMime(result.mime);
        final ext = mimeExt.isEmpty ? '.xlsx' : mimeExt;
        final base = isUsableSuggested
            ? suggestedName
            : 'report_${DateTime.now().millisecondsSinceEpoch}';
        fileName = base.contains('.') ? base : '$base$ext';
      } else {
        final cookies = await CookieManager.instance().getCookies(url: url);
        final cookieHeader =
            cookies.map((c) => '${c.name}=${c.value}').join('; ');
        final headers = <String, String>{
          if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          if (request.userAgent != null && request.userAgent!.isNotEmpty)
            'User-Agent': request.userAgent!,
        };
        final response =
            await http.get(Uri.parse(urlStr), headers: headers);
        if (response.statusCode != 200) {
          throw HttpException('HTTP ${response.statusCode}');
        }
        bytes = response.bodyBytes;
        fileName = isUsableSuggested
            ? suggestedName
            : (_filenameFromUrl(url) ??
                'download_${DateTime.now().millisecondsSinceEpoch}');
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download failed')),
      );
    }
  }

  Future<_BlobResult> _readBlobFromWebView(String blobUrl) async {
    final controller = _controller;
    if (controller == null) throw Exception('No controller');
    final result = await controller.callAsyncJavaScript(
      functionBody: r'''
        const response = await fetch(blobUrl);
        const blob = await response.blob();
        const dataUrl = await new Promise((resolve, reject) => {
          const reader = new FileReader();
          reader.onloadend = () => resolve(reader.result);
          reader.onerror = () => reject(reader.error);
          reader.readAsDataURL(blob);
        });
        return { dataUrl: dataUrl, mime: blob.type || '' };
      ''',
      arguments: {'blobUrl': blobUrl},
    );
    if (result == null || result.error != null || result.value == null) {
      throw Exception('Blob read failed: ${result?.error}');
    }
    final value = Map<String, dynamic>.from(result.value as Map);
    final dataUrl = value['dataUrl'] as String;
    final commaIdx = dataUrl.indexOf(',');
    if (commaIdx < 0) throw Exception('Malformed data URL');
    final bytes = base64Decode(dataUrl.substring(commaIdx + 1));
    return _BlobResult(bytes: bytes, mime: (value['mime'] as String?) ?? '');
  }

  String _extensionForMime(String mime) {
    switch (mime) {
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        return '.xlsx';
      case 'application/vnd.ms-excel':
        return '.xls';
      case 'text/csv':
        return '.csv';
      case 'application/pdf':
        return '.pdf';
      case 'application/json':
        return '.json';
      case 'text/plain':
        return '.txt';
      default:
        return '';
    }
  }

  String? _filenameFromUrl(WebUri url) {
    final segments = url.pathSegments;
    if (segments.isEmpty) return null;
    final last = segments.last;
    return last.isEmpty ? null : last;
  }

  Future<void> _exportPdf() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.evaluateJavascript(source: _enablePrintCssJs);
    final Uint8List? bytes;
    try {
      bytes = await controller.createPdf();
    } finally {
      await controller.evaluateJavascript(source: _restorePrintCssJs);
    }
    if (!mounted) return;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not generate PDF')),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/report_$ts.pdf');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
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
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: _pageLoaded ? _exportPdf : null,
                  tooltip: 'PDF',
                ),
                IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: _pageLoaded ? _print : null,
                  tooltip: 'Print',
                ),
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
                  setState(() {
                    _error = null;
                    _pageLoaded = false;
                    _initialUri = null;
                    _userAgent = null;
                  });
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
      fit: StackFit.expand,
      children: [
        if (_initialUri != null)
          InAppWebView(
            initialUrlRequest: URLRequest(url: _initialUri),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              useOnDownloadStart: true,
              userAgent: _userAgent,
            ),
            onWebViewCreated: (controller) => _controller = controller,
            onDownloadStartRequest: (controller, request) =>
                _handleDownload(request),
            onLoadStop: (controller, url) {
              if (mounted) setState(() => _pageLoaded = true);
            },
          ),
        if (!_pageLoaded)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.white,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

class _BlobResult {
  final Uint8List bytes;
  final String mime;
  const _BlobResult({required this.bytes, required this.mime});
}

const _enablePrintCssJs = r'''
(() => {
  window.__origPrintMedia = [];
  document.querySelectorAll('link[rel="stylesheet"]').forEach((l) => {
    if (l.media && l.media.toLowerCase().includes('print')) {
      window.__origPrintMedia.push({ link: l, media: l.media });
      l.media = 'all';
    }
  });
  for (const sheet of Array.from(document.styleSheets)) {
    let rules;
    try { rules = sheet.cssRules; } catch (_) { continue; }
    if (!rules) continue;
    for (const rule of Array.from(rules)) {
      if (rule.type === CSSRule.MEDIA_RULE) {
        const mt = rule.media.mediaText;
        if (mt && mt.toLowerCase().includes('print')) {
          window.__origPrintMedia.push({ rule: rule, media: mt });
          rule.media.mediaText = 'all';
        }
      }
    }
  }
})();
''';

const _restorePrintCssJs = r'''
(() => {
  const entries = window.__origPrintMedia || [];
  for (const e of entries) {
    if (e.link) e.link.media = e.media;
    else if (e.rule) e.rule.media.mediaText = e.media;
  }
  window.__origPrintMedia = [];
})();
''';
