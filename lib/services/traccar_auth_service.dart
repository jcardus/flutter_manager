import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../env/env.dart';

/// Traccar authentication and session utilities.
///
/// Traccar uses a session cookie (typically JSESSIONID). We store it so we can
/// attach it to subsequent requests after app restarts.
class TraccarAuthService {
  static const String _cookieKey = 'traccar_cookie';
  static const String _userKey = 'traccar_user';

  /// Returns the Traccar base URL. Configure via --dart-define=TRACCAR_BASE_URL
  /// or edit Env.traccarBaseUrl default.
  static String get baseUrl => Env.traccarBaseUrl;

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<void> _saveCookie(String cookie) async {
    final p = await _prefs;
    await p.setString(_cookieKey, cookie);
  }

  Future<String?> _getCookie() async {
    final p = await _prefs;
    return p.getString(_cookieKey);
  }

  /// Exposes the stored session cookie (e.g., JSESSIONID=...) for services that
  /// need to attach it to non-HTTP-client channels (like WebSockets on IO).
  Future<String?> getCookie() => _getCookie();

  Future<void> _clearCookie() async {
    final p = await _prefs;
    await p.remove(_cookieKey);
  }

  Future<void> _saveUser(Map<String, dynamic> user) async {
    final p = await _prefs;
    await p.setString(_userKey, jsonEncode(user));
  }

  Future<Map<String, dynamic>?> getUser() async {
    final p = await _prefs;
    final raw = p.getString(_userKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearUser() async {
    final p = await _prefs;
    await p.remove(_userKey);
  }

  Map<String, String> _headersWithCookie([Map<String, String>? extra]) {
    final headers = <String, String>{
      'accept': 'application/json',
    };
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  Future<Map<String, String>> _effectiveHeaders() async {
    final cookie = await _getCookie();
    final headers = _headersWithCookie();
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie; // e.g., JSESSIONID=...; other cookies
    }
    return headers;
  }

  /// Check if a valid session exists by calling GET /api/session
  Future<bool> sessionExists() async {
    if (baseUrl.isEmpty) return false;

    final uri = Uri.parse('$baseUrl/api/session');
    final headers = await _effectiveHeaders();
    try {
      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode == 200) {
        // Persist any updated cookie from Set-Cookie
        final setCookie = resp.headers['set-cookie'];
        if (setCookie != null && setCookie.isNotEmpty) {
          // Store only cookie pair(s) before first ';'
          final cookiePair = setCookie.split(',').first.split(';').first.trim();
          await _saveCookie(cookiePair);
        }
        // Save user body (Traccar returns user JSON when session valid)
        if (resp.body.isNotEmpty) {
          try {
            final data = jsonDecode(resp.body) as Map<String, dynamic>;
            await _saveUser(data);
          } catch (_) {}
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Login with email/username and password via POST /api/session
  Future<(bool success, String? message)> login(
      {required String email, required String password}) async {
    if (baseUrl.isEmpty) {
      return (false, 'Traccar base URL not configured');
    }
    final uri = Uri.parse('$baseUrl/api/session');
    try {
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8'},
        body: 'email=${Uri.encodeComponent(email)}&password=${Uri.encodeComponent(password)}'
      );
      if (resp.statusCode == 200) {
        final setCookie = resp.headers['set-cookie'];
        if (setCookie != null && setCookie.isNotEmpty) {
          final cookiePair = setCookie.split(',').first.split(';').first.trim();
          await _saveCookie(cookiePair);
        }
        if (resp.body.isNotEmpty) {
          try {
            final data = jsonDecode(resp.body) as Map<String, dynamic>;
            await _saveUser(data);
          } catch (_) {}
        }
        return (true, null);
      }
      String msg = 'Login failed (${resp.statusCode})';
      try {
        final data = jsonDecode(resp.body);
        if (data is Map && data['message'] is String) msg = data['message'];
      } catch (_) {}
      return (false, msg);
    } catch (e) {
      return (false, 'Network error: $e');
    }
  }

  /// Logout via DELETE /api/session
  Future<void> logout() async {
    if (baseUrl.isEmpty) {
      await _clearCookie();
      await _clearUser();
      return;
    }
    final uri = Uri.parse('$baseUrl/api/session');
    try {
      final headers = await _effectiveHeaders();
      await http.delete(uri, headers: headers);
    } catch (e) {
      dev.log('[HTTP] Error during logout: $e', name: 'TraccarAuth');
    }
    await _clearCookie();
    await _clearUser();
  }
}