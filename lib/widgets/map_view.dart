import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/device.dart';
import '../models/position.dart';

class MapView extends StatefulWidget {
  final Map<int, Device> devices;
  final Map<int, Position> positions;

  const MapView({
    super.key,
    required this.devices,
    required this.positions,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  MapLibreMapController? mapController;
  String? _mapStyle;
  bool _hasInitiallyFit = false;

  static const String _sourceId = 'devices-source';

  // Default location (San Francisco)
  final LatLng _center = const LatLng(37.7749, -122.4194);

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
  }

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  void _update() {
    _updateMapSource();
    if (!_hasInitiallyFit && widget.positions.isNotEmpty) {
      _fitMapToDevices();
      _hasInitiallyFit = true;
    }
  }

  Future<void> _loadMapStyle() async {
    final style = await rootBundle.loadString('assets/map_style.json');
    setState(() {
      _mapStyle = style;
    });
  }

  void _onMapCreated(MapLibreMapController controller) {
    mapController = controller;
    _update();
  }

  Future<void> _updateMapSource() async {
    if (mapController == null) {
      dev.log('[Map] MapController is null, skipping source update', name: 'Map');
      return;
    }

    dev.log('[Map] Updating source - Devices: ${widget.devices.length}, Positions: ${widget.positions.length}',
        name: 'Map');

    try {
      // Build GeoJSON features for all devices with positions
      final List<Map<String, dynamic>> features = [];

      for (var entry in widget.positions.entries) {
        final deviceId = entry.key;
        final position = entry.value;
        final device = widget.devices[deviceId];

        if (device == null) {
          dev.log('[Map] No device found for position deviceId=$deviceId', name: 'TraccarMap');
          continue;
        }

        features.add({
          'type': 'Feature',
          'id': deviceId,
          'geometry': {
            'type': 'Point',
            'coordinates': [position.longitude, position.latitude],
          },
          'properties': {
            'deviceId': deviceId,
            'name': device.name,
            'status': device.status,
          },
        });
      }

      final geojson = {
        'type': 'FeatureCollection',
        'features': features,
      };

      // Update the source that's already defined in the style
      await mapController!.setGeoJsonSource(_sourceId, geojson);
      dev.log('[Map] Updated source with ${features.length} feature(s)', name: 'TraccarMap');
    } catch (e, stack) {
      dev.log('[Map] Error updating source: $e', name: 'TraccarMap', error: e, stackTrace: stack);
    }
  }

  /// Fit map camera to show all devices
  void _fitMapToDevices() {
    if (mapController == null || widget.positions.isEmpty) return;

    final positions = widget.positions.values.toList();

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

  @override
  Widget build(BuildContext context) {
    if (_mapStyle == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return MapLibreMap(
      onMapCreated: _onMapCreated,
      initialCameraPosition: CameraPosition(target: _center),
      styleString: _mapStyle!,
      myLocationEnabled: true,
    );
  }
}
