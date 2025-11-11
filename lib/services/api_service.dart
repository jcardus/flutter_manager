import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/device.dart';
import '../models/position.dart';

class ApiService {
  final AuthService _authService = AuthService();

  /// Fetch all devices from Traccar API
  Future<List<Device>> fetchDevices() async {
    final baseUrl = AuthService.baseUrl;
    if (baseUrl.isEmpty) {
      dev.log('[API] Base URL not configured', name: 'TraccarAPI');
      return [];
    }

    final uri = Uri.parse('$baseUrl/api/devices');
    final cookie = await _authService.getCookie();

    final headers = <String, String>{
      'accept': 'application/json',
      if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
    };

    try {
      dev.log('Fetching devices from $uri', name: 'API');
      final resp = await http.get(uri, headers: headers);

      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body) as List<dynamic>;
        final devices = data
            .map((json) => Device.fromJson(json as Map<String, dynamic>))
            .toList();
        dev.log('Fetched ${devices.length} device(s)', name: 'API');
        return devices;
      } else {
        dev.log('Failed to fetch devices: ${resp.statusCode}', name: 'API');
        return [];
      }
    } catch (e, stack) {
      dev.log('Error fetching devices: $e', name: 'API', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Fetch all positions from Traccar API
  Future<List<Position>> fetchPositions() async {
    final baseUrl = AuthService.baseUrl;
    if (baseUrl.isEmpty) {
      dev.log('[API] Base URL not configured', name: 'TraccarAPI');
      return [];
    }

    final uri = Uri.parse('$baseUrl/api/positions');
    final cookie = await _authService.getCookie();

    final headers = <String, String>{
      'accept': 'application/json',
      if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
    };

    try {
      dev.log('[API] Fetching positions from $uri', name: 'TraccarAPI');
      final resp = await http.get(uri, headers: headers);

      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body) as List<dynamic>;
        final positions = data
            .map((json) => Position.fromJson(json as Map<String, dynamic>))
            .toList();
        dev.log('[API] Fetched ${positions.length} position(s)', name: 'TraccarAPI');
        return positions;
      } else {
        dev.log('[API] Failed to fetch positions: ${resp.statusCode}', name: 'TraccarAPI');
        return [];
      }
    } catch (e, stack) {
      dev.log('[API] Error fetching positions: $e', name: 'TraccarAPI', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Fetch both devices and positions in one call

}
