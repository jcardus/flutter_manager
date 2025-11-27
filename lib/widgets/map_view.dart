import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/device.dart';
import '../models/position.dart';
import '../models/event.dart';
import '../utils/constants.dart';
import '../utils/device_colors.dart';
import '../map/styles.dart';
import 'map/style_selector.dart';
import '../icons/Icons.dart' as platform_icons;

class MapView extends StatefulWidget {
  final Map<int, Device> devices;
  final Map<int, Position> positions;
  final int? selectedDevice;
  final bool showingRoute;
  final List<Position> routePositions;
  final List<Position> movingSegmentPositions;
  final Event? segmentStartEvent;
  final Event? segmentEndEvent;
  final Function(int deviceId)? onDeviceSelected;
  final Position? eventPositionToCenter;
  final Event? selectedEvent;

  const MapView({
    super.key,
    required this.devices,
    required this.positions,
    this.selectedDevice,
    this.showingRoute = false,
    this.routePositions = const [],
    this.movingSegmentPositions = const [],
    this.segmentStartEvent,
    this.segmentEndEvent,
    this.onDeviceSelected,
    this.eventPositionToCenter,
    this.selectedEvent,
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
  bool? _lastShowingRoute;
  List<Position> _lastRoutePositions = [];
  List<Position> _lastMovingSegmentPositions = [];


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

    // Clear event marker when not showing route or no device selected
    if ((widget.selectedDevice == null || !widget.showingRoute) &&
        (oldWidget.selectedDevice != null || oldWidget.showingRoute)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _clearEventMarker();
      });
    }

