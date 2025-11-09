import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'devices_list_page.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';
import '../models/device.dart';
import '../models/position.dart';
import '../widgets/map_view.dart';
import '../widgets/profile_view.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  final SocketService _socketService = SocketService();
  final ApiService _apiService = ApiService();
  StreamSubscription? _wsSub;

  final Map<int, Device> _devices = {};
  final Map<int, Position> _positions = {};
  final List<IconData> _iconList = [
    Icons.map_outlined,
    Icons.list,
    Icons.person_outline,
  ];

  @override
  Future<void> initState() async {
    super.initState();
    final devices = await _apiService.fetchDevices();
    final devicesMap = <int, Device>{};
    for (var device in devices) { devicesMap[device.id] = device; }
    setState(() {_devices.addAll(devicesMap);});
    await _connectSocket();
  }

  Widget _buildCurrentScreen() {
    switch (_selectedIndex) {
      case 1:
        return DevicesListPage(
          devices: _devices,
          positions: _positions,
        );
      case 2:
        return ProfileView(
          deviceCount: _devices.length,
          activeCount: _positions.length,
        );
      default:
        return MapView(
          devices: _devices,
          positions: _positions,
        );
    }
  }

  Future<void> _connectSocket() async {
    final ok = await _socketService.connect();
    if (!mounted) return;
    if (ok && _socketService.stream != null) {
      _wsSub = _socketService.stream!.listen(
        (event) {
          _handleWebSocketMessage(event);
        },
        onError: (e) => dev.log('[WS] Stream error: $e', name: 'WS'),
        onDone: () => dev.log('[WS] Closed', name: 'WS'),
      );
    } else {
      dev.log('[WS] Failed to connect', name: 'WS');
    }
  }

  void _handleWebSocketMessage(dynamic event) {
    if (event is! String) return;

    final data = jsonDecode(event) as Map<String, dynamic>;

    final Map<int, Device> newDevices = {};
    final Map<int, Position> newPositions = {};

    if (data['devices'] != null) {
      final devicesList = data['devices'] as List;
      for (var deviceJson in devicesList) {
        final device = Device.fromJson(deviceJson as Map<String, dynamic>);
        newDevices[device.id] = device;
      }
      dev.log('Received ${devicesList.length} device(s)', name: 'WS');
    }

    if (data['positions'] != null) {
      final positionsList = data['positions'] as List;
      for (var positionJson in positionsList) {
        final position = Position.fromJson(positionJson as Map<String, dynamic>);
        newPositions[position.deviceId] = position;
      }
      dev.log('Received ${positionsList.length} position(s)', name: 'WS');
    }

    if (newDevices.isNotEmpty || newPositions.isNotEmpty) {
      setState(() {
        if (newDevices.isNotEmpty) {
          _devices.addAll(newDevices);
        }
        if (newPositions.isNotEmpty) {
          _positions.addAll(newPositions);
        }
      });
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _socketService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildCurrentScreen(),
          // Curved Navigation Bar Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CurvedNavigationBar(
              index: _selectedIndex,
              height: 60,
              items: <Widget>[
                Icon(_iconList[0], size: 30, color: Colors.white),
                Icon(_iconList[1], size: 30, color: Colors.white),
                Icon(_iconList[2], size: 30, color: Colors.white),
              ],
              color: Theme.of(context).colorScheme.primary,
              buttonBackgroundColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Colors.transparent,
              animationCurve: Curves.easeInOut,
              animationDuration: const Duration(milliseconds: 300),
              onTap: (index) {setState(() {_selectedIndex = index;});},
            ),
          ),
        ],
      ),
    );
  }
}
