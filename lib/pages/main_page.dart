import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';
import '../models/device.dart';
import '../models/position.dart';
import '../widgets/devices_list_view.dart';
import '../widgets/map_view.dart';
import '../widgets/profile_view.dart';
import '../widgets/device_bottom_sheet.dart';

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
  int? _selectedDeviceId;
  final List<IconData> _iconList = [
    Icons.map_outlined,
    Icons.list,
    Icons.person_outline,
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final devices = await _apiService.fetchDevices();
    final devicesMap = <int, Device>{};
    for (var device in devices) { devicesMap[device.id] = device; }
    final positions = await _apiService.fetchPositions();
    final positionsMap = <int, Position>{};
    for (var position in positions) { positionsMap[position.deviceId] = position; }
    setState(() {
      _devices.addAll(devicesMap);
      _positions.addAll(positionsMap);
    });
    if (!mounted) return;
    await _connectSocket();
  }

  void _onDeviceTap(int deviceId) {
    setState(() {
      _selectedDeviceId = deviceId;
      _selectedIndex = 0; // Switch to map view
    });
  }

  void _closeBottomSheet() {
    setState(() {
      _selectedDeviceId = null;
    });
  }

  Widget _buildCurrentScreen() {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        MapView(
          devices: _devices,
          positions: _positions,
          selectedDevice: _selectedDeviceId,
          onDeviceSelected: _onDeviceTap,
        ),
        DevicesListView(
          devices: _devices,
          positions: _positions,
          onDeviceTap: _onDeviceTap,
        ),
        ProfileView(
          deviceCount: _devices.length,
          activeCount: _positions.length,
        ),
      ],
    );
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
      dev.log('Failed to connect', name: 'WS');
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
    }

    if (data['positions'] != null) {
      final positionsList = data['positions'] as List;
      for (var positionJson in positionsList) {
        final position = Position.fromJson(positionJson as Map<String, dynamic>);
        newPositions[position.deviceId] = position;
      }
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
            child: SafeArea(
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
              )
            ),
          ),
          // Device Bottom Sheet (positioned after nav bar so it overlaps)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                )),
                child: child,
              );
            },
            child: _selectedDeviceId != null
                ? DeviceBottomSheet(
                    key: ValueKey(_selectedDeviceId),
                    device: _devices[_selectedDeviceId]!,
                    position: _positions[_selectedDeviceId],
                    onClose: _closeBottomSheet,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
