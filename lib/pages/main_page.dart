import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
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
    return Stack(
      children: [
        // Keep map alive but only visible when selected
        Offstage(
          offstage: _selectedIndex != 0,
          child: MapView(
            devices: _devices,
            positions: _positions,
            selectedDevice: _selectedDeviceId,
            onDeviceSelected: _onDeviceTap,
          ),
        ),
        // Conditionally render other views (not kept alive)
        if (_selectedIndex == 1)
          DevicesListView(
            devices: _devices,
            positions: _positions,
            onDeviceTap: _onDeviceTap,
          ),
        if (_selectedIndex == 2)
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
          // Floating Navigation Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    elevation: 3,
                    borderRadius: BorderRadius.circular(10),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildNavItem(0, Icons.map_outlined, 'Map'),
                          const SizedBox(width: 4),
                          _buildNavItem(1, Icons.list, 'Devices'),
                          const SizedBox(width: 4),
                          _buildNavItem(2, Icons.person_outline, 'Profile'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Device Bottom Sheet
          _BottomSheetBuilder(
            selectedDeviceId: _selectedDeviceId,
            devices: _devices,
            positions: _positions,
            onClose: _closeBottomSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Separate widget that only rebuilds when selected device data changes
class _BottomSheetBuilder extends StatefulWidget {
  final int? selectedDeviceId;
  final Map<int, Device> devices;
  final Map<int, Position> positions;
  final VoidCallback? onClose;

  const _BottomSheetBuilder({
    required this.selectedDeviceId,
    required this.devices,
    required this.positions,
    this.onClose,
  });

  @override
  State<_BottomSheetBuilder> createState() => _BottomSheetBuilderState();
}

class _BottomSheetBuilderState extends State<_BottomSheetBuilder> {
  Widget? _cachedBottomSheet;
  int? _lastDeviceId;
  int? _lastPositionId;

  @override
  Widget build(BuildContext context) {
    final selectedDeviceId = widget.selectedDeviceId;

    // Check if we need to rebuild the bottom sheet
    if (selectedDeviceId != null) {
      final device = widget.devices[selectedDeviceId];
      final position = widget.positions[selectedDeviceId];
      final currentPositionId = position?.id;

      // Check if device changed (animate) or just position updated (no animation)
      final deviceChanged = selectedDeviceId != _lastDeviceId;
      final positionChanged = currentPositionId != _lastPositionId;

      if (_cachedBottomSheet == null || deviceChanged || positionChanged) {
        _lastDeviceId = selectedDeviceId;
        _lastPositionId = currentPositionId;

        // Only animate when device changes or first opening
        if (deviceChanged || _cachedBottomSheet == null) {
          _cachedBottomSheet = AnimatedSwitcher(
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
            child: DeviceBottomSheet(
              key: ValueKey(selectedDeviceId),
              device: device!,
              position: position,
              onClose: widget.onClose,
            ),
          );
        } else {
          // Position changed but device is the same - just rebuild without animation
          _cachedBottomSheet = DeviceBottomSheet(
            key: ValueKey(selectedDeviceId),
            device: device!,
            position: position,
            onClose: widget.onClose,
          );
        }
      }
    } else {
      _lastDeviceId = null;
      _lastPositionId = null;
      _cachedBottomSheet = const SizedBox.shrink();
    }
    return _cachedBottomSheet!;
  }
}