    // Center on event position if provided
    if (widget.eventPositionToCenter != null &&
        widget.eventPositionToCenter != oldWidget.eventPositionToCenter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerOnEventPosition(widget.eventPositionToCenter!);
      });
    }
  }

  Future<void> _update() async {
    if (widget.positions.isNotEmpty && mapController != null && _mapReady) {
      await _updateMapSource();
      await _updateRouteSource();
      await _updateMovingSegmentSource();
      if (!_initialFitDone) {
        _fitMapToDevices();
        _initialFitDone = true;
      }
    }
  }

  void _centerOnDevice(int deviceId, {bool changeZoom = true}) async {
    final position = widget.positions[deviceId];
    if (mapController == null || position == null) { return; }
    final zoom = mapController!.cameraPosition!.zoom < selectedZoomLevel && changeZoom ?
        selectedZoomLevel : mapController!.cameraPosition!.zoom;
    await mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), zoom),
        duration: const Duration(milliseconds: 250)
    );
  }

  IconData _getEventIcon(String type) {
    switch (type.toLowerCase()) {
      case 'ignitionon':
        return platform_icons.PlatformIcons.ignitionOn;
      case 'ignitionoff':
        return platform_icons.PlatformIcons.ignitionOff;
      case 'geofenceenter':
        return Icons.login;
      case 'geofenceexit':
        return Icons.logout;
      case 'alarm':
        return Icons.warning;
      case 'commandresult':
        return Icons.check_circle;
      case 'devicemoving':
        return platform_icons.PlatformIcons.play;
      case 'devicestopped':
        return Icons.stop_circle;
      case 'deviceoverspeed':
        return Icons.speed;
      default:
        return Icons.event;
    }
  }

  Color _getEventColor(String type, BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    switch (type.toLowerCase()) {
      case 'ignitionon':
      case 'devicemoving':
        return colors.tertiary; // Green for movement/ignition on
      case 'ignitionoff':
      case 'devicestopped':
        return colors.error; // Red for stop/ignition off
      default:
        return colors.primary;
    }
  }

  void _centerOnEventPosition(Position position) async {
    if (mapController == null || widget.selectedEvent == null) { return; }

    // Generate icon name based on event type
    final iconName = 'event-marker-${widget.selectedEvent!.displayType.toLowerCase()}';

    // Check if icon already exists, if not add it
    try {
      final icon = _getEventIcon(widget.selectedEvent!.displayType);
      await addImageFromIcon(
        iconName,
        icon,
        const Color(0xFFFF5722),
        size: 48,
      );
    } catch (e) {
      dev.log('Error adding event icon: $e');
    }

    // Update event marker source with the specific icon
    final markerFeature = {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [position.longitude, position.latitude],
      },
      'properties': {
        'icon': iconName,
      },
    };

    await mapController!.setGeoJsonSource(
      MapStyles.eventMarkerSourceId,
      {'type': 'FeatureCollection', 'features': [markerFeature]},
    );

    final zoom = mapController!.cameraPosition!.zoom < selectedZoomLevel ?
        selectedZoomLevel : mapController!.cameraPosition!.zoom;
    await mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), zoom),
        duration: const Duration(milliseconds: 500)
    );
  }

  Future<void> _clearEventMarker() async {
    if (mapController == null) { return; }
    await mapController!.setGeoJsonSource(
      MapStyles.eventMarkerSourceId,
      {'type': 'FeatureCollection', 'features': []},
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

  Future<void> addImageFromIcon(String name, IconData icon, Color color, {double size = 48}) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        color: color,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);

    final image = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final list = byteData!.buffer.asUint8List();

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
          'color': DeviceColors.getDeviceColorName(device, position),
          'baseRotation': baseRotation.toStringAsFixed(1).padLeft(5, '0'),
          'rotate': position.course - baseRotation,
        },
      });
    }
    await mapController!.setGeoJsonSource(MapStyles.devicesSourceId, {'type': 'FeatureCollection', 'features': features});

    // Only update layer visibility if showingRoute changed
    if (_lastShowingRoute != widget.showingRoute) {
      await _updateLayersVisibility();
      _lastShowingRoute = widget.showingRoute;
    }

    // Check if selected device is visible, pan if needed
    _checkSelectedDeviceVisibility();
  }

  Future<void> _updateLayersVisibility() async {
    if (mapController == null) return;

    final visible = !widget.showingRoute;
    await mapController!.setLayerVisibility(MapStyles.layerId, visible);
    await mapController!.setLayerVisibility(MapStyles.clusterLayerId, visible);
    await mapController!.setLayerVisibility(MapStyles.clusterCountLayerId, visible);
  }

  Future<void> _updateRouteSource() async {
    if (mapController == null) return;

    // Check if route positions have changed
    if (_routePositionsEqual(widget.routePositions, _lastRoutePositions)) {
      return;
    }

    if (widget.routePositions.length < 2 ) {
      await mapController!.setGeoJsonSource(
        MapStyles.deviceRouteSourceId,
        {'type': 'FeatureCollection', 'features': []},
      );
      _lastRoutePositions = [];
      return;
    }

    // Build LineString from route positions
    final coordinates = widget.routePositions
        .map((p) => [p.longitude, p.latitude])
        .toList();

    final lineString = {
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates': coordinates,
      },
      'properties': {},
    };


    dev.log('updating route ${coordinates.length}');
    await mapController!.setGeoJsonSource(
      MapStyles.deviceRouteSourceId,
      {'type': 'FeatureCollection', 'features': [lineString]},
    );

    // Store current positions for next comparison
    _lastRoutePositions = List.from(widget.routePositions);

    // Fit map to route
    _fitMapToRoute();
  }

  bool _routePositionsEqual(List<Position> a, List<Position> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  Future<void> _updateMovingSegmentSource() async {
    if (mapController == null) return;

    // Check if moving segment positions have changed
    if (_routePositionsEqual(widget.movingSegmentPositions, _lastMovingSegmentPositions)) {
      return;
    }

    if (widget.movingSegmentPositions.length < 2 ) {
      await mapController!.setGeoJsonSource(
        MapStyles.movingSegmentSourceId,
        {'type': 'FeatureCollection', 'features': []},
      );
      await mapController!.setGeoJsonSource(
        MapStyles.eventMarkerSourceId,
        {'type': 'FeatureCollection', 'features': []},
      );
      _lastMovingSegmentPositions = [];
      return;
    }

    // Build LineString from moving segment positions
    final coordinates = widget.movingSegmentPositions
        .map((p) => [p.longitude, p.latitude])
        .toList();

    final lineString = {
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates': coordinates,
      },
      'properties': {},
    };

    dev.log('updating moving segment ${coordinates.length}');
    await mapController!.setGeoJsonSource(
      MapStyles.movingSegmentSourceId,
      {'type': 'FeatureCollection', 'features': [lineString]},
    );

    // Add start and end markers using event marker source
    final startPos = widget.movingSegmentPositions.first;
    final endPos = widget.movingSegmentPositions.last;

    // Get the event icons and add them
    if (widget.segmentStartEvent != null && widget.segmentEndEvent != null) {
      final startIcon = _getEventIcon(widget.segmentStartEvent!.displayType);
      final endIcon = _getEventIcon(widget.segmentEndEvent!.displayType);

      final startColor = _getEventColor(widget.segmentStartEvent!.displayType, context);
      final endColor = _getEventColor(widget.segmentEndEvent!.displayType, context);

      await addImageFromIcon('segment-start', startIcon, startColor, size: 48);
      await addImageFromIcon('segment-end', endIcon, endColor, size: 48);

      final markers = [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [startPos.longitude, startPos.latitude],
          },
          'properties': {
            'icon': 'segment-start',
          },
        },
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [endPos.longitude, endPos.latitude],
          },
          'properties': {
            'icon': 'segment-end',
          },
        },
      ];

      await mapController!.setGeoJsonSource(
        MapStyles.eventMarkerSourceId,
        {'type': 'FeatureCollection', 'features': markers},
      );
    }

    // Store current positions for next comparison
    _lastMovingSegmentPositions = List.from(widget.movingSegmentPositions);

    // Fit map to moving segment
    _fitMapToMovingSegment();
  }

  void _fitMapToRoute() {
    if (mapController == null || widget.routePositions.isEmpty) return;

    final positions = widget.routePositions;
    final minLat = positions.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final maxLat = positions.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final minLng = positions.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final maxLng = positions.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

    mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        left: 50,
        top: 50,
        right: 50,
        bottom: 50,
      ),
    );
  }

  void _fitMapToMovingSegment() {
    if (mapController == null || widget.movingSegmentPositions.isEmpty) return;

    final positions = widget.movingSegmentPositions;
    final minLat = positions.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final maxLat = positions.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final minLng = positions.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final maxLng = positions.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

    mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        left: 50,
        top: 50,
        right: 50,
        bottom: 100,
      ),
      duration: const Duration(milliseconds: 500),
    );
  }

  Future<void> _checkSelectedDeviceVisibility() async {
    // Don't auto-pan if showing route view
    if (mapController == null || widget.selectedDevice == null || widget.showingRoute) return;

    final position = widget.positions[widget.selectedDevice];
    if (position == null) return;

    final visibleRegion = await mapController!.getVisibleRegion();

    // Check if selected device is within visible bounds
    final lat = position.latitude;
    final lng = position.longitude;

    final isVisible = lat >= visibleRegion.southwest.latitude &&
        lat <= visibleRegion.northeast.latitude &&
        lng >= visibleRegion.southwest.longitude &&
        lng <= visibleRegion.northeast.longitude;

    // If selected device is not visible, pan to it
    if (!isVisible) {
      _centerOnDevice(widget.selectedDevice!, changeZoom: false);
    }
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
