import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../screens/devices_list_screen.dart';
import '../services/traccar_socket_service.dart';
import '../services/traccar_api_service.dart';
import '../models/device.dart';
import '../models/position.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  MapLibreMapController? mapController;
  int _selectedIndex = 0;
  String? _mapStyle;
  final TraccarSocketService _socketService = TraccarSocketService();
  final TraccarApiService _apiService = TraccarApiService();
  StreamSubscription? _wsSub;

  // Traccar data state
  Map<int, Device> _devices = {};
  Map<int, Position> _positions = {};

  // Default location (San Francisco)
  final LatLng _center = const LatLng(37.7749, -122.4194);

  // Icons for bottom navigation
  final List<IconData> _iconList = [
    Icons.map_outlined,
    Icons.devices,
    Icons.favorite_outline,
    Icons.person_outline,
  ];

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    _initializeData();
  }

  /// Update devices state and trigger map refresh
  void _updateDevices(Map<int, Device> newDevices) {
    setState(() {
      _devices.addAll(newDevices);
    });
  }

  /// Update positions state and trigger map refresh
  void _updatePositions(Map<int, Position> newPositions) {
    final hadNoPositions = _positions.isEmpty;

    setState(() {
      _positions.addAll(newPositions);
    });

    // Update map after state change
    _updateMapSymbols();

    // Fit map to devices on first position update
    if (hadNoPositions && _positions.isNotEmpty) {
      _fitMapToDevices();
    }
  }

  /// Fetch initial data from API, then connect to websocket for real-time updates
  Future<void> _initializeData() async {
    dev.log('[Init] Fetching initial devices and positions', name: 'TraccarInit');
    final devices = await _apiService.fetchDevices();

    if (!mounted) return;

    // Update devices using wrapper method
    final devicesMap = <int, Device>{};
    for (var device in devices) {
      devicesMap[device.id] = device;
    }
    _updateDevices(devicesMap);

    dev.log('[Init] Loaded ${_devices.length} devices, ${_positions.length} positions',
        name: 'TraccarInit');

    await _connectSocket();
  }

  Widget _buildCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildMapView();
      case 1:
        return DevicesListScreen(
          devices: _devices,
          positions: _positions,
        );
      case 2:
        return const Center(child: Text('Favorites - Coming Soon'));
      case 3:
        return const Center(child: Text('Profile - Coming Soon'));
      default:
        return _buildMapView();
    }
  }

  Widget _buildMapView() {
    if (_mapStyle == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        MapLibreMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: _center,
            zoom: 11.0,
          ),
          styleString: _mapStyle!,
          myLocationEnabled: true,
          myLocationTrackingMode: MyLocationTrackingMode.tracking,
        ),
        Positioned(
          bottom: 80,
          right: 16,
          child: SpeedDial(
            icon: Icons.add,
            activeIcon: Icons.close,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            activeBackgroundColor: Theme.of(context).colorScheme.primary,
            activeForegroundColor: Colors.white,
            buttonSize: const Size(56, 56),
            visible: true,
            closeManually: false,
            elevation: 8.0,
            animationCurve: Curves.elasticInOut,
            isOpenOnStart: false,
            shape: const CircleBorder(),
            children: [
              SpeedDialChild(
                child: const Icon(Icons.add_location_alt),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                label: 'Add Location',
                labelStyle: const TextStyle(fontSize: 14),
                onTap: () {},
              ),
              SpeedDialChild(
                child: const Icon(Icons.route),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                label: 'Add Route',
                labelStyle: const TextStyle(fontSize: 14),
                onTap: () {},
              ),
              SpeedDialChild(
                child: const Icon(Icons.local_shipping),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                label: 'Add Vehicle',
                labelStyle: const TextStyle(fontSize: 14),
                onTap: () {},
              ),
              SpeedDialChild(
                child: const Icon(Icons.camera_alt),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                label: 'Take Photo',
                labelStyle: const TextStyle(fontSize: 14),
                onTap: () {},
              ),
            ],
          ),
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
        onError: (e) => dev.log('[WS] Stream error: $e', name: 'TraccarWS'),
        onDone: () => dev.log('[WS] Closed', name: 'TraccarWS'),
      );
    } else {
      dev.log('[WS] Failed to connect', name: 'TraccarWS');
    }
  }

  void _handleWebSocketMessage(dynamic event) {
    try {
      if (event is! String) return;

      final data = jsonDecode(event) as Map<String, dynamic>;
      dev.log('[WS] Received: ${data.keys.join(", ")}', name: 'TraccarWS');

      bool updated = false;

      // Parse devices and positions outside setState
      final Map<int, Device> newDevices = {};
      final Map<int, Position> newPositions = {};

      // Handle devices
      if (data['devices'] != null) {
        final devicesList = data['devices'] as List;
        for (var deviceJson in devicesList) {
          final device = Device.fromJson(deviceJson as Map<String, dynamic>);
          newDevices[device.id] = device;
        }
        dev.log('[WS] Received ${devicesList.length} device(s)', name: 'TraccarWS');
        updated = true;
      }

      // Handle positions
      if (data['positions'] != null) {
        final positionsList = data['positions'] as List;
        for (var positionJson in positionsList) {
          final position = Position.fromJson(positionJson as Map<String, dynamic>);
          newPositions[position.deviceId] = position;
        }
        dev.log('[WS] Received ${positionsList.length} position(s)', name: 'TraccarWS');
        updated = true;
      }

      // Update state using wrapper methods
      if (updated && mounted) {
        // Update devices if any
        if (newDevices.isNotEmpty) {
          _updateDevices(newDevices);
        }

        // Update positions if any (automatically updates map)
        if (newPositions.isNotEmpty) {
          _updatePositions(newPositions);
        }

        dev.log('[WS] State updated - Devices: ${_devices.length}, Positions: ${_positions.length}', name: 'TraccarWS');
      }
    } catch (e, stack) {
      dev.log('[WS] Error parsing message: $e', name: 'TraccarWS', error: e, stackTrace: stack);
    }
  }

  // Use circles instead of symbols since we don't have fonts in custom style
  final Map<int, Circle> _mapCircles = {};

  Future<void> _updateMapSymbols() async {
    if (mapController == null) {
      dev.log('[Map] MapController is null, skipping symbol update', name: 'TraccarMap');
      return;
    }

    dev.log('[Map] Updating symbols - Devices: ${_devices.length}, Positions: ${_positions.length}',
        name: 'TraccarMap');

    try {
      // Remove circles for devices that no longer have positions
      final circlesToRemove = <int>[];
      for (var deviceId in _mapCircles.keys) {
        if (!_positions.containsKey(deviceId)) {
          circlesToRemove.add(deviceId);
        }
      }
      for (var deviceId in circlesToRemove) {
        final circle = _mapCircles.remove(deviceId);
        if (circle != null) {
          await mapController!.removeCircle(circle);
        }
      }

      // Add or update circles for devices with positions
      for (var entry in _positions.entries) {
        final deviceId = entry.key;
        final position = entry.value;
        final device = _devices[deviceId];

        if (device == null) {
          dev.log('[Map] No device found for position deviceId=$deviceId', name: 'TraccarMap');
          continue;
        }

        final latLng = LatLng(position.latitude, position.longitude);
        dev.log('[Map] Adding circle for ${device.name} at $latLng', name: 'TraccarMap');

        // Remove old circle if exists
        final oldCircle = _mapCircles[deviceId];
        if (oldCircle != null) {
          await mapController!.removeCircle(oldCircle);
        }

        // Add new circle marker
        final circle = await mapController!.addCircle(
          CircleOptions(
            geometry: latLng,
            circleRadius: 8,
            circleColor: '#FF0000',
            circleStrokeWidth: 2,
            circleStrokeColor: '#FFFFFF',
          ),
        );
        _mapCircles[deviceId] = circle;
      }

      dev.log('[Map] Successfully updated ${_mapCircles.length} circle(s)', name: 'TraccarMap');
    } catch (e, stack) {
      dev.log('[Map] Error updating symbols: $e', name: 'TraccarMap', error: e, stackTrace: stack);
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _socketService.close();
    super.dispose();
  }

  Future<void> _loadMapStyle() async {
    final style = await rootBundle.loadString('assets/google_maps_style.json');
    setState(() {
      _mapStyle = style;
    });
  }

  void _onMapCreated(MapLibreMapController controller) {
    mapController = controller;
    dev.log('[Map] Map created, controller ready', name: 'TraccarMap');

    // If we already have positions, update symbols and fit bounds
    if (_positions.isNotEmpty) {
      _updateMapSymbols();
      _fitMapToDevices();
    }
  }

  /// Fit map camera to show all devices
  void _fitMapToDevices() {
    if (mapController == null || _positions.isEmpty) return;

    final positions = _positions.values.toList();

    // Find bounds
    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLng = positions.first.longitude;
    double maxLng = positions.first.longitude;

    for (var pos in positions) {
      if (pos.latitude < minLat) minLat = pos.latitude;
      if (pos.latitude > maxLat) maxLat = pos.latitude;
      if (pos.longitude < minLng) minLng = pos.longitude;
      if (pos.longitude > maxLng) maxLng = pos.longitude;
    }

    // Add some padding
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    dev.log('[Map] Fitting bounds: SW($minLat,$minLng) NE($maxLat,$maxLng)', name: 'TraccarMap');

    mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - latPadding, minLng - lngPadding),
          northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
        ),
        left: 50,
        top: 50,
        right: 50,
        bottom: 150, // Extra padding for bottom nav
      ),
    );
  }

  void _onMenuItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Handle menu item selection here
    switch (index) {
      case 0:
        dev.log('Map selected', name: 'Navigation');
        break;
      case 1:
        dev.log('Devices selected', name: 'Navigation');
        break;
      case 2:
        dev.log('Favorites selected', name: 'Navigation');
        break;
      case 3:
        dev.log('Profile selected', name: 'Navigation');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Current screen content
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
                Icon(_iconList[3], size: 30, color: Colors.white),
              ],
              color: Theme.of(context).colorScheme.primary,
              buttonBackgroundColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Colors.transparent,
              animationCurve: Curves.easeInOut,
              animationDuration: const Duration(milliseconds: 300),
              onTap: _onMenuItemTapped,
            ),
          ),
        ],
      ),
    );
  }
}