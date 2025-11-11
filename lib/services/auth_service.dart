import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../env/env.dart';

class AuthService {
  static const String _cookieKey = 'traccar_cookie';
  static const String _userKey = 'traccar_user';

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
    final headers = <String, String>{'accept': 'application/json'};
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  Future<Map<String, String>> _effectiveHeaders() async {
    final cookie = await _getCookie();
    final headers = _headersWithCookie();
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }
    return headers;
  }

  Future<bool> sessionExists() async {
    if (baseUrl.isEmpty) return false;

    final uri = Uri.parse('$baseUrl/api/session');
    final headers = await _effectiveHeaders();
    try {
      final resp = await http.get(uri, headers: headers);
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
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

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
            final headers = await _effectiveHeaders();
            headers['content-type'] = 'application/x-www-form-urlencoded;charset=UTF-8';
           dev.log((await http.post(
                Uri.parse('$baseUrl/api/session/token'),
                headers: headers,
                body: 'expiration=${DateTime.now().add(Duration(days: 1)).toIso8601String()}'
            )) as String);

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
