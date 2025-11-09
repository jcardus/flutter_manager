import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel createWebSocketChannel(Uri uri, {Map<String, dynamic>? headers}) {
  // Browser will handle cookies automatically; headers are ignored.
  return HtmlWebSocketChannel.connect(uri.toString());
}
