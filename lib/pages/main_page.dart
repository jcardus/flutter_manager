import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/geofence.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';
import '../models/device.dart';
import '../models/position.dart';
import '../models/event.dart';
import '../widgets/devices_list_view.dart';
import '../widgets/map_view.dart';
import '../widgets/profile_view.dart';
import '../widgets/device_bottom_sheet.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  final SocketService _socketService = SocketService();
  final ApiService _apiService = ApiService();
  StreamSubscription? _wsSub;
  bool _wsConnected = false;

  final Map<int, Device> _devices = {};
  final Map<int, Position> _positions = {};
  final Map<int, Geofence> _geofences = {};
  int? _selectedDeviceId;
  bool _showingRoute = false;
  List<Position> _routePositions = [];
  List<Position> _movingSegmentPositions = [];
  Event? _segmentStartEvent;
  Event? _segmentEndEvent;
  double _bottomSheetSize = 0.0;
  Position? _eventPositionToCenter;
  Event? _selectedEvent;
  bool? _isFirstPosition;
  String? _positionLabel;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final devices = await _apiService.fetchDevices();
    final devicesMap = <int, Device>{};
    for (var device in devices) { devicesMap[device.id] = device; }
    final positions = await _apiService.fetchPositions();
    final positionsMap = <int, Position>{};
    for (var position in positions) { positionsMap[position.deviceId] = position; }
    final geofences = await _apiService.fetchGeofences();
    final geofenceMap = <int, Geofence>{};
    for (var geofence in geofences) { geofenceMap[geofence.id] = geofence; }
    setState(() {
      _devices.addAll(devicesMap);
      _positions.addAll(positionsMap);
      _geofences.addAll(geofenceMap);
    });
    if (!mounted) return;
    await _connectSocket();
  }

  void _onDeviceTap(int deviceId) {
    setState(() {
      _selectedDeviceId = deviceId;
      _selectedIndex = 0; // Switch to map view
    });
  }

  void _closeBottomSheet() {
    setState(() {
      _selectedDeviceId = null;
      _showingRoute = false;
      _routePositions = [];
      _movingSegmentPositions = [];
      _segmentStartEvent = null;
      _segmentEndEvent = null;
      _bottomSheetSize = 0.0;
    });
  }

  void _onRouteToggle(bool showingRoute) {
    setState(() {
      _showingRoute = showingRoute;
      if (!showingRoute) {
        _routePositions = [];
        _movingSegmentPositions = [];
        _segmentStartEvent = null;
        _segmentEndEvent = null;
      }
    });
  }

  void _onRoutePositionsLoaded(List<Position> positions) {
    setState(() {
      _routePositions = positions;
      // Clear map icons when new route data is loaded (e.g., date change)
      _movingSegmentPositions = [];
      _segmentStartEvent = null;
      _segmentEndEvent = null;
      _eventPositionToCenter = null;
      _selectedEvent = null;
      _isFirstPosition = null;
    });
  }

  void _onStateSegmentTap(List<Position> positions, Event startEvent, Event endEvent) {
    setState(() {
      _movingSegmentPositions = positions;
      _segmentStartEvent = startEvent;
      _segmentEndEvent = endEvent;
    });
  }

  void _clearMovingSegmentHighlight() {
    if (_movingSegmentPositions.isNotEmpty) {
      setState(() {
        _movingSegmentPositions = [];
        _segmentStartEvent = null;
        _segmentEndEvent = null;
      });
    }
  }

  void _onBottomSheetSizeChanged(double size) {
    setState(() {
      _bottomSheetSize = size;
    });
  }

  void _onEventTap(Position position, Event event) {
    setState(() {
      _eventPositionToCenter = position;
      _selectedEvent = event;
      // Clear moving segment highlight when tapping an event
      _movingSegmentPositions = [];
      _segmentStartEvent = null;
      _segmentEndEvent = null;
    });
    // Reset after next frame to allow MapView to process it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _eventPositionToCenter = null;
        });
      }
    });
  }

  void _onPositionTap(Position position, bool isFirst, String? label) {
    setState(() {
      _eventPositionToCenter = position;
      _selectedEvent = null;
      _isFirstPosition = isFirst;
      _positionLabel = label;
      // Clear moving segment highlight when tapping a position
      _movingSegmentPositions = [];
      _segmentStartEvent = null;
      _segmentEndEvent = null;
    });
    // Reset after next frame to allow MapView to process it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _eventPositionToCenter = null;
          _isFirstPosition = null;
          _positionLabel = null;
        });
      }
    });
  }

  Widget _buildCurrentScreen() {
    return Stack(
      children: [
        // Keep map alive but only visible when selected
        Offstage(
          offstage: _selectedIndex != 0,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = constraints.maxHeight;
              // Map height = screen height - bottom sheet height + 10px overlap
              // This creates a small gap so the rounded top corners of the sheet are visible
              final mapHeight = _selectedDeviceId != null
                  ? screenHeight * (1 - _bottomSheetSize) + 10
                  : screenHeight;
              return SizedBox(
                height: mapHeight,
                child: MapView(
                  devices: _devices,
                  positions: _positions,
                  geofences: _geofences,
                  selectedDevice: _selectedDeviceId,
                  selectedIndex: _selectedIndex,
                  showingRoute: _showingRoute,
                  routePositions: _routePositions,
                  movingSegmentPositions: _movingSegmentPositions,
                  segmentStartEvent: _segmentStartEvent,
                  segmentEndEvent: _segmentEndEvent,
                  onDeviceSelected: _onDeviceTap,
                  eventPositionToCenter: _eventPositionToCenter,
                  selectedEvent: _selectedEvent,
                  isFirstPosition: _isFirstPosition,
                  positionLabel: _positionLabel,
                  onMapBackgroundTap: _clearMovingSegmentHighlight,
                ),
              );
            },
          ),
        ),
        // Conditionally render other views (not kept alive)
        if (_selectedIndex == 1)
          DevicesListView(
            devices: _devices,
            positions: _positions,
            onDeviceTap: _onDeviceTap,
          ),
        if (_selectedIndex == 2)
          ProfileView(
            deviceCount: _devices.length,
            activeCount: _positions.length,
            wsConnected: _wsConnected,
            wsLastMessage: _socketService.lastMessageTime,
          ),
      ],
    );
  }

  Future<void> _connectSocket() async {
    _socketService.onStatusChanged = () {
      if (mounted) setState(() => _wsConnected = _socketService.isConnected);
    };
    _wsSub = _socketService.stream.listen(_handleWebSocketMessage);
    await _socketService.connect();
  }

  void _handleWebSocketMessage(dynamic event) {
    if (event is! String) return;

    final data = jsonDecode(event) as Map<String, dynamic>;

    final Map<int, Device> newDevices = {};
    final Map<int, Position> newPositions = {};

    if (data['devices'] != null) {
      final devicesList = data['devices'] as List;
      for (var deviceJson in devicesList) {
        final device = Device.fromJson(deviceJson as Map<String, dynamic>);
        newDevices[device.id] = device;
      }
    }

    if (data['positions'] != null) {
      final positionsList = data['positions'] as List;
      for (var positionJson in positionsList) {
        final position = Position.fromJson(positionJson as Map<String, dynamic>);
        newPositions[position.deviceId] = position;
      }
    }

    if (newDevices.isNotEmpty || newPositions.isNotEmpty) {
      setState(() {
        if (newDevices.isNotEmpty) {
          _devices.addAll(newDevices);
        }
        if (newPositions.isNotEmpty) {
          _positions.addAll(newPositions);
        }
      });
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _socketService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canPop = _selectedDeviceId == null && _selectedIndex == 0;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_showingRoute) {
          _onRouteToggle(false);
        } else if (_selectedDeviceId != null) {
          _closeBottomSheet();
        } else if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
        }
      },
      child: Scaffold(
      body: Padding(
        padding: EdgeInsets.only(bottom: Platform.isAndroid ? MediaQuery.of(context).padding.bottom : 0),
        child: Stack(
        children: [
          _buildCurrentScreen(),
          // Floating Navigation Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 32,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildNavItem(0, Icons.map_outlined, Icons.map, l10n.map),
                            const SizedBox(width: 4),
                            _buildNavItem(1, Icons.list_outlined, Icons.list, l10n.devices),
                            const SizedBox(width: 4),
                            _buildNavItem(2, Icons.person_outline, Icons.person, l10n.profile),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Device Bottom Sheet
          _BottomSheetBuilder(
            selectedDeviceId: _selectedDeviceId,
            devices: _devices,
            positions: _positions,
            onClose: _closeBottomSheet,
            onRouteToggle: _onRouteToggle,
            showingRoute: _showingRoute,
            onRoutePositionsLoaded: _onRoutePositionsLoaded,
            onSheetSizeChanged: _onBottomSheetSizeChanged,
            onEventTap: _onEventTap,
            onPositionTap: _onPositionTap,
            onStateSegmentTap: _onStateSegmentTap,
            highlightedSegmentPositions: _movingSegmentPositions,
          ),
          // Back button when showing route
          if (_showingRoute)
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Material(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    elevation: 4,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => _onRouteToggle(false),
                      iconSize: 24,
                    ),
                  ),
                ),
              ),
            ),
        ],
        ),
      ),
    ),
    );
  }

  Widget _buildNavItem(int index, IconData outlinedIcon, IconData filledIcon, String label) {
    final isSelected = _selectedIndex == index;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? filledIcon : outlinedIcon,
                key: ValueKey(isSelected),
                size: 22,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: isSelected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// Separate widget that only rebuilds when selected device changes
class _BottomSheetBuilder extends StatefulWidget {
  final int? selectedDeviceId;
  final Map<int, Device> devices;
  final Map<int, Position> positions;
  final VoidCallback? onClose;
  final ValueChanged<bool>? onRouteToggle;
  final bool showingRoute;
  final ValueChanged<List<Position>>? onRoutePositionsLoaded;
  final ValueChanged<double>? onSheetSizeChanged;
  final Function(Position position, Event event)? onEventTap;
  final Function(Position position, bool isFirst, String? label)? onPositionTap;
  final Function(List<Position> positions, Event startEvent, Event endEvent)? onStateSegmentTap;
  final List<Position>? highlightedSegmentPositions;

  const _BottomSheetBuilder({
    required this.selectedDeviceId,
    required this.devices,
    required this.positions,
    this.onClose,
    this.onRouteToggle,
    this.showingRoute = false,
    this.onRoutePositionsLoaded,
    this.onSheetSizeChanged,
    this.onEventTap,
    this.onPositionTap,
    this.onStateSegmentTap,
    this.highlightedSegmentPositions,
  });

  @override
  State<_BottomSheetBuilder> createState() => _BottomSheetBuilderState();
}

class _BottomSheetBuilderState extends State<_BottomSheetBuilder> {
  int? _lastDeviceId;
  int? _lastPositionId;
  bool? _lastShowingRoute;
  int? _lastHighlightedSegmentFirstId;
  Widget? _cachedSheet;

  @override
  Widget build(BuildContext context) {
    final selectedDeviceId = widget.selectedDeviceId;

    if (selectedDeviceId != null) {
      final device = widget.devices[selectedDeviceId];
      final position = widget.positions[selectedDeviceId];
      final currentPositionId = position?.id;
      final currentHighlightedFirstId = widget.highlightedSegmentPositions?.isNotEmpty == true
          ? widget.highlightedSegmentPositions!.first.id
          : null;

      // Check if device, position, or route view changed
      final deviceChanged = selectedDeviceId != _lastDeviceId;
      final positionChanged = currentPositionId != _lastPositionId;
      final routeViewChanged = widget.showingRoute != _lastShowingRoute;
      final highlightedSegmentChanged = currentHighlightedFirstId != _lastHighlightedSegmentFirstId;

      // Only rebuild if selected device's data or view actually changed
      if (deviceChanged || positionChanged || routeViewChanged || highlightedSegmentChanged || _cachedSheet == null) {
        _lastDeviceId = selectedDeviceId;
        _lastPositionId = currentPositionId;
        _lastShowingRoute = widget.showingRoute;
        _lastHighlightedSegmentFirstId = currentHighlightedFirstId;

        _cachedSheet = AnimatedSwitcher(
          duration: const Duration(milliseconds: 100),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: child,
            );
          },
          child: DeviceBottomSheet(
            key: ValueKey(selectedDeviceId),
            device: device!,
            position: position,
            onClose: widget.onClose,
            onRouteToggle: widget.onRouteToggle,
            showingRoute: widget.showingRoute,
            onRoutePositionsLoaded: widget.onRoutePositionsLoaded,
            onSheetSizeChanged: widget.onSheetSizeChanged,
            onEventTap: widget.onEventTap,
            onPositionTap: widget.onPositionTap,
            onStateSegmentTap: widget.onStateSegmentTap,
            highlightedSegmentPositions: widget.highlightedSegmentPositions,
          ),
        );
      }

      return _cachedSheet!;
    } else {
      _lastDeviceId = null;
      _lastPositionId = null;
      _lastShowingRoute = null;
      _lastHighlightedSegmentFirstId = null;
      _cachedSheet = null;
      return const SizedBox.shrink();
    }
  }
}
