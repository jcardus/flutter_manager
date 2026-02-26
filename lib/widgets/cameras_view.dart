import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/device.dart';
import '../l10n/app_localizations.dart';

const _urlKeys = ['cameraUrl', 'streamUrl', 'camera', 'videoUrl'];
const _url2Keys = ['cameraUrl2', 'streamUrl2', 'videoUrl2'];

List<String> getCameraUrls(Device device) {
  final attrs = device.attributes ?? {};
  final urls = <String>[];
  for (final key in _urlKeys) {
    final val = attrs[key];
    if (val is String && val.trim().isNotEmpty) {
      urls.add(val.trim());
      break;
    }
  }
  for (final key in _url2Keys) {
    final val = attrs[key];
    if (val is String && val.trim().isNotEmpty) {
      urls.add(val.trim());
      break;
    }
  }
  return urls;
}

bool _isRtsp(String url) =>
    url.startsWith('rtsp://') || url.startsWith('rtsps://');

bool _isHttps(String url) => url.startsWith('https://');

class CamerasView extends StatelessWidget {
  final Map<int, Device> devices;

  const CamerasView({super.key, required this.devices});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final cameras = <({Device device, String url, int? channel})>[];
    for (final device in devices.values) {
      final urls = getCameraUrls(device);
      if (urls.isEmpty) continue;
      if (urls.length == 1) {
        cameras.add((device: device, url: urls[0], channel: null));
      } else {
        for (var i = 0; i < urls.length; i++) {
          cameras.add((device: device, url: urls[i], channel: i + 1));
        }
      }
    }

    if (cameras.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off_outlined,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.noCameras,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.noCamerasHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 16 / 11,
      ),
      itemCount: cameras.length,
      itemBuilder: (context, i) {
        final cam = cameras[i];
        return _CameraCard(
          device: cam.device,
          url: cam.url,
          channel: cam.channel,
        );
      },
    );
  }
}

class _CameraCard extends StatelessWidget {
  final Device device;
  final String url;
  final int? channel;

  const _CameraCard({
    required this.device,
    required this.url,
    this.channel,
  });

  String get _label =>
      channel != null ? '${device.name} — CH$channel' : device.name;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              _FullScreenCamera(device: device, url: url, channel: channel),
        ),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: CameraFeed(url: url, label: _label)),
            _CameraLabel(
              label: _label,
              isOnline: device.status == 'online',
            ),
          ],
        ),
      ),
    );
  }
}

class CameraFeed extends StatefulWidget {
  final String url;
  final String label;

  const CameraFeed({super.key, required this.url, required this.label});

  @override
  State<CameraFeed> createState() => _CameraFeedState();
}

class _CameraFeedState extends State<CameraFeed> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    if (_isHttps(widget.url)) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRtsp(widget.url)) return _RtspPlaceholder(url: widget.url);
    if (!_isHttps(widget.url)) return const _InsecurePlaceholder();
    return WebViewWidget(controller: _controller!);
  }
}

class _CameraLabel extends StatelessWidget {
  final String label;
  final bool isOnline;

  const _CameraLabel({required this.label, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline
                  ? Colors.green
                  : Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _RtspPlaceholder extends StatefulWidget {
  final String url;

  const _RtspPlaceholder({required this.url});

  @override
  State<_RtspPlaceholder> createState() => _RtspPlaceholderState();
}

class _RtspPlaceholderState extends State<_RtspPlaceholder> {
  bool _copied = false;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.url));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ColoredBox(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_outlined, color: Colors.white30, size: 32),
          const SizedBox(height: 8),
          Text(
            l10n.rtspStream,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _copy,
            icon: Icon(
              _copied ? Icons.check : Icons.copy,
              size: 14,
              color: Colors.white54,
            ),
            label: Text(
              _copied ? l10n.copied : l10n.copyUrl,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsecurePlaceholder extends StatelessWidget {
  const _InsecurePlaceholder();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ColoredBox(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_open_outlined, color: Colors.white30, size: 32),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              l10n.insecureStream,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _FullScreenCamera extends StatelessWidget {
  final Device device;
  final String url;
  final int? channel;

  const _FullScreenCamera({
    required this.device,
    required this.url,
    this.channel,
  });

  String get _label =>
      channel != null ? '${device.name} — CH$channel' : device.name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_label),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: device.status == 'online' ? Colors.green : Colors.grey,
              ),
            ),
          ),
        ],
      ),
      body: CameraFeed(url: url, label: _label),
    );
  }
}
