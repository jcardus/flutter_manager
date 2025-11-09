import 'dart:developer' as dev;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../env/env.dart';
import 'traccar_auth_service.dart';
import 'ws_channel_factory_io.dart' if (dart.library.html) 'ws_channel_factory_web.dart';

/// Simple Traccar WebSocket client that connects to /api/socket using the
/// existing session cookie (JSESSIONID).
class TraccarSocketService {
  WebSocketChannel? _channel;

  WebSocketChannel? get channel => _channel;
  Stream<dynamic>? get stream => _channel?.stream;

  /// Open the WebSocket connection. Returns true if the socket was created.
  Future<bool> connect() async {
    if (_channel != null) return true; // already connected/connecting
    final base = Env.traccarBaseUrl;
    if (base.isEmpty) return false;

    // Build ws/wss URL
    final wsScheme = base.startsWith('https') ? 'wss' : 'ws';
    final wsUrl = base.replaceFirst(RegExp('^https?'), wsScheme) + '/api/socket';

    try {
      final cookie = await TraccarAuthService().getCookie();
      final headers = <String, dynamic>{};
      if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;
      _channel = createWebSocketChannel(Uri.parse(wsUrl), headers: headers);
      dev.log('[WS] Connected to $wsUrl', name: 'TraccarWS');
      return true;
    } catch (e) {
      dev.log('[WS] Connection error: $e', name: 'TraccarWS', level: 1000);
      _channel = null;
      return false;
    }
  }

  /// Close the WebSocket connection.
  Future<void> close([int? code, String? reason]) async {
    try {
      await _channel?.sink.close(code, reason);
    } catch (_) {}
    _channel = null;
  }
}