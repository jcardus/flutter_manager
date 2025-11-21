import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/device.dart';
import '../models/position.dart';
import '../utils/constants.dart';
import '../map/styles.dart';
import 'map/style_selector.dart';

class MapView extends StatefulWidget {
  final Map<int, Device> devices;
  final Map<int, Position> positions;
  final int? selectedDevice;
  final Function(int deviceId)? onDeviceSelected;

  const MapView({
    super.key,
    required this.devices,
    required this.positions,
    this.selectedDevice,
    this.onDeviceSelected,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  MapLibreMapController? mapController;
  bool _initialFitDone = false;
  bool _mapReady = false;
  int _styleIndex = 0;
  Future<String>? _initialStyleFuture;
  double scrollOffset = 0;


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialStyleFuture == null) {
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      _initialStyleFuture = MapStyles.getStyleString(MapStyles.configs[_styleIndex], pixelRatio);
    }
    super.didChangeDependencies();
  }

  Future<void> _applyStyle(int index) async {
    if (mapController == null) return;
    setState(() => _mapReady = false);
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final styleString = await MapStyles.getStyleString(MapStyles.configs[index], pixelRatio);
    await mapController!.setStyle(styleString);
    setState(() { _styleIndex = index; });
  }

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
    if (widget.selectedDevice != null &&
        widget.selectedDevice != oldWidget.selectedDevice) {
      // Defer showing bottom sheet until after build completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerOnDevice(widget.selectedDevice!);
      });
    }
  }

  void _update() {
    if (widget.positions.isNotEmpty && mapController != null && _mapReady) {
      _updateMapSource();
      if (!_initialFitDone) {
        _fitMapToDevices();
        _initialFitDone = true;
      }
    }
  }

  void _centerOnDevice(int deviceId) async {
    final position = widget.positions[deviceId];
    if (mapController == null || position == null) { return; }
    final zoom = mapController!.cameraPosition!.zoom;
    var p = await mapController!.toScreenLocation(
        LatLng(position.latitude, position.longitude));
    if (zoom < selectedZoomLevel) {
      await mapController!.animateCamera(
          CameraUpdate.zoomBy(selectedZoomLevel-zoom, Offset(p.x.toDouble(), p.y.toDouble())),
          duration: Duration(milliseconds: 250));
    }
    p = await mapController!.toScreenLocation(
        LatLng(position.latitude, position.longitude));
    final ll = await mapController!.toLatLng(Point(p.x, p.y + scrollOffset));
    await mapController!.animateCamera(
        CameraUpdate.newLatLng(ll),
        duration: const Duration(milliseconds: 250)
    );
  }

  void _onMapCreated(MapLibreMapController controller) {
    mapController = controller;
  }

  Future<void> _onMapClick(Point<double> point, LatLng? coordinates) async {
    if (mapController == null) return;
    try {
      final features = await mapController!.queryRenderedFeatures(
          point,
          [MapStyles.layerId, MapStyles.clusterLayerId],
          null
      );

      if (features.isNotEmpty) {
        for (var feature in features) {
          final properties = feature['properties'];
          if (properties != null && properties['deviceId'] != null) {
            widget.onDeviceSelected?.call((properties['deviceId'] as num).toInt());
            return;
          } else if (properties != null && properties['cluster_id'] != null) {
            final zoom = mapController!.cameraPosition!.zoom;
            coordinates ??= await mapController!.toLatLng(point);
            await mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(coordinates, zoom + 2),
              duration: const Duration(milliseconds: 1000),
            );
            return;
          }
        }
      }
    } catch (e, stack) {
      dev.log('_onMapClick', error: e, stackTrace: stack);
    }
  }

  Future<void> addImageFromAsset(String name, String assetName) async {
    dev.log('adding $name, $assetName');
    final bytes = await rootBundle.load(assetName);
    final list = bytes.buffer.asUint8List();
    return mapController!.addImage(name, list);
  }

  Future<void> _updateMapSource() async {
    final List<Map<String, dynamic>> features = [];
    for (var entry in widget.positions.entries) {
      final deviceId = entry.key;
      final position = entry.value;
      final device = widget.devices[deviceId];
      if (device == null) { continue; }
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
    await mapController!.setGeoJsonSource(MapStyles.sourceId, {'type': 'FeatureCollection', 'features': features});
  }

  void _fitMapToDevices() {
    if (mapController == null || widget.positions.isEmpty) return;
    final positions = widget.positions.values.toList();

    final minLat = positions.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final maxLat = positions.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final minLng = positions.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final maxLng = positions.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

    // Add some padding
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

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
    scrollOffset = MediaQuery.of(context).size.height / 4;
    return Scaffold(
      body: FutureBuilder<String>(
        future: _initialStyleFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Stack(
            children: [
              MapLibreMap(
                onMapCreated: _onMapCreated,
                onStyleLoadedCallback: _onStyleLoaded,
                onMapClick: Platform.isIOS ? null: _onMapClick,
                initialCameraPosition: CameraPosition(target: LatLng(0, 0)),
                styleString: snapshot.data!,
                myLocationEnabled: true,
                trackCameraPosition: true,
              ),
              if (Platform.isIOS)
                Positioned.fill(
                  child: GestureDetector(
                      onTapUp: (event) =>
                          _onMapClick(
                              Point(event.localPosition.dx,
                                  event.localPosition.dy),
                              null
                          ),
                      behavior: HitTestBehavior.translucent
                  ),
                ),
              MapStyleSelector(
                  selectedStyleIndex: _styleIndex,
                  mapReady: _mapReady,
                  onStyleSelected: _applyStyle,
                )
            ],
          );
        },
      ),
    );
  }

  getMapIcon(String? category) {
    if (category != null && categoryIcons.contains(category)) {
      return category;
    }
    return 'truck';
  }
}
