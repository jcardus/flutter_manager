import 'dart:developer' as dev;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/map_constants.dart';
import 'auth_service.dart';
import 'package:web_socket_channel/io.dart';

class SocketService {
  WebSocketChannel? _channel;

  WebSocketChannel? get channel => _channel;
  Stream<dynamic>? get stream => _channel?.stream;

  /// Open the WebSocket connection. Returns true if the socket was created.
  Future<bool> connect() async {
    if (_channel != null) return true; // already connected/connecting

    // Web doesn't support WebSocket
    if (kIsWeb) return false;

    final base = traccarBaseUrl;
    if (base.isEmpty) return false;

    // Build ws/wss URL
    final wsScheme = base.startsWith('https') ? 'wss' : 'ws';
    final wsUrl = '${base.replaceFirst(RegExp('^https?'), wsScheme)}/api/socket';

    try {
      final cookie = await AuthService().getCookie();
      final headers = <String, dynamic>{};
      if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;
      _channel = IOWebSocketChannel.connect(Uri.parse(wsUrl), headers: headers);
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
