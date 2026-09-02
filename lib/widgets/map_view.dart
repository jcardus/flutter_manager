import 'dart:developer' as dev;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:manager/l10n/app_localizations.dart';
import '../models/device.dart';
import '../models/geofence.dart';
import '../models/position.dart';
import '../models/event.dart';
import '../utils/device_colors.dart';
import '../utils/device_icons.dart';
import '../utils/svg_cache.dart';
import '../utils/turbo_colormap.dart';
import '../map/styles.dart';
import 'map/style_selector.dart';
import '../icons/icons.dart' as platform_icons;

class MapView extends StatefulWidget {
  final Map<int, Device> devices;
  final Map<int, Position> positions;
  final Map<int, Geofence> geofences;
  final int? selectedDevice;
  final int? selectedIndex;
  final bool showingRoute;
  final List<Position> routePositions;
  final List<Position> movingSegmentPositions;
  final Event? segmentStartEvent;
  final Event? segmentEndEvent;
  final Function(int deviceId)? onDeviceSelected;
  final Position? eventPositionToCenter;
  final Event? selectedEvent;
  final bool? isFirstPosition;
  final String? positionLabel;
  final VoidCallback? onMapBackgroundTap;

  const MapView({
    super.key,
    required this.devices,
    required this.positions,
    required this.geofences,
    this.selectedDevice,
    this.selectedIndex,
    this.showingRoute = false,
    this.routePositions = const [],
    this.movingSegmentPositions = const [],
    this.segmentStartEvent,
    this.segmentEndEvent,
    this.onDeviceSelected,
    this.eventPositionToCenter,
    this.selectedEvent,
    this.isFirstPosition,
    this.positionLabel,
    this.onMapBackgroundTap,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> with TickerProviderStateMixin {
  final _mapController = MapController();
  int _styleIndex = 0;
  bool _geofencesSelected = true;
  bool _initialFitDone = false;
  List<Position> _lastRoutePositions = [];
  List<Position> _lastMovingSegmentPositions = [];
  AnimationController? _animController;
  AnimationController? _markerAnimController;
  final Map<int, LatLng> _fromPositions = {};
  final Map<int, LatLng> _lastKnownPositions = {};
  double _markerT = 1.0;
  bool _showCurrentLocation = false;
  bool _locatingCurrentLocation = false;
  geo.Position? _currentLocation;
  StreamSubscription<geo.Position>? _locationSubscription;

  Future<void> _toggleCurrentLocation() async {
    if (_showCurrentLocation) {
      await _locationSubscription?.cancel();
      _locationSubscription = null;
      if (mounted) {
        setState(() {
          _showCurrentLocation = false;
          _currentLocation = null;
        });
      }
      return;
    }

    setState(() => _locatingCurrentLocation = true);
    try {
      if (!await geo.Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.locationServicesDisabled,
              ),
            ),
          );
        }
        return;
      }

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.locationPermissionDenied,
              ),
            ),
          );
        }
        return;
      }

      final position = await geo.Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _showCurrentLocation = true;
        _currentLocation = position;
      });
      _animatedMove(LatLng(position.latitude, position.longitude), 16);
      _locationSubscription =
          geo.Geolocator.getPositionStream(
            locationSettings: const geo.LocationSettings(
              accuracy: geo.LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen((position) {
            if (mounted) setState(() => _currentLocation = position);
          });
    } catch (error) {
      dev.log('Unable to get current location', name: 'MAP', error: error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.locationUnavailable),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _locatingCurrentLocation = false);
    }
  }

  void _animatedMove(LatLng dest, double zoom) {
    _animController?.dispose();
    final cam = _mapController.camera;
    final latTween = Tween(begin: cam.center.latitude, end: dest.latitude);
    final lngTween = Tween(begin: cam.center.longitude, end: dest.longitude);
    final zoomTween = Tween(begin: cam.zoom, end: zoom);

    _animController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 500),
        )..addListener(() {
          final t = _animController!.value;
          _mapController.move(
            LatLng(
              latTween.evaluate(AlwaysStoppedAnimation(t)),
              lngTween.evaluate(AlwaysStoppedAnimation(t)),
            ),
            zoomTween.evaluate(AlwaysStoppedAnimation(t)),
          );
        });
    _animController!.forward();
  }

  static const _clusterDisableZoom = 16;

  void _onPositionsChanged() {
    final animate = _mapController.camera.zoom >= 10;
    final bounds = animate ? _mapController.camera.visibleBounds : null;
    bool changed = false;

    for (final e in widget.positions.entries) {
      final newLL = LatLng(e.value.latitude, e.value.longitude);
      final oldLL = _lastKnownPositions[e.key];
      if (oldLL == null || oldLL == newLL) {
        _lastKnownPositions[e.key] = newLL;
        continue;
      }
      _lastKnownPositions[e.key] = newLL;
      if (animate && bounds!.contains(newLL)) {
        _fromPositions[e.key] = oldLL;
        changed = true;
      }
    }
    if (!changed) return;
    dev.log(
      'Animating ${_fromPositions.length} devices at zoom ${_mapController.camera.zoom.toStringAsFixed(1)}',
      name: 'MAP',
    );

    // Reset and reuse controller instead of disposing mid-animation
    if (_markerAnimController == null) {
      _markerAnimController =
          AnimationController(vsync: this, duration: const Duration(seconds: 2))
            ..addListener(
              () => setState(() => _markerT = _markerAnimController!.value),
            )
            ..addStatusListener((s) {
              if (s == AnimationStatus.completed) _fromPositions.clear();
            });
    } else {
      _markerAnimController!.reset();
    }
    _markerT = 0;
    _markerAnimController!.forward();
  }

  LatLng _animatedPoint(int id, Position pos) {
    final to = LatLng(pos.latitude, pos.longitude);
    final from = _fromPositions[id];
    if (from == null || _markerT >= 1.0) return to;
    final t = Curves.easeOut.transform(_markerT);
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _animController?.dispose();
    _markerAnimController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _onPositionsChanged();

    // Initial fit on first data
    if (!_initialFitDone &&
        widget.positions.isNotEmpty &&
        widget.selectedIndex == 0) {
      _initialFitDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToDevices());
    }

    // Center on newly selected device
    if (widget.selectedDevice != null &&
        widget.selectedDevice != oldWidget.selectedDevice) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _centerOnDevice(widget.selectedDevice!),
      );
    }

    // Pan to selected device if it moves outside the visible map
    if (widget.selectedDevice != null &&
        widget.selectedDevice == oldWidget.selectedDevice &&
        !widget.showingRoute) {
      final pos = widget.positions[widget.selectedDevice!];
      if (pos != null) {
        final deviceLatLng = LatLng(pos.latitude, pos.longitude);
        final bounds = _mapController.camera.visibleBounds;
        if (!bounds.contains(deviceLatLng)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _animatedMove(deviceLatLng, _mapController.camera.zoom);
          });
        }
      }
    }

    // Center on event position
    if (widget.eventPositionToCenter != null &&
        widget.eventPositionToCenter != oldWidget.eventPositionToCenter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final pos = widget.eventPositionToCenter!;
        final target = LatLng(pos.latitude, pos.longitude);
        final isScrub = widget.positionLabel == 'Scrub';
        if (isScrub) {
          // Keep current zoom; only recenter if vehicle leaves viewport.
          final bounds = _mapController.camera.visibleBounds;
          if (!bounds.contains(target)) {
            _mapController.move(target, _mapController.camera.zoom);
          }
        } else {
          _mapController.move(
            target,
            _mapController.camera.zoom < 14 ? 14 : _mapController.camera.zoom,
          );
        }
      });
    }

    // Fit to route when route positions change
    if (!_routePositionsEqual(widget.routePositions, _lastRoutePositions) &&
        widget.routePositions.length >= 2) {
      _lastRoutePositions = List.from(widget.routePositions);
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToRoute());
    }

    // Fit to moving segment when it changes
    if (!_routePositionsEqual(
      widget.movingSegmentPositions,
      _lastMovingSegmentPositions,
    )) {
      final wasHighlighted = _lastMovingSegmentPositions.isNotEmpty;
      _lastMovingSegmentPositions = List.from(widget.movingSegmentPositions);
      if (widget.movingSegmentPositions.length >= 2) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _fitMapToMovingSegment(),
        );
      } else if (wasHighlighted && widget.routePositions.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToRoute());
      }
    }

    setState(() {});
  }

  bool _routePositionsEqual(List<Position> a, List<Position> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void _centerOnDevice(int deviceId) {
    final position = widget.positions[deviceId];
    if (position == null) return;
    final dest = LatLng(position.latitude, position.longitude);
    final currentZoom = _mapController.camera.zoom;
    final minZoom = _clusterDisableZoom.toDouble();
    if (currentZoom >= minZoom) {
      _animatedMove(dest, currentZoom);
    } else {
      _mapController.move(dest, minZoom);
      // Force rebuild so cluster layer re-evaluates at new zoom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) setState(() {});
      });
    }
  }

  void _fitMapToDevices() {
    if (widget.positions.isEmpty) return;
    _fitToPoints(
      widget.positions.values
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList(),
      bottomPadding: 150,
    );
  }

  void _fitMapToRoute() {
    if (widget.routePositions.isEmpty) return;
    _fitToPoints(
      widget.routePositions
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList(),
    );
  }

  void _fitMapToMovingSegment() {
    if (widget.movingSegmentPositions.isEmpty) return;
    _fitToPoints(
      widget.movingSegmentPositions
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList(),
      bottomPadding: 100,
    );
  }

  void _fitToPoints(List<LatLng> points, {double bottomPadding = 50}) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 14);
      return;
    }
    try {
      final bounds = LatLngBounds.fromPoints(points);
      // Degenerate bounds (all points identical or colinear at sub-meter scale)
      // make CameraFit.bounds compute log2(viewport/0) -> Infinity, poisoning
      // MapCamera.zoom and crashing every subsequent layer build.
      const eps = 1e-7;
      final span =
          (bounds.north - bounds.south).abs() +
          (bounds.east - bounds.west).abs();
      if (span < eps) {
        _mapController.move(bounds.center, 14);
        return;
      }
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: EdgeInsets.fromLTRB(50, 50, 50, bottomPadding),
        ),
      );
    } catch (e) {
      dev.log('_fitToPoints error: $e');
    }
  }

  static const _category3dIcon = {
    'default': 'sedan_50',
    'car': 'sedan_50',
    'van': 'furgoneta_60',
    'camper': 'furgoneta_ventana',
    'truck': 'cam_caja_60',
    'bus': 'bus_85',
    'tractor': 'tractor_v2',
    'crane': 'grua_v2',
    'trailer': 'remolque_caja_70',
    'trailer2': 'remolque_jaula',
    'motorcycle': 'moto_50',
    'scooter': 'motoneta_45',
    'construction': 'retroex',
    'freightelevator': 'montacarga',
    'boat': 'barco',
    'ship': 'barco',
    'plane': 'helicoptero',
    'helicopter': 'helicoptero',
    'bicycle': 'bici_40',
    'person': 'sedan_50',
    'animal': 'sedan_50',
    'pickup': 'pickup_60',
    'taxi': 'taxi',
    'planer': 'aplanadora_75',
    'excavator': 'excavadora',
    'excavatorcrane': 'grua_excavadora_85',
  };

  static const _iconBaseUrl =
      'https://library.service24gps.com/img/iconUber/iconsDinamicos_new_medidas/';

  static const _colorNameToHex = {
    'green': '22c55e', // moving
    'yellow': 'eab308', // idle (ignition on, stopped)
    'orange': 'f97316', // parked (ignition off)
    'red': 'ef4444', // offline
  };

  static const _rotationStep = 22.5; // 16 frames per 360°

  String _iconUrl(String? category, String colorName, double course) {
    final icon =
        _category3dIcon[category?.toLowerCase()] ?? _category3dIcon['default']!;
    final hex = _colorNameToHex[colorName] ?? _colorNameToHex['grey']!;
    final snapped = (course % 360 ~/ _rotationStep) * _rotationStep;
    return '$_iconBaseUrl$icon.php?grados=${snapped.toStringAsFixed(1)}&c=$hex&b=F0F0F0';
  }

  /// Remainder degrees after quantizing to 22.5° frames
  double _rotationRemainder(double course) {
    return (course % 360) - (course % 360 ~/ _rotationStep) * _rotationStep;
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
      case 'tripstart':
        return Icons.play_arrow;
      case 'devicestopped':
      case 'tripend':
      case 'stopstart':
      case 'stopend':
        return Icons.stop;
      case 'deviceoverspeed':
        return Icons.speed;
      default:
        return Icons.event;
    }
  }

  Color _getEventColor(String type) {
    final colors = Theme.of(context).colorScheme;
    switch (type.toLowerCase()) {
      case 'ignitionon':
      case 'devicemoving':
      case 'tripstart':
        return colors.tertiary;
      case 'ignitionoff':
      case 'devicestopped':
      case 'tripend':
      case 'stopstart':
      case 'stopend':
        return colors.error;
      default:
        return colors.primary;
    }
  }

  Marker _buildMarkerFor(int deviceId, Position position, Device device) {
    final statusColor = DeviceColors.getDeviceColor(device, position, context);
    final colorName = DeviceColors.getDeviceColorName(device, position);
    final url = _iconUrl(device.category, colorName, position.course);
    final remainder = _rotationRemainder(position.course) * pi / 180;

    return Marker(
      key: ValueKey(deviceId),
      point: _animatedPoint(deviceId, position),
      width: 96,
      height: 110,
      alignment: Alignment.center,
      child: _AnimatedDeviceMarker(
        deviceId: deviceId,
        url: url,
        statusColor: statusColor,
        rotationRemainder: remainder,
        deviceName: device.name,
        fallbackIcon: DeviceIcons.getCategoryIcon(device),
        onTap: () => widget.onDeviceSelected?.call(deviceId),
      ),
    );
  }

  List<Marker> _buildDeviceMarkers() {
    if (widget.showingRoute) return [];

    final markers = <Marker>[];
    for (final entry in widget.positions.entries) {
      final deviceId = entry.key;
      final position = entry.value;
      final device = widget.devices[deviceId];
      if (device == null) continue;
      // Skip selected device — it's rendered separately outside the cluster
      if (deviceId == widget.selectedDevice) continue;

      markers.add(_buildMarkerFor(deviceId, position, device));
    }
    return markers;
  }

  List<Marker> _buildSelectedDeviceMarker() {
    if (widget.showingRoute || widget.selectedDevice == null) return [];
    final position = widget.positions[widget.selectedDevice!];
    final device = widget.devices[widget.selectedDevice!];
    if (position == null || device == null) return [];
    return [_buildMarkerFor(widget.selectedDevice!, position, device)];
  }

  List<Polygon> _buildGeofencePolygons() {
    final polygons = <Polygon>[];
    for (final geofence in widget.geofences.values) {
      final geometry = geofence.areaToGeometry();
      if (geometry == null || geometry['type'] != 'Polygon') continue;

      final rawCoords = (geometry['coordinates'][0] as List)
          .cast<List<dynamic>>();
      final points = rawCoords
          .map((c) => LatLng(c[1] as double, c[0] as double))
          .toList();

      polygons.add(
        Polygon(
          points: points,
          color: const Color(0x4D3FABC9),
          borderColor: const Color(0x993FABC9),
          borderStrokeWidth: 2,
        ),
      );
    }
    return polygons;
  }

  List<Polyline> _buildGeofenceLines() {
    final lines = <Polyline>[];
    for (final geofence in widget.geofences.values) {
      final geometry = geofence.areaToGeometry();
      if (geometry == null || geometry['type'] != 'LineString') continue;

      final rawCoords = (geometry['coordinates'] as List).cast<List<dynamic>>();
      final points = rawCoords
          .map((c) => LatLng(c[1] as double, c[0] as double))
          .toList();

      lines.add(
        Polyline(
          points: points,
          color: const Color(0x993FABC9),
          strokeWidth: 2,
        ),
      );
    }
    return lines;
  }

  List<Marker> _buildGeofenceLabels() {
    final markers = <Marker>[];
    for (final geofence in widget.geofences.values) {
      final geometry = geofence.areaToGeometry();
      if (geometry == null) continue;

      List<double>? centroid;
      if (geometry['type'] == 'Polygon') {
        final rawCoords = (geometry['coordinates'][0] as List)
            .cast<List<dynamic>>();
        final coords = rawCoords
            .map((c) => [c[0] as double, c[1] as double])
            .toList();
        centroid = geofence.polygonCentroid(coords);
      } else if (geometry['type'] == 'LineString') {
        final rawCoords = (geometry['coordinates'] as List)
            .cast<List<dynamic>>();
        if (rawCoords.isNotEmpty) {
          centroid = [rawCoords[0][0] as double, rawCoords[0][1] as double];
        }
      }

      if (centroid == null) continue;

      markers.add(
        Marker(
          point: LatLng(centroid[1], centroid[0]),
          width: 120,
          height: 22,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(204),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              geofence.name,
              style: const TextStyle(fontSize: 11, color: Colors.black),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }
    return markers;
  }

  bool get _hasSelectedPosition =>
      widget.eventPositionToCenter != null ||
      widget.movingSegmentPositions.length >= 2;

  List<Polyline> _buildRouteLines() {
    if (widget.routePositions.length < 2) return [];
    final points = widget.routePositions
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    final fade = _hasSelectedPosition ? 0.25 : 1.0;
    return [
      // White casing (wider, drawn first)
      Polyline(
        points: points,
        color: Colors.white.withValues(alpha: fade),
        strokeWidth: 9,
      ),
      // Blue route (narrower, on top)
      Polyline(
        points: points,
        color: const Color(0xFF2196F3).withValues(alpha: fade),
        strokeWidth: 5,
      ),
    ];
  }

  List<CircleMarker> _buildSpeedCircles() {
    if (widget.routePositions.isEmpty) return [];
    final speeds = widget.routePositions.map((p) => p.speed).toList();
    final maxSpeed = speeds.reduce((a, b) => a > b ? a : b);
    final fade = _hasSelectedPosition ? 0.2 : 1.0;
    return widget.routePositions.map((p) {
      final color = TurboColormap.getSpeedColor(p.speed, 0, maxSpeed);
      return CircleMarker(
        point: LatLng(p.latitude, p.longitude),
        radius: 2.5,
        color: color.withValues(alpha: fade),
        useRadiusInMeter: false,
      );
    }).toList();
  }

  List<Polyline> _buildMovingSegmentLine() {
    if (widget.movingSegmentPositions.length < 2) return [];
    final seg = widget.movingSegmentPositions;
    final points = seg.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final speeds = seg.map((p) => p.speed).toList();
    final maxSpeed = speeds.reduce((a, b) => a > b ? a : b);

    final lines = <Polyline>[
      // White casing
      Polyline(points: points, color: Colors.white, strokeWidth: 10),
    ];
    // Per-segment speed-colored lines on top
    for (int i = 0; i < points.length - 1; i++) {
      final avg = (speeds[i] + speeds[i + 1]) / 2;
      final color = TurboColormap.getSpeedColor(
        avg,
        0,
        maxSpeed > 0 ? maxSpeed : 1,
      );
      lines.add(
        Polyline(
          points: [points[i], points[i + 1]],
          color: color,
          strokeWidth: 6,
        ),
      );
    }
    return lines;
  }

  List<CircleMarker> _buildMovingSegmentCircles() {
    if (widget.movingSegmentPositions.length < 2) return [];
    final seg = widget.movingSegmentPositions;
    final speeds = seg.map((p) => p.speed).toList();
    final maxSpeed = speeds.reduce((a, b) => a > b ? a : b);
    return seg.map((p) {
      final color = TurboColormap.getSpeedColor(
        p.speed,
        0,
        maxSpeed > 0 ? maxSpeed : 1,
      );
      return CircleMarker(
        point: LatLng(p.latitude, p.longitude),
        radius: 2.5,
        color: color,
        useRadiusInMeter: false,
      );
    }).toList();
  }

  Marker _buildEventIconMarker(LatLng point, IconData icon, Color color) {
    return Marker(
      point: point,
      width: 36,
      height: 36,
      alignment: Alignment.center,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(64),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  List<Marker> _buildEventMarkers() {
    final markers = <Marker>[];

    // Event/position marker
    if (widget.eventPositionToCenter != null) {
      final pos = widget.eventPositionToCenter!;
      final point = LatLng(pos.latitude, pos.longitude);

      if (widget.positionLabel == 'Scrub' && widget.selectedDevice != null) {
        final device = widget.devices[widget.selectedDevice!];
        if (device != null) {
          final statusColor = DeviceColors.getDeviceColor(device, pos, context);
          final colorName = DeviceColors.getDeviceColorName(device, pos);
          final url = _iconUrl(device.category, colorName, pos.course);
          final remainder = _rotationRemainder(pos.course) * pi / 180;
          markers.add(
            Marker(
              point: point,
              width: 96,
              height: 110,
              alignment: Alignment.center,
              child: Transform.rotate(
                angle: remainder,
                child: _SvgIcon(
                  url: url,
                  statusColor: statusColor,
                  fallbackIcon: DeviceIcons.getCategoryIcon(device),
                ),
              ),
            ),
          );
          return markers;
        }
      }

      IconData icon;
      Color color;

      if (widget.selectedEvent != null) {
        icon = _getEventIcon(widget.selectedEvent!.displayType);
        color = const Color(0xFFFF5722);
      } else if (widget.positionLabel == 'Movement Start') {
        icon = Icons.play_arrow;
        color = Theme.of(context).colorScheme.tertiary;
      } else if (widget.positionLabel == 'Stop') {
        icon = Icons.stop;
        color = Theme.of(context).colorScheme.error;
      } else if (widget.positionLabel == 'AirTag Location') {
        icon = Icons.location_on;
        color = Theme.of(context).colorScheme.primary;
      } else {
        final isFirst = widget.isFirstPosition ?? true;
        icon = isFirst ? Icons.flag : Icons.flag_outlined;
        color = isFirst
            ? Theme.of(context).colorScheme.tertiary
            : Theme.of(context).colorScheme.error;
      }
      markers.add(_buildEventIconMarker(point, icon, color));
    }

    // Moving segment start/end markers
    if (widget.movingSegmentPositions.length >= 2) {
      if (widget.segmentStartEvent != null) {
        markers.add(
          _buildEventIconMarker(
            LatLng(
              widget.movingSegmentPositions.first.latitude,
              widget.movingSegmentPositions.first.longitude,
            ),
            _getEventIcon(widget.segmentStartEvent!.displayType),
            _getEventColor(widget.segmentStartEvent!.displayType),
          ),
        );
      }
      if (widget.segmentEndEvent != null) {
        markers.add(
          _buildEventIconMarker(
            LatLng(
              widget.movingSegmentPositions.last.latitude,
              widget.movingSegmentPositions.last.longitude,
            ),
            _getEventIcon(widget.segmentEndEvent!.displayType),
            _getEventColor(widget.segmentEndEvent!.displayType),
          ),
        );
      }
      return markers;
    }

    // Route start/end markers (only when no segment highlight or event marker)
    if (widget.routePositions.isNotEmpty &&
        widget.eventPositionToCenter == null) {
      final startPos = widget.routePositions.first;
      final endPos = widget.routePositions.last;
      markers.add(
        _buildEventIconMarker(
          LatLng(startPos.latitude, startPos.longitude),
          Icons.flag,
          const Color(0xFF4CAF50),
        ),
      );
      markers.add(
        _buildEventIconMarker(
          LatLng(endPos.latitude, endPos.longitude),
          Icons.flag_outlined,
          const Color(0xFFF44336),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final style = MapStyles.configs[_styleIndex];

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(0, 0),
            initialZoom: 2,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (_, __) => widget.onMapBackgroundTap?.call(),
          ),
          children: [
            TileLayer(
              urlTemplate: style.urlTemplateFor(context),
              subdomains: style.subdomains,
              userAgentPackageName: 'com.frotaweb.manager',
              tileProvider: CancellableNetworkTileProvider(),
            ),
            if (_geofencesSelected) ...[
              PolygonLayer(polygons: _buildGeofencePolygons()),
              PolylineLayer(polylines: _buildGeofenceLines()),
              MarkerLayer(markers: _buildGeofenceLabels()),
            ],
            PolylineLayer(polylines: _buildRouteLines()),
            CircleLayer(circles: _buildSpeedCircles()),
            if (_showCurrentLocation && _currentLocation != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: LatLng(
                      _currentLocation!.latitude,
                      _currentLocation!.longitude,
                    ),
                    radius: _currentLocation!.accuracy,
                    useRadiusInMeter: true,
                    color: Colors.blue.withAlpha(35),
                    borderColor: Colors.blue.withAlpha(100),
                    borderStrokeWidth: 1,
                  ),
                ],
              ),
            PolylineLayer(polylines: _buildMovingSegmentLine()),
            CircleLayer(circles: _buildMovingSegmentCircles()),
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 60,
                padding: const EdgeInsets.all(80),
                disableClusteringAtZoom: _clusterDisableZoom,
                animationsOptions: const AnimationsOptions(
                  zoom: Duration(milliseconds: 300),
                  fitBound: Duration(milliseconds: 300),
                  spiderfy: Duration(milliseconds: 300),
                ),
                markers: _buildDeviceMarkers(),
                size: const Size(48, 48),
                builder: (context, markers) {
                  final count = markers.length;
                  final size = count > 99 ? 56.0 : 48.0;
                  return Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(64),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: count > 99 ? 14 : 16,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            MarkerLayer(markers: _buildSelectedDeviceMarker()),
            MarkerLayer(markers: _buildEventMarkers()),
            if (_showCurrentLocation && _currentLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(
                      _currentLocation!.latitude,
                      _currentLocation!.longitude,
                    ),
                    width: 28,
                    height: 28,
                    child: Semantics(
                      label: AppLocalizations.of(context)!.myLocation,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (widget.positions.isEmpty)
          const Center(child: CircularProgressIndicator()),
        MapStyleSelector(
          selectedStyleIndex: _styleIndex,
          mapReady: true,
          onStyleSelected: (index) => setState(() => _styleIndex = index),
          geofencesLayer: _geofencesSelected,
          onLayerSelected: () =>
              setState(() => _geofencesSelected = !_geofencesSelected),
          onZoomIn: () => _mapController.move(
            _mapController.camera.center,
            _mapController.camera.zoom + 1,
          ),
          onZoomOut: () => _mapController.move(
            _mapController.camera.center,
            _mapController.camera.zoom - 1,
          ),
          currentLocationLayer: _showCurrentLocation,
          locatingCurrentLocation: _locatingCurrentLocation,
          onCurrentLocationSelected: _toggleCurrentLocation,
        ),
      ],
    );
  }
}

class _AnimatedDeviceMarker extends StatelessWidget {
  final int deviceId;
  final String url;
  final Color statusColor;
  final double rotationRemainder;
  final String deviceName;
  final IconData fallbackIcon;
  final VoidCallback? onTap;

  const _AnimatedDeviceMarker({
    required this.deviceId,
    required this.url,
    required this.statusColor,
    required this.rotationRemainder,
    required this.deviceName,
    required this.fallbackIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            key: ValueKey('rot_$deviceId'),
            tween: Tween(end: rotationRemainder),
            duration: const Duration(seconds: 2),
            curve: Curves.easeOut,
            builder: (context, angle, child) =>
                Transform.rotate(angle: angle, child: child),
            child: _SvgIcon(
              url: url,
              statusColor: statusColor,
              fallbackIcon: fallbackIcon,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(204),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              deviceName,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SvgIcon extends StatefulWidget {
  final String url;
  final Color statusColor;
  final IconData fallbackIcon;

  const _SvgIcon({
    required this.url,
    required this.statusColor,
    this.fallbackIcon = Icons.navigation,
  });

  @override
  State<_SvgIcon> createState() => _SvgIconState();
}

class _SvgIconState extends State<_SvgIcon> {
  String? _svgData;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _svgData = SvgCache.getSync(widget.url);
    if (_svgData == null) _load();
  }

  @override
  void didUpdateWidget(_SvgIcon old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _svgData = SvgCache.getSync(widget.url);
      _failed = false;
      if (_svgData == null) _load();
    }
  }

  Future<void> _load() async {
    final svg = await SvgCache.get(widget.url);
    if (!mounted) return;
    setState(() {
      _svgData = svg;
      _failed = svg == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_svgData != null) {
      return SvgPicture.string(_svgData!, width: 72, height: 72);
    }
    if (_failed) {
      return Icon(widget.fallbackIcon, color: widget.statusColor, size: 56);
    }
    return const SizedBox(width: 72, height: 72);
  }
}
