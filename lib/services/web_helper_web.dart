// Web implementation using package:web
import 'package:web/web.dart' as web;

String? getTokenFromUrl() {
  final uri = Uri.parse(web.window.location.href);
  return uri.queryParameters['token'];
}