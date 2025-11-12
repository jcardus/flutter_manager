import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/device.dart';
import '../models/position.dart';
import '../utils/constants.dart';

class MapView extends StatefulWidget {
  final Map<int, Device> devices;
  final Map<int, Position> positions;
  final int? selectedDevice;

  const MapView({
    super.key,
    required this.devices,
    required this.positions,
    this.selectedDevice,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  MapLibreMapController? mapController;
  bool _initialFitDone = false;
  bool _mapReady = false;
  bool _menuExpanded = false;
  int _currentIndex = 0;

  // Demo styles
  static const String _dark = 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json';
  static const String _light = 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json';
  static const String _google = 'assets/map_style.json';

  late final List<_StyleEntry> _styles = [
    const _StyleEntry('Dark', _dark),
    const _StyleEntry('Light', _light),
    const _StyleEntry('Google', _google),
  ];


  Future<void> _applyStyle(int index) async {
    if (mapController == null) return;
    setState(() => _mapReady = false);
    final entry = _styles[index];
    dev.log('Switching to style: ${entry.label}');
    try {
      await mapController!.setStyle(entry.styleString);
    } catch (e, st) {
      dev.log('Failed to set style ${entry.label}: $e', stackTrace: st);
    }
    setState(() { _currentIndex = index; });
  }

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
    if (widget.selectedDevice != null &&
        widget.selectedDevice != oldWidget.selectedDevice) {
      _centerOnDevice(widget.selectedDevice!);
    }
  }

  void _update() {
    if (widget.positions.isNotEmpty && _mapReady) {
      _updateMapSource();
      if (!_initialFitDone) {
        _fitMapToDevices();
        _initialFitDone = true;
      }
    }
  }

  void _centerOnDevice(int deviceId) {
    final position = widget.positions[deviceId];
    if (mapController == null || position == null) { return; }
    mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude), selectedZoomLevel),
    );
  }

  void _onMapCreated(MapLibreMapController controller) {
    mapController = controller;
  }

  Future<void> addImageFromAsset(String name, String assetName) async {
    dev.log('adding $name, $assetName');
    final bytes = await rootBundle.load(assetName);
    final list = bytes.buffer.asUint8List();
    return mapController!.addImage(name, list);
  }

  Future<void> _updateMapSource() async {
    if (mapController == null) { return; }
    final List<Map<String, dynamic>> features = [];
    for (var entry in widget.positions.entries) {
      final deviceId = entry.key;
      final position = entry.value;
      final device = widget.devices[deviceId];
      if (device == null) {
        dev.log('No device found for position deviceId=$deviceId', name: 'Map');
        continue;
      }
      final baseRotation =
          (position.course / (360 / rotationFrames)).floor() *
          (360 / rotationFrames);
      features.add({
        'type': 'Feature',
        'id': deviceId,
        'geometry': {
          'type': 'Point',
          'coordinates': [position.longitude, position.latitude],
        },
        'properties': {
          'deviceId': deviceId,
          'category': getMapIcon(device.category),
          'name': device.name,
          'color': device.status == 'online' ? 'green' : 'red',
          'baseRotation': baseRotation.toStringAsFixed(1).padLeft(5, '0'),
          'rotate': position.course - baseRotation,
        },
      });
    }
    await mapController!.setGeoJsonSource(sourceId, {'type': 'FeatureCollection', 'features': features});
  }

  void _fitMapToDevices() {
    if (mapController == null || widget.positions.isEmpty) return;
    final positions = widget.positions.values.toList();

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

    dev.log(
      'Fitting bounds: SW($minLat,$minLng) NE($maxLat,$maxLng)',
      name: 'Map',
    );

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
      for (final vehicle in categoryIcons) {
        for (final color in colors) {
          for (int i = 0; i < rotationFrames; i++) {
            final frame = (i * (360 / rotationFrames))
                .toStringAsFixed(1)
                .padLeft(5, '0');
            await addImageFromAsset(
              "${vehicle}_${color}_$frame",
              "assets/map/icons/${vehicle}_${color}_$frame.png",
            );
          }
        }
      }
      setState(() { _mapReady = true; });
      _update();
    } catch (e) {
      dev.log('_onStyleLoaded', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            initialCameraPosition: CameraPosition(target: LatLng(0, 0)),
            styleString: "assets/map_style.json",
            myLocationEnabled: true,
          ),
          Positioned(
            top: 16,
            right: 0,
            child: SafeArea(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: IntrinsicWidth(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: 30,
                      maxWidth: _menuExpanded ? 250 : 30,
                    ),
                    child: Material(
                      elevation: 3,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _menuExpanded = !_menuExpanded;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            _menuExpanded ? Icons.chevron_right : Icons.chevron_left,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      if (_menuExpanded) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Map Style',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...List.generate(_styles.length, (index) {
                          final style = _styles[index];
                          final isSelected = _currentIndex == index;
                          return InkWell(
                            onTap: () => _applyStyle(index),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                    size: 20,
                                    color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _mapReady || !isSelected ? style.label : 'Loading...',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: isSelected
                                          ? Theme.of(context).colorScheme.primary
                                          : null,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  getMapIcon(String? category) {
    switch (category) {
      case 'truck':
        return categoryIcons[0];
      default:
        return categoryIcons[0];
    }
  }
}

class _StyleEntry {
  final String label;
  final String styleString;
  const _StyleEntry(this.label, this.styleString);
}
