import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import '../models/device.dart';
import '../models/geofence.dart';
import '../models/position.dart';
import '../models/event.dart';
import '../utils/constants.dart';
import '../utils/device_colors.dart';
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

class _MapViewState extends State<MapView> {
  final _mapController = MapController();
  int _styleIndex = 0;
  bool _geofencesSelected = true;
  bool _initialFitDone = false;
  List<Position> _lastRoutePositions = [];
  List<Position> _lastMovingSegmentPositions = [];

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);

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
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _centerOnDevice(widget.selectedDevice!));
    }

    // Center on event position
    if (widget.eventPositionToCenter != null &&
        widget.eventPositionToCenter != oldWidget.eventPositionToCenter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final pos = widget.eventPositionToCenter!;
        _mapController.move(
          LatLng(pos.latitude, pos.longitude),
          _mapController.camera.zoom < 14 ? 14 : _mapController.camera.zoom,
        );
      });
    }

    // Fit to route when route positions change
    if (!_routePositionsEqual(widget.routePositions, _lastRoutePositions) &&
        widget.routePositions.length >= 2) {
      _lastRoutePositions = List.from(widget.routePositions);
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _fitMapToRoute());
    }

    // Fit to moving segment when it changes
    if (!_routePositionsEqual(
        widget.movingSegmentPositions, _lastMovingSegmentPositions)) {
      final wasHighlighted = _lastMovingSegmentPositions.isNotEmpty;
      _lastMovingSegmentPositions = List.from(widget.movingSegmentPositions);
      if (widget.movingSegmentPositions.length >= 2) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _fitMapToMovingSegment());
      } else if (wasHighlighted && widget.routePositions.isNotEmpty) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _fitMapToRoute());
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
    final zoom = _mapController.camera.zoom < selectedZoomLevel
        ? selectedZoomLevel
        : _mapController.camera.zoom;
    _mapController.move(LatLng(position.latitude, position.longitude), zoom);
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
    'default':         'sedan_50',
    'car':             'sedan_50',
    'van':             'furgoneta_60',
    'camper':          'furgoneta_ventana',
    'truck':           'cam_caja_60',
    'bus':             'bus_85',
    'tractor':         'tractor_v2',
    'crane':           'grua_v2',
    'trailer':         'remolque_caja_70',
    'motorcycle':      'moto_50',
    'scooter':         'motoneta_45',
    'construction':    'retroex',
    'freightelevator': 'montacarga',
    'boat':            'barco',
    'ship':            'barco',
    'plane':           'helicoptero',
    'helicopter':      'helicoptero',
    'bicycle':         'bici_40',
    'person':          'sedan_50',
    'animal':          'sedan_50',
    'pickup':          'pickup_60',
    'taxi':            'taxi',
    'planer':          'aplanadora_75',
    'excavator':       'excavadora',
    'excavatorcrane':  'grua_excavadora_85',
  };

  static const _iconBaseUrl =
      'https://library.service24gps.com/img/iconUber/iconsDinamicos_new_medidas/';

  static const _colorNameToHex = {
    'green': '22c55e',   // moving
    'yellow': 'eab308',  // idle (ignition on, stopped)
    'orange': 'f97316',  // parked (ignition off)
    'red': 'ef4444',     // offline
  };

  static const _rotationStep = 22.5; // 16 frames per 360°

  String _iconUrl(String? category, String colorName, double course) {
    final icon = _category3dIcon[category?.toLowerCase()] ??
        _category3dIcon['default']!;
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
        return platform_icons.PlatformIcons.play;
      case 'devicestopped':
      case 'tripend':
      case 'stopstart':
      case 'stopend':
        return Icons.stop_circle;
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

  List<Marker> _buildDeviceMarkers() {
    if (widget.showingRoute) return [];

    final markers = <Marker>[];
    for (final entry in widget.positions.entries) {
      final deviceId = entry.key;
      final position = entry.value;
      final device = widget.devices[deviceId];
      if (device == null) continue;

      final statusColor = DeviceColors.getDeviceColor(device, position, context);
      final colorName = DeviceColors.getDeviceColorName(device, position);
      final url = _iconUrl(device.category, colorName, position.course);
      final remainder = _rotationRemainder(position.course) * pi / 180;

      markers.add(Marker(
        point: LatLng(position.latitude, position.longitude),
        width: 96,
        height: 110,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () => widget.onDeviceSelected?.call(deviceId),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: remainder,
                child: _SvgIcon(
                  url: url,
                  statusColor: statusColor,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(204),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  device.name,
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
        ),
      ));
    }
    return markers;
  }

  List<Polygon> _buildGeofencePolygons() {
    final polygons = <Polygon>[];
    for (final geofence in widget.geofences.values) {
      final geometry = geofence.areaToGeometry();
      if (geometry == null || geometry['type'] != 'Polygon') continue;

      final rawCoords =
          (geometry['coordinates'][0] as List).cast<List<dynamic>>();
      final points = rawCoords
          .map((c) => LatLng(c[1] as double, c[0] as double))
          .toList();

      polygons.add(Polygon(
        points: points,
        color: const Color(0x4D3FABC9),
        borderColor: const Color(0x993FABC9),
        borderStrokeWidth: 2,
      ));
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

      lines.add(Polyline(
        points: points,
        color: const Color(0x993FABC9),
        strokeWidth: 2,
      ));
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
        final rawCoords =
            (geometry['coordinates'][0] as List).cast<List<dynamic>>();
        final coords =
            rawCoords.map((c) => [c[0] as double, c[1] as double]).toList();
        centroid = geofence.polygonCentroid(coords);
      } else if (geometry['type'] == 'LineString') {
        final rawCoords =
            (geometry['coordinates'] as List).cast<List<dynamic>>();
        if (rawCoords.isNotEmpty) {
          centroid = [rawCoords[0][0] as double, rawCoords[0][1] as double];
        }
      }

      if (centroid == null) continue;

      markers.add(Marker(
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
      ));
    }
    return markers;
  }

  List<Polyline> _buildRouteLines() {
    if (widget.routePositions.length < 2) return [];
    final points = widget.routePositions
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    return [
      Polyline(points: points, color: Colors.white, strokeWidth: 5),
      Polyline(points: points, color: const Color(0xFF2196F3), strokeWidth: 8),
    ];
  }

  List<CircleMarker> _buildSpeedCircles() {
    if (widget.routePositions.isEmpty) return [];
    final speeds = widget.routePositions.map((p) => p.speed).toList();
    final maxSpeed = speeds.reduce((a, b) => a > b ? a : b);
    return widget.routePositions.map((p) {
      final color = TurboColormap.getSpeedColor(p.speed, 0, maxSpeed);
      return CircleMarker(
        point: LatLng(p.latitude, p.longitude),
        radius: 2.5,
        color: color,
        useRadiusInMeter: false,
      );
    }).toList();
  }

  List<Polyline> _buildMovingSegmentLine() {
    if (widget.movingSegmentPositions.length < 2) return [];
    final points = widget.movingSegmentPositions
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    return [
      Polyline(
        points: points,
        color: const Color(0x804CAF50),
        strokeWidth: 6,
      ),
    ];
  }

  Marker _buildEventIconMarker(
      LatLng point, IconData icon, Color color) {
    return Marker(
      point: point,
      width: 36,
      height: 36,
      child: Container(
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
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  List<Marker> _buildEventMarkers() {
    final markers = <Marker>[];

    // Event/position marker
    if (widget.eventPositionToCenter != null) {
      final pos = widget.eventPositionToCenter!;
      final point = LatLng(pos.latitude, pos.longitude);
      IconData icon;
      Color color;

      if (widget.selectedEvent != null) {
        icon = _getEventIcon(widget.selectedEvent!.displayType);
        color = const Color(0xFFFF5722);
      } else if (widget.positionLabel == 'Movement Start') {
        icon = platform_icons.PlatformIcons.play;
        color = Theme.of(context).colorScheme.tertiary;
      } else if (widget.positionLabel == 'Stop') {
        icon = Icons.stop_circle;
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
        markers.add(_buildEventIconMarker(
          LatLng(widget.movingSegmentPositions.first.latitude,
              widget.movingSegmentPositions.first.longitude),
          _getEventIcon(widget.segmentStartEvent!.displayType),
          _getEventColor(widget.segmentStartEvent!.displayType),
        ));
      }
      if (widget.segmentEndEvent != null) {
        markers.add(_buildEventIconMarker(
          LatLng(widget.movingSegmentPositions.last.latitude,
              widget.movingSegmentPositions.last.longitude),
          _getEventIcon(widget.segmentEndEvent!.displayType),
          _getEventColor(widget.segmentEndEvent!.displayType),
        ));
      }
      return markers;
    }

    // Route start/end markers (only when no segment highlight or event marker)
    if (widget.routePositions.isNotEmpty &&
        widget.eventPositionToCenter == null) {
      final startPos = widget.routePositions.first;
      final endPos = widget.routePositions.last;
      markers.add(Marker(
        point: LatLng(startPos.latitude, startPos.longitude),
        width: 36,
        height: 36,
        child: const Icon(Icons.flag, color: Color(0xFF4CAF50), size: 36),
      ));
      markers.add(Marker(
        point: LatLng(endPos.latitude, endPos.longitude),
        width: 36,
        height: 36,
        child: const Icon(Icons.flag_outlined,
            color: Color(0xFFF44336), size: 36),
      ));
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
              urlTemplate: style.urlTemplate,
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
            PolylineLayer(polylines: _buildMovingSegmentLine()),
            MarkerLayer(markers: _buildDeviceMarkers()),
            MarkerLayer(markers: _buildEventMarkers()),
          ],
        ),
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
        ),
      ],
    );
  }
}

class _SvgIcon extends StatefulWidget {
  final String url;
  final Color statusColor;

  const _SvgIcon({required this.url, required this.statusColor});

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
      return Icon(Icons.error_outline, color: widget.statusColor, size: 56);
    }
    return const SizedBox(width: 72, height: 72);
  }
}
