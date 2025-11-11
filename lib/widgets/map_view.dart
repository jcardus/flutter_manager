import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/device.dart';
import '../models/position.dart';
import '../constants/map_constants.dart';

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
  bool _hasInitiallyFit = false;

  static const String _sourceId = 'devices-source';

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

  void _onMapCreated(MapLibreMapController controller) {
    mapController = controller;
    _update();
  }

  Future<void> addImageFromAsset(String name, String assetName) async {
    final bytes = await rootBundle.load(assetName);
    final list = bytes.buffer.asUint8List();
    return mapController!.addImage(name, list);
  }

  Future<void> _updateMapSource() async {
    if (mapController == null) {
      dev.log('mapController is null, skipping source update', name: 'Map');
      return;
    }
    final List<Map<String, dynamic>> features = [];

    for (var entry in widget.positions.entries) {
      final deviceId = entry.key;
      final position = entry.value;
      final device = widget.devices[deviceId];

      if (device == null) {
        dev.log('No device found for position deviceId=$deviceId', name: 'Map');
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
          'category': 'truck', // device.category,
          'name': device.name,
          'status': device.status,
          'baseRotation': (position.course / 6).floor().toString().padLeft(3, '0')
        },
      });
    }

    final geojson = {
      'type': 'FeatureCollection',
      'features': features,
    };

    // Update the source that's already defined in the style
    await mapController!.setGeoJsonSource(_sourceId, geojson);
    // dev.log('[Map] Updated source with $features feature(s)', name: 'TraccarMap');
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

  Future<void> _onStyleLoaded() async {
    try {
      for (final vehicle in vehicleTypes) {
        for (final color in colors) {
          for (int i = 0; i < rotationFrames; i++) {
            final iconNumber = i.toString().padLeft(3, '0');
            await addImageFromAsset(
                "${vehicle}_${color}_$iconNumber",
                "assets/map/icons/${vehicle}_${color}_$iconNumber.png"
            );
          }
        }
      }
    } catch (e) {
      dev.log('_onStyleLoaded', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      initialCameraPosition: CameraPosition(target: LatLng(0, 0)),
      styleString: "assets/map_style.json",
      myLocationEnabled: true,
    );
  }

  getMapIcon(String? category) {
    dev.log(category!);
    switch (category) {
      default:
        return vehicleTypes[0];
    }
  }
}
