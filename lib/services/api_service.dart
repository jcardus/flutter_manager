import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/geofence.dart';
import 'auth_service.dart';
import '../models/device.dart';
import '../models/position.dart';
import '../models/event.dart';
import 'web_helper_stub.dart'
    if (dart.library.html) 'web_helper_web.dart' as web_helper;

class ApiService {
  final AuthService _authService = AuthService();

  String? _getWebToken() {
    if (!kIsWeb) return null;
    return web_helper.getTokenFromUrl();
  }

  Future<List<T>> _fetchList<T>({
    required String endpoint,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final baseUrl = AuthService.baseUrl;
    final uri = Uri.parse('$baseUrl$endpoint');

    try {
      final headers = await _getAuthHeaders({'accept': 'application/json'});
      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body) as List<dynamic>;
        final items = data
            .map((json) => fromJson(json as Map<String, dynamic>))
            .toList();
        return items;
      } else {
        dev.log('Failed to fetch $endpoint: ${resp.statusCode}', name: 'API');
        return [];
      }
    } catch (e, stack) {
      dev.log('Error fetching $endpoint: $e', name: 'API', error: e, stackTrace: stack);
      return [];
    }
  }

  Future<List<Device>> fetchDevices() async {
    return _fetchList(
      endpoint: '/api/devices',
      fromJson: Device.fromJson
    );
  }

  Future<List<Position>> fetchPositions() async {
    return _fetchList(
      endpoint: '/api/positions',
      fromJson: Position.fromJson
    );
  }

  Future<List<Geofence>> fetchGeofences() async {
    return _fetchList(
        endpoint: '/api/geofences',
        fromJson: Geofence.fromJson
    );
  }

  Future<List<Event>> fetchEvents({
    required int deviceId,
    required DateTime from,
    required DateTime to,
  }) async {
    final fromParam = from.toUtc().toIso8601String();
    final toParam = to.toUtc().toIso8601String();
    final events = await _fetchList(
      endpoint: '/api/reports/events?deviceId=$deviceId&from=$fromParam&to=$toParam',
      fromJson: Event.fromJson
    );
    // Filter out deviceOnline and deviceOffline events
    return events
        .where((event) => event.type != 'deviceOnline' && event.type != 'deviceOffline')
        .toList();
  }

  Future<List<Position>> fetchDevicePositions({
    required int deviceId,
    required DateTime from,
    required DateTime to,
  }) async {
    final fromParam = from.toUtc().toIso8601String();
    final toParam = to.toUtc().toIso8601String();
    return _fetchList(
      endpoint: '/api/reports/route?deviceId=$deviceId&from=$fromParam&to=$toParam',
      fromJson: Position.fromJson
    );
  }


  Future<Map<String, String>> _getAuthHeaders([Map<String, String>? extraHeaders]) async {
    final headers = <String, String>{
      if (extraHeaders != null) ...extraHeaders,
    };

    // On web, use token from query string in Authorization header
    if (kIsWeb) {
      final token = _getWebToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    } else {
      // On native, use cookie authentication
      final cookie = await _authService.getCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }
    }

    return headers;
  }

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<String> shareDevice(int deviceId, DateTime expirationTime) async {
    final baseUrl = AuthService.baseUrl;

    try {
      // Generate random credentials
      final randomString = _generateRandomString(22);
      final email = 'temp_$randomString';
      final password = randomString;
      final token = randomString;

      // First, create the user
      final createUserUri = Uri.parse('$baseUrl/api/users');
      final createUserHeaders = await _getAuthHeaders({
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      });

      final userBody = jsonEncode({
        'name': email,
        'email': email,
        'readonly': true,
        'administrator': false,
        'password': password,
        'token': token,
        'expirationTime': expirationTime.toUtc().toIso8601String(),
        'attributes': {
          'linkVersion': null,
          'endAddress': '',
        },
      });

      final createUserResponse = await http.post(
        createUserUri,
        headers: createUserHeaders,
        body: userBody,
      );

      if (createUserResponse.statusCode != 200 && createUserResponse.statusCode != 201) {
        dev.log('Failed to create user: ${createUserResponse.statusCode}', name: 'API');
        return '';
      }

      // Extract the userId from the response
      final userData = jsonDecode(createUserResponse.body) as Map<String, dynamic>;
      final userId = userData['id'] as int;

      // Create permission to link the device with the user
      final permissionUri = Uri.parse('$baseUrl/api/permissions');
      final permissionHeaders = await _getAuthHeaders({
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      });

      final permissionBody = jsonEncode({
        'userId': userId,
        'deviceId': deviceId
      });

      await http.post(
        permissionUri,
        headers: permissionHeaders,
        body: permissionBody,
      );
      return 'https://eta.fleetmap.io/?token=$token';
    } catch (e, stack) {
      dev.log('Error in shareDevice: $e', name: 'API', error: e, stackTrace: stack);
      return '';
    }
  }

  Future<String?> shareDeviceV2(int deviceId, DateTime expiration) async {
    final baseUrl = AuthService.baseUrl;
    final uri = Uri.parse('$baseUrl/api/devices/share');

    try {
      final headers = await _getAuthHeaders({'Content-Type': 'application/x-www-form-urlencoded'});
      final expirationString = expiration.toUtc().toIso8601String();
      final response = await http.post(
        uri,
        headers: headers,
        body: 'deviceId=${Uri.encodeComponent(deviceId.toString())}&expiration=${Uri.encodeComponent(expirationString)}',
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        dev.log('Failed to share device: ${response.statusCode}', name: 'API');
        return null;
      }
    } catch (e, stack) {
      dev.log('Error sharing device: $e', name: 'API', error: e, stackTrace: stack);
      return null;
    }
  }

  Future<bool> sendCommand(int deviceId, String commandType) async {
    final baseUrl = AuthService.baseUrl;
    final uri = Uri.parse('$baseUrl/api/commands/send');

    try {
      final headers = await _getAuthHeaders({
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      });

      final body = jsonEncode({
        'deviceId': deviceId,
        'type': commandType,
      });

      final response = await http.post(
        uri,
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        dev.log('Failed to send command: ${response.statusCode}', name: 'API');
        return false;
      }
    } catch (e, stack) {
      dev.log('Error sending command: $e', name: 'API', error: e, stackTrace: stack);
      return false;
    }
  }
}
