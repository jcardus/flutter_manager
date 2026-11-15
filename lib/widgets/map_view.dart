import 'dart:developer' as dev;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:platform_maps_flutter/platform_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:manager/l10n/app_localizations.dart';
import '../models/device.dart';
import '../models/geofence.dart';
import '../models/position.dart';
import '../models/event.dart';
import '../utils/device_colors.dart';
import '../utils/vehicle_icon_cache.dart';
import '../utils/turbo_colormap.dart';
import '../utils/marker_bitmap_helper.dart';
import '../utils/event_display.dart';
import 'map/style_selector.dart';

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
  PlatformMapController? _mapController;
  int _styleIndex = 0;
  bool _geofencesSelected = true;
  bool _initialFitDone = false;
  List<Position> _lastRoutePositions = [];
  List<Position> _lastMovingSegmentPositions = [];
  bool _showCurrentLocation = false;
  bool _locatingCurrentLocation = false;
  double _currentZoom = 12.0;

  final Map<String, BitmapDescriptor> _vehicleBitmaps = {};
  Set<Marker> _eventMarkers = {};

  @override
  void initState() {
    super.initState();
    _loadBitmaps();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateEventMarkers();
  }

  @override
  void dispose() {
    super.dispose();
  }

  MapType get _currentMapType {
    switch (_styleIndex) {
      case 1:
        return MapType.satellite;
      case 2:
        return MapType.hybrid;
      default:
        return MapType.normal;
    }
  }

  bool get _currentTrafficEnabled => _styleIndex == 3;

  void _loadBitmaps() {
    for (final entry in widget.positions.entries) {
      final device = widget.devices[entry.key];
      if (device == null) continue;
      final colorName = DeviceColors.getDeviceColorName(device, entry.value);
      final icon = VehicleIcon.forDevice(device.category, colorName, entry.value.course);
      final key = '${icon.shape}_${(icon.angle * 10).round()}_${icon.cabHex}_${icon.bodyHex}';
      if (!_vehicleBitmaps.containsKey(key)) {
        MarkerBitmapHelper.getVehicleBitmap(icon).then((bitmap) {
          if (bitmap != null && mounted) {
            setState(() {
              _vehicleBitmaps[key] = bitmap;
            });
          }
        });
      }
    }
  }

  void _updateEventMarkers() {
    _buildEventMarkers().then((markers) {
      if (mounted) setState(() => _eventMarkers = markers);
    });
  }

  Future<void> _toggleCurrentLocation() async {
    if (_showCurrentLocation) {
      if (mounted) {
        setState(() {
          _showCurrentLocation = false;
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
      });
      _animatedMove(LatLng(position.latitude, position.longitude), 16);
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
    _currentZoom = zoom;
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(dest, zoom),
    );
  }

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadBitmaps();
    _updateEventMarkers();

    // Initial fit on first data
    if (!_initialFitDone &&
        widget.positions.isNotEmpty &&
        widget.selectedIndex == 0) {
      _initialFitDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToDevices());
    }

    // Center on newly selected device or when returning to map
    if (widget.selectedDevice != null &&
        (widget.selectedDevice != oldWidget.selectedDevice ||
         (widget.selectedIndex == 0 && oldWidget.selectedIndex != 0) ||
         (widget.eventPositionToCenter == null && oldWidget.eventPositionToCenter != null))) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _centerOnDevice(widget.selectedDevice!),
      );
    }

    // Center on event position
    if (widget.eventPositionToCenter != null &&
        widget.eventPositionToCenter != oldWidget.eventPositionToCenter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final pos = widget.eventPositionToCenter;
        if (pos == null) return;
        final target = LatLng(pos.latitude, pos.longitude);
        final zoom = _currentZoom < 14 ? 14.0 : _currentZoom;
        _animatedMove(target, zoom);
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
    final targetZoom = _currentZoom < 15 ? 15.0 : _currentZoom;
    _animatedMove(dest, targetZoom);
  }

  void _fitMapToDevices() {
    if (widget.positions.isEmpty) return;
    _fitToPoints(
      widget.positions.values
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList(),
      bottomPadding: 120,
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
      bottomPadding: 80,
    );
  }

  void _fitToPoints(List<LatLng> points, {double bottomPadding = 50}) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      _animatedMove(points.first, 15);
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    try {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, bottomPadding),
      );
    } catch (e) {
      dev.log('_fitToPoints error: $e');
    }
  }

  Set<Marker> _buildDeviceMarkers() {
    if (widget.showingRoute) return const {};

    final markers = <Marker>{};
    for (final entry in widget.positions.entries) {
      final deviceId = entry.key;
      final position = entry.value;
      final device = widget.devices[deviceId];
      if (device == null) continue;

      final colorName = DeviceColors.getDeviceColorName(device, position);
      final icon = VehicleIcon.forDevice(device.category, colorName, position.course);
      final key = '${icon.shape}_${(icon.angle * 10).round()}_${icon.cabHex}_${icon.bodyHex}';
      final bitmap = _vehicleBitmaps[key];
      if (bitmap == null) continue;

      markers.add(
        Marker(
          markerId: MarkerId('device_$deviceId'),
          position: LatLng(position.latitude, position.longitude),
          icon: bitmap,
          infoWindow: InfoWindow(
            title: device.name,
            snippet: position.speed > 0
                ? '${position.speed.toStringAsFixed(0)} km/h'
                : 'Parado',
          ),
          onTap: () {
            _centerOnDevice(deviceId);
            widget.onDeviceSelected?.call(deviceId);
          },
        ),
      );
    }
    return markers;
  }

  Set<Polygon> _buildGeofencePolygons() {
    if (!_geofencesSelected) return const {};
    final polygons = <Polygon>{};
    for (final geofence in widget.geofences.values) {
      final geometry = geofence.areaToGeometry();
      if (geometry == null || geometry['type'] != 'Polygon') continue;

      final rawCoords = (geometry['coordinates'][0] as List).cast<List<dynamic>>();
      final points = rawCoords
          .map((c) => LatLng(c[1] as double, c[0] as double))
          .toList();

      polygons.add(
        Polygon(
          polygonId: PolygonId('geofence_poly_${geofence.id}'),
          points: points,
          fillColor: const Color(0x4D3FABC9),
          strokeColor: const Color(0x993FABC9),
          strokeWidth: 2,
        ),
      );
    }
    return polygons;
  }

  Set<Polyline> _buildGeofenceLines() {
    if (!_geofencesSelected) return const {};
    final lines = <Polyline>{};
    for (final geofence in widget.geofences.values) {
      final geometry = geofence.areaToGeometry();
      if (geometry == null || geometry['type'] != 'LineString') continue;

      final rawCoords = (geometry['coordinates'] as List).cast<List<dynamic>>();
      final points = rawCoords
          .map((c) => LatLng(c[1] as double, c[0] as double))
          .toList();

      lines.add(
        Polyline(
          polylineId: PolylineId('geofence_line_${geofence.id}'),
          points: points,
          color: const Color(0x993FABC9),
          width: 2,
        ),
      );
    }
    return lines;
  }

  bool get _hasSelectedPosition =>
      widget.eventPositionToCenter != null ||
      widget.movingSegmentPositions.length >= 2;

  Set<Polyline> _buildRouteLines() {
    if (widget.routePositions.length < 2) return const {};
    final points = widget.routePositions
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    final fade = _hasSelectedPosition ? 0.25 : 1.0;
    return {
      // White casing
      Polyline(
        polylineId: PolylineId('route_casing'),
        points: points,
        color: Colors.white.withValues(alpha: fade),
        width: 8,
        zIndex: 1,
      ),
      // Blue core
      Polyline(
        polylineId: PolylineId('route_core'),
        points: points,
        color: const Color(0xFF2196F3).withValues(alpha: fade),
        width: 5,
        zIndex: 2,
      ),
    };
  }

  Set<Polyline> _buildMovingSegmentLines() {
    if (widget.movingSegmentPositions.length < 2) return const {};
    final seg = widget.movingSegmentPositions;
    final points = seg.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final speeds = seg.map((p) => p.speed).toList();
    final maxSpeed = speeds.reduce((a, b) => a > b ? a : b);

    final lines = <Polyline>{
      Polyline(
        polylineId: PolylineId('seg_casing'),
        points: points,
        color: Colors.white,
        width: 9,
        zIndex: 3,
      ),
    };

    for (int i = 0; i < points.length - 1; i++) {
      final avg = (speeds[i] + speeds[i + 1]) / 2;
      final color = TurboColormap.getSpeedColor(
        avg,
        0,
        maxSpeed > 0 ? maxSpeed : 1,
      );
      lines.add(
        Polyline(
          polylineId: PolylineId('seg_$i'),
          points: [points[i], points[i + 1]],
          color: color,
          width: 5,
          zIndex: 4,
        ),
      );
    }
    return lines;
  }

  Future<Set<Marker>> _buildEventMarkers() async {
    final markers = <Marker>{};
    if (!mounted) return markers;

    final tertiaryColor = Theme.of(context).colorScheme.tertiary;
    final errorColor = Theme.of(context).colorScheme.error;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final segStartColor = widget.segmentStartEvent != null
        ? EventDisplay.color(context, widget.segmentStartEvent!.displayType)
        : null;
    final segEndColor = widget.segmentEndEvent != null
        ? EventDisplay.color(context, widget.segmentEndEvent!.displayType)
        : null;

    if (widget.eventPositionToCenter != null) {
      final pos = widget.eventPositionToCenter!;
      final point = LatLng(pos.latitude, pos.longitude);

      IconData icon;
      Color color;
      if (widget.selectedEvent != null) {
        icon = EventDisplay.icon(widget.selectedEvent!.displayType);
        color = const Color(0xFFFF5722);
      } else if (widget.positionLabel == 'Movement Start') {
        icon = Icons.play_arrow;
        color = tertiaryColor;
      } else if (widget.positionLabel == 'Stop') {
        icon = Icons.stop;
        color = errorColor;
      } else if (widget.positionLabel == 'AirTag Location') {
        icon = Icons.location_on;
        color = primaryColor;
      } else {
        final isFirst = widget.isFirstPosition ?? true;
        icon = isFirst ? Icons.flag : Icons.flag_outlined;
        color = isFirst ? tertiaryColor : errorColor;
      }

      final bitmap = await MarkerBitmapHelper.getCircleIconBitmap(
        icon: icon,
        color: color,
      );
      markers.add(
        Marker(
          markerId: MarkerId('event_marker'),
          position: point,
          icon: bitmap,
        ),
      );
    }

    if (widget.movingSegmentPositions.length >= 2) {
      if (widget.segmentStartEvent != null && segStartColor != null) {
        final pos = widget.movingSegmentPositions.first;
        final icon = EventDisplay.icon(widget.segmentStartEvent!.displayType);
        final bitmap = await MarkerBitmapHelper.getCircleIconBitmap(icon: icon, color: segStartColor);
        markers.add(
          Marker(
            markerId: MarkerId('segment_start'),
            position: LatLng(pos.latitude, pos.longitude),
            icon: bitmap,
          ),
        );
      }
      if (widget.segmentEndEvent != null && segEndColor != null) {
        final pos = widget.movingSegmentPositions.last;
        final icon = EventDisplay.icon(widget.segmentEndEvent!.displayType);
        final bitmap = await MarkerBitmapHelper.getCircleIconBitmap(icon: icon, color: segEndColor);
        markers.add(
          Marker(
            markerId: MarkerId('segment_end'),
            position: LatLng(pos.latitude, pos.longitude),
            icon: bitmap,
          ),
        );
      }
    } else if (widget.routePositions.isNotEmpty && widget.eventPositionToCenter == null) {
      final start = widget.routePositions.first;
      final end = widget.routePositions.last;
      final startBitmap = await MarkerBitmapHelper.getCircleIconBitmap(
        icon: Icons.flag,
        color: const Color(0xFF4CAF50),
      );
      final endBitmap = await MarkerBitmapHelper.getCircleIconBitmap(
        icon: Icons.flag_outlined,
        color: const Color(0xFFF44336),
      );
      markers.add(
        Marker(
          markerId: MarkerId('route_start'),
          position: LatLng(start.latitude, start.longitude),
          icon: startBitmap,
        ),
      );
      markers.add(
        Marker(
          markerId: MarkerId('route_end'),
          position: LatLng(end.latitude, end.longitude),
          icon: endBitmap,
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final deviceMarkers = _buildDeviceMarkers();
    final allMarkers = <Marker>{
      ...deviceMarkers,
      ..._eventMarkers,
    };

    final allPolylines = <Polyline>{
      ..._buildGeofenceLines(),
      ..._buildRouteLines(),
      ..._buildMovingSegmentLines(),
    };

    final allPolygons = _buildGeofencePolygons();

    return Stack(
      children: [
        PlatformMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(0, 0),
            zoom: 2,
          ),
          mapType: _currentMapType,
          trafficEnabled: _currentTrafficEnabled,
          myLocationEnabled: _showCurrentLocation,
          myLocationButtonEnabled: false,
          compassEnabled: true,
          rotateGesturesEnabled: true,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          tiltGesturesEnabled: true,
          markers: allMarkers,
          polylines: allPolylines,
          polygons: allPolygons,
          onMapCreated: (controller) {
            _mapController = controller;
            if (widget.selectedDevice != null) {
              _initialFitDone = true;
              Future.delayed(
                const Duration(milliseconds: 300),
                () => _centerOnDevice(widget.selectedDevice!),
              );
            } else if (widget.positions.isNotEmpty && !_initialFitDone) {
              _initialFitDone = true;
              Future.delayed(const Duration(milliseconds: 300), _fitMapToDevices);
            }
          },
          onCameraMove: (position) {
            _currentZoom = position.zoom;
          },
          onTap: (_) => widget.onMapBackgroundTap?.call(),
        ),
        if (widget.positions.isEmpty)
          const Center(child: CircularProgressIndicator()),
        MapStyleSelector(
          selectedStyleIndex: _styleIndex,
          mapReady: _mapController != null,
          onStyleSelected: (index) => setState(() => _styleIndex = index),
          geofencesLayer: _geofencesSelected,
          onLayerSelected: () => setState(() => _geofencesSelected = !_geofencesSelected),
          onZoomIn: () => _mapController?.animateCamera(CameraUpdate.zoomIn()),
          onZoomOut: () => _mapController?.animateCamera(CameraUpdate.zoomOut()),
          currentLocationLayer: _showCurrentLocation,
          locatingCurrentLocation: _locatingCurrentLocation,
          onCurrentLocationSelected: _toggleCurrentLocation,
        ),
      ],
    );
  }
}
