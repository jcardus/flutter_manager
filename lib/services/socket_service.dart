import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb, VoidCallback;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../utils/constants.dart';
import 'auth_service.dart';

class SocketService {
  final _messageController = StreamController<dynamic>.broadcast();
  Stream<dynamic> get stream => _messageController.stream;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  bool _disposed = false;
  bool _connected = false;
  int _reconnectAttempts = 0;
  DateTime? lastMessageTime;

  bool get isConnected => _connected;

  VoidCallback? onStatusChanged;

  Future<bool> connect() async {
    if (_disposed || kIsWeb) return false;

    var wsUrl = String.fromEnvironment('WEBSOCKET_URL');
    if (wsUrl.isEmpty) {
      final base = traccarBaseUrl;
      if (base.isEmpty) return false;
      final wsScheme = base.startsWith('https') ? 'wss' : 'ws';
      wsUrl = '${base.replaceFirst(RegExp('^https?'), wsScheme)}/api/socket';
    }

    try {
      final cookie = await AuthService().getCookie();
      final headers = <String, dynamic>{};
      if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;

      _channel = IOWebSocketChannel.connect(Uri.parse(wsUrl), headers: headers);
      _sub = _channel!.stream.listen(
        (message) {
          lastMessageTime = DateTime.now();
          _messageController.add(message);
        },
        onError: (e) {
          dev.log('[WS] Error: $e', name: 'WS');
          _setConnected(false);
          _scheduleReconnect();
        },
        onDone: () {
          dev.log('[WS] Closed', name: 'WS');
          _setConnected(false);
          _scheduleReconnect();
        },
      );

      _reconnectAttempts = 0;
      _setConnected(true);
      dev.log('[WS] Connected to $wsUrl', name: 'TraccarWS');
      return true;
    } catch (e) {
      dev.log('[WS] Connection error: $e', name: 'TraccarWS', level: 1000);
      _channel = null;
      _setConnected(false);
      _scheduleReconnect();
      return false;
    }
  }

  void _setConnected(bool value) {
    _connected = value;
    onStatusChanged?.call();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    final seconds = min(30, pow(2, _reconnectAttempts).toInt());
    _reconnectAttempts++;
    dev.log('[WS] Reconnecting in ${seconds}s (attempt $_reconnectAttempts)', name: 'WS');
    Future.delayed(Duration(seconds: seconds), () {
      if (!_disposed) {
        _sub?.cancel();
        try { _channel?.sink.close(); } catch (_) {}
        _channel = null;
        connect();
      }
    });
  }

  Future<void> close() async {
    _disposed = true;
    await _sub?.cancel();
    try { await _channel?.sink.close(); } catch (_) {}
    _channel = null;
    await _messageController.close();
  }
}
