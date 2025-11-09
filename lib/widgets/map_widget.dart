import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/device.dart';
import '../models/position.dart';

class MapWidget extends StatefulWidget {
  final Map<int, Device> devices;
  final Map<int, Position> positions;

  const MapWidget({
    super.key,
    required this.devices,
    required this.positions,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  MapLibreMapController? mapController;
  String? _mapStyle;
  bool _sourceLayerAdded = false;
  bool _hasInitiallyFit = false;

  static const String _sourceId = 'devices-source';
  static const String _layerId = 'devices-layer';

  // Default location (San Francisco)
  final LatLng _center = const LatLng(37.7749, -122.4194);

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
  }

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update map when positions change
    if (widget.positions != oldWidget.positions) {
      _updateMapSource();

      // Fit map to devices on first position update
      if (!_hasInitiallyFit && widget.positions.isNotEmpty) {
        _fitMapToDevices();
        _hasInitiallyFit = true;
      }
    }
  }

  Future<void> _loadMapStyle() async {
    final style = await rootBundle.loadString('assets/google_maps_style.json');
    setState(() {
      _mapStyle = style;
    });
  }

  void _onMapCreated(MapLibreMapController controller) {
    mapController = controller;

    // If we already have positions, update source and fit bounds
    if (widget.positions.isNotEmpty) {
      _updateMapSource();
      if (!_hasInitiallyFit) {
        _fitMapToDevices();
        _hasInitiallyFit = true;
      }
    }
  }

  Future<void> _updateMapSource() async {
    if (mapController == null) {
      dev.log('[Map] MapController is null, skipping source update', name: 'TraccarMap');
      return;
    }

    dev.log('[Map] Updating source - Devices: ${widget.devices.length}, Positions: ${widget.positions.length}',
        name: 'TraccarMap');

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

      // Add source and layer on first update
      if (!_sourceLayerAdded) {
        await mapController!.addSource(
          _sourceId,
          GeojsonSourceProperties(data: geojson),
        );

        await mapController!.addCircleLayer(
          _sourceId,
          _layerId,
          CircleLayerProperties(
            circleRadius: 8,
            circleColor: '#FF0000',
            circleStrokeWidth: 2,
            circleStrokeColor: '#FFFFFF',
          ),
        );

        _sourceLayerAdded = true;
        dev.log('[Map] Added source and layer with ${features.length} feature(s)', name: 'TraccarMap');
      } else {
        // Update existing source with new data
        await mapController!.setGeoJsonSource(_sourceId, geojson);
        dev.log('[Map] Updated source with ${features.length} feature(s)', name: 'TraccarMap');
      }
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
      initialCameraPosition: CameraPosition(
        target: _center,
        zoom: 11.0,
      ),
      styleString: _mapStyle!,
      myLocationEnabled: true,
      myLocationTrackingMode: MyLocationTrackingMode.tracking,
    );
  }
}
