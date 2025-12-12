import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/device.dart';
import '../models/position.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import 'common/handle_bar.dart';
import '../icons/icons.dart' as platform_icons;
import '../l10n/app_localizations.dart';

class DeviceRoute extends StatefulWidget {
  final Device device;
  final Position? position;
  final VoidCallback? onBack;
  final ValueChanged<List<Position>>? onRoutePositionsLoaded;
  final Function(Position position, Event event)? onEventTap;
  final Function(Position position, bool isFirst)? onPositionTap;
  final Function(List<Position> positions, Event startEvent, Event endEvent)? onStateSegmentTap;
  final List<Position>? highlightedSegmentPositions;

  const DeviceRoute({
    super.key,
    required this.device,
    required this.position,
    this.onBack,
    this.onRoutePositionsLoaded,
    this.onEventTap,
    this.onPositionTap,
    this.onStateSegmentTap,
    this.highlightedSegmentPositions,
  });

  @override
  State<DeviceRoute> createState() => _DeviceRouteState();
}

// Base class for list items
abstract class _ListItem {}

class _EventItem extends _ListItem {
  final Event event;
  final Position? position;

  _EventItem(this.event, this.position);
}

class _StateSeparator extends _ListItem {
  final String state;
  final Duration duration;
  final double? distance; // Distance in kilometers
  final double? maxSpeed; // Maximum speed in km/h
  final List<Position> positions;
  final Event startEvent;
  final Event endEvent;

  _StateSeparator(this.state, this.duration, this.distance, this.maxSpeed, this.positions, this.startEvent, this.endEvent);
}

class _PositionItem extends _ListItem {
  final Position position;
  final bool isFirst;

  _PositionItem(this.position, {this.isFirst = false});
}

class _DeviceRouteState extends State<DeviceRoute> {
  DateTime _selectedDate = DateTime.now();
  List<Event> _events = [];
  List<Position> _positions = [];
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
    });

    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final eventsFuture = _apiService.fetchEvents(
      deviceId: widget.device.id,
      from: startOfDay,
      to: endOfDay,
    );

    final positionsFuture = _apiService.fetchDevicePositions(
      deviceId: widget.device.id,
      from: startOfDay,
      to: endOfDay,
    );

    final results = await Future.wait([eventsFuture, positionsFuture]);
    final events = results[0] as List<Event>;
    final positions = results[1] as List<Position>;

    // Notify parent about route positions
    widget.onRoutePositionsLoaded?.call(positions);

    setState(() {
      _events = events;
      _positions = positions;
      _isLoading = false;
    });
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
    _loadEvents();
  }

  void _nextDay() {
    final nextDay = _selectedDate.add(const Duration(days: 1));
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    if (nextDay.difference(todayMidnight).inDays < 1) {
      setState(() {
        _selectedDate = nextDay;
      });
      _loadEvents();
    }
  }

  Future<void> _openDatePicker() async {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(todayMidnight) ? todayMidnight : _selectedDate,
      firstDate: DateTime(2020),
      lastDate: todayMidnight,
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadEvents();
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Haversine formula to calculate distance between two GPS coordinates
    const earthRadius = 6371.0; // Earth's radius in kilometers

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  double? _calculateTotalDistance(List<Position> positions) {
    if (positions.length < 2) {
      return null;
    }

    double totalDistance = 0.0;
    for (int i = 0; i < positions.length - 1; i++) {
      totalDistance += _calculateDistance(
        positions[i].latitude,
        positions[i].longitude,
        positions[i + 1].latitude,
        positions[i + 1].longitude,
      );
    }

    return totalDistance;
  }

  (String, List<Position>) _determineStateAndPositions(DateTime startTime, DateTime endTime) {
    // Find positions between the two events (inclusive)
    final positionsBetween = _positions.where((p) {
      final posTime = p.fixTime;
      return (posTime.isAfter(startTime) || posTime.isAtSameMomentAs(startTime)) &&
             (posTime.isBefore(endTime) || posTime.isAtSameMomentAs(endTime));
    }).toList();

    if (positionsBetween.isEmpty) {
      return ('stopped', []);
    }

    // Check if any position shows movement (speed > 0)
    final hasMovement = positionsBetween.any((p) => p.speed > 0);
    return (hasMovement ? 'moving' : 'stopped', positionsBetween);
  }

  List<_ListItem> _buildListItems() {
    final items = <_ListItem>[];

    // Add first position if available
    if (_positions.isNotEmpty) {
      items.add(_PositionItem(_positions.first, isFirst: true));

      // Add segment from first position to first event
      if (_events.isNotEmpty) {
        final firstEvent = _events.first;
        final firstPosition = _positions.first;
        final gap = firstEvent.eventTime.difference(firstPosition.fixTime);

        if (gap.inMinutes >= 2) {
          final (state, positions) = _determineStateAndPositions(firstPosition.fixTime, firstEvent.eventTime);
          final distance = state.toLowerCase() == 'moving' ? _calculateTotalDistance(positions) : null;
          final maxSpeed = state.toLowerCase() == 'moving' && positions.isNotEmpty
              ? positions.map((p) => p.speed * 1.852).reduce((a, b) => a > b ? a : b)
              : null;
          // Create a dummy event for the first position to use in the separator
          final startEvent = Event(
            id: -1,
            type: 'start',
            deviceId: firstPosition.deviceId,
            eventTime: firstPosition.fixTime,
            positionId: firstPosition.id,
            attributes: {},
          );
          items.add(_StateSeparator(state, gap, distance, maxSpeed, positions, startEvent, firstEvent));
        }
      }
    }

    for (int i = 0; i < _events.length; i++) {
      final event = _events[i];
      Position? position;
      if (event.positionId != null) {
        try {
          position = _positions.firstWhere((p) => p.id == event.positionId);
        } catch (e) {
          position = null;
        }
      }

      items.add(_EventItem(event, position));

      // Check if there's a next event and calculate time gap
      if (i < _events.length - 1) {
        final nextEvent = _events[i + 1];
        final gap = nextEvent.eventTime.difference(event.eventTime);

        // If gap is more than 2 minutes, add a separator
        if (gap.inMinutes >= 2) {
          final (state, positions) = _determineStateAndPositions(event.eventTime, nextEvent.eventTime);
          final distance = state.toLowerCase() == 'moving' ? _calculateTotalDistance(positions) : null;
          final maxSpeed = state.toLowerCase() == 'moving' && positions.isNotEmpty
              ? positions.map((p) => p.speed * 1.852).reduce((a, b) => a > b ? a : b)
              : null;
          items.add(_StateSeparator(state, gap, distance, maxSpeed, positions, event, nextEvent));
        }
      }
    }

    // Add segment from last event to last position
    if (_positions.isNotEmpty && _events.isNotEmpty) {
      final lastEvent = _events.last;
      final lastPosition = _positions.last;
      final gap = lastPosition.fixTime.difference(lastEvent.eventTime);

      if (gap.inMinutes >= 2) {
        final (state, positions) = _determineStateAndPositions(lastEvent.eventTime, lastPosition.fixTime);
        final distance = state.toLowerCase() == 'moving' ? _calculateTotalDistance(positions) : null;
        final maxSpeed = state.toLowerCase() == 'moving' && positions.isNotEmpty
            ? positions.map((p) => p.speed * 1.852).reduce((a, b) => a > b ? a : b)
            : null;
        // Create a dummy event for the last position to use in the separator
        final endEvent = Event(
          id: -2,
          type: 'end',
          deviceId: lastPosition.deviceId,
          eventTime: lastPosition.fixTime,
          positionId: lastPosition.id,
          attributes: {},
        );
        items.add(_StateSeparator(state, gap, distance, maxSpeed, positions, lastEvent, endEvent));
      }
    }

    // Add last position if available
    if (_positions.isNotEmpty) {
      items.add(_PositionItem(_positions.last, isFirst: false));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HandleBar(),
          // Date selector with navigation arrows
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _previousDay,
              ),
              Expanded(
                child: Material(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _openDatePicker,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, color: colors.primary, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat.yMMMMd(locale).format(_selectedDate),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 14
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_drop_down, color: colors.onSurfaceVariant, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _nextDay,
              ),
            ],
          ),
          // Events list
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Builder(
              builder: (context) {
                final items = _buildListItems();
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: Text(
                        'No events for ${DateFormat.yMd().format(_selectedDate)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(vertical: 10),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item is _EventItem) {
                      return _EventCard(
                        event: item.event,
                        position: item.position,
                        onTap: item.position != null
                            ? () => widget.onEventTap?.call(item.position!, item.event)
                            : null,
                      );
                    } else if (item is _StateSeparator) {
                      // Check if this segment is currently highlighted
                      final isHighlighted = widget.highlightedSegmentPositions != null &&
                          item.positions.isNotEmpty &&
                          widget.highlightedSegmentPositions!.isNotEmpty &&
                          item.positions.first.id == widget.highlightedSegmentPositions!.first.id;

                      return _StateRow(
                        state: item.state,
                        duration: item.duration,
                        distance: item.distance,
                        maxSpeed: item.maxSpeed,
                        positions: item.positions,
                        isHighlighted: isHighlighted,
                        onTap: item.state.toLowerCase() == 'moving' && item.positions.isNotEmpty
                            ? () {
                                // Toggle off if already highlighted, otherwise highlight this segment
                                if (isHighlighted) {
                                  widget.onStateSegmentTap?.call([], item.startEvent, item.endEvent);
                                } else {
                                  widget.onStateSegmentTap?.call(item.positions, item.startEvent, item.endEvent);
                                }
                              }
                            : null,
                      );
                    } else if (item is _PositionItem) {
                      return _PositionCard(
                        position: item.position,
                        isFirst: item.isFirst,
                        onTap: () => widget.onPositionTap?.call(item.position, item.isFirst),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                );
              },
            ),

        ],
      ),
    );
  }
}

class _StateRow extends StatelessWidget {
  final String state;
  final Duration duration;
  final double? distance; // Distance in kilometers
  final double? maxSpeed; // Maximum speed in km/h
  final List<Position> positions; // Positions for speed graph
  final bool isHighlighted;
  final VoidCallback? onTap;

  const _StateRow({
    required this.state,
    required this.duration,
    this.distance,
    this.maxSpeed,
    this.positions = const [],
    this.isHighlighted = false,
    this.onTap,
  });

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final localizations = AppLocalizations.of(context)!;
    final isMoving = state.toLowerCase() == 'moving';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: colors.outlineVariant,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(
                  painter: isMoving && positions.length > 1
                      ? SpeedGraphPainter(
                          positions: positions,
                          maxSpeed: maxSpeed ?? 0,
                          color: colors.tertiary.withValues(alpha: 0.5),
                        )
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isHighlighted
                          ? colors.primary.withValues(alpha: 0.3)
                          : isMoving
                              ? colors.primaryContainer.withValues(alpha: 0.5)
                              : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isHighlighted
                            ? colors.primary
                            : isMoving ? colors.primary.withValues(alpha: 0.3) : colors.outlineVariant,
                        width: isHighlighted ? 2 : 1,
                      ),
                      boxShadow: isHighlighted
                          ? [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isMoving ? platform_icons.PlatformIcons.play : Icons.stop_circle,
                          size: 14,
                          color: isHighlighted
                              ? Colors.white
                              : isMoving ? colors.primary : colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${isMoving ? localizations.stateMoving : localizations.stateStopped} - ${_formatDuration(duration)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isHighlighted
                                    ? Colors.white
                                    : isMoving ? colors.primary : colors.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                                shadows: isMoving && !isHighlighted ? [
                                  const Shadow(color: Colors.white, blurRadius: 3),
                                  const Shadow(color: Colors.white, blurRadius: 3),
                                  const Shadow(color: Colors.white, blurRadius: 3),
                                ] : isHighlighted ? [
                                  Shadow(color: colors.primary.withValues(alpha: 0.8), blurRadius: 4),
                                  Shadow(color: colors.primary.withValues(alpha: 0.8), blurRadius: 4),
                                ] : null,
                              ),
                            ),
                            if (distance != null || maxSpeed != null)
                              Text(
                                '${distance != null ? '${distance!.toStringAsFixed(1)} km' : ''}${distance != null && maxSpeed != null ? ' · ' : ''}${maxSpeed != null ? 'max: ${maxSpeed!.toStringAsFixed(0)} km/h' : ''}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isHighlighted
                                      ? Colors.white
                                      : isMoving ? colors.primary : colors.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  shadows: isMoving && !isHighlighted ? [
                                    const Shadow(color: Colors.white, blurRadius: 3),
                                    const Shadow(color: Colors.white, blurRadius: 3),
                                    const Shadow(color: Colors.white, blurRadius: 3),
                                  ] : isHighlighted ? [
                                    Shadow(color: colors.primary.withValues(alpha: 0.8), blurRadius: 4),
                                    Shadow(color: colors.primary.withValues(alpha: 0.8), blurRadius: 4),
                                  ] : null,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: colors.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  final Position position;
  final bool isFirst;
  final VoidCallback? onTap;

  const _PositionCard({
    required this.position,
    required this.isFirst,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final localizations = AppLocalizations.of(context)!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(
              isFirst ? Icons.flag : Icons.flag_outlined,
              color: isFirst ? colors.tertiary : colors.error,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isFirst ? localizations.positionStart : localizations.positionEnd,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        DateFormat.jm(locale).format(position.fixTime.toLocal()),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (position.address != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      position.address!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final Position? position;
  final VoidCallback? onTap;

  const _EventCard({
    required this.event,
    this.position,
    this.onTap,
  });

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

  String _formatEventType(String type, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    switch (type.toLowerCase()) {
      case 'ignitionon':
        return localizations.eventIgnitionOn;
      case 'ignitionoff':
        return localizations.eventIgnitionOff;
      case 'geofenceenter':
        return localizations.eventGeofenceEnter;
      case 'geofenceexit':
        return localizations.eventGeofenceExit;
      case 'alarm':
        return localizations.eventAlarm;
      case 'commandresult':
        return localizations.eventCommandResult;
      case 'devicemoving':
        return localizations.eventDeviceMoving;
      case 'devicestopped':
        return localizations.eventDeviceStopped;
      case 'deviceoverspeed':
        return localizations.eventDeviceOverspeed;
      default:
        // Fallback: Convert camelCase to Title Case with spaces
        final regex = RegExp(r'(?<=[a-z])(?=[A-Z])');
        return type.replaceAllMapped(regex, (match) => ' ').toUpperCase();
    }
  }

  Color _getEventColor(String type, ColorScheme colors) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final iconColor = _getEventColor(event.displayType, colors);
    final locale = Localizations.localeOf(context).toString();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Container(
              // padding: const EdgeInsets.all(8),
              child: Icon(
                _getEventIcon(event.displayType),
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatEventType(event.displayType, context),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        DateFormat.jm(locale).format(event.eventTime.toLocal()),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (position?.address != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      position!.address!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SpeedGraphPainter extends CustomPainter {
  final List<Position> positions;
  final double maxSpeed;
  final Color color;

  SpeedGraphPainter({
    required this.positions,
    required this.maxSpeed,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2 || maxSpeed <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    // Convert speeds from knots to km/h
    final speeds = positions.map((p) => p.speed * 1.852).toList();

    // Find the actual max speed from the data
    final actualMaxSpeed = speeds.reduce((a, b) => a > b ? a : b);

    // Use the actual max if it's greater than 0, otherwise use the provided maxSpeed
    final normalizer = actualMaxSpeed > 0 ? actualMaxSpeed : maxSpeed;

    if (normalizer <= 0) return;

    // Start path from bottom-left
    path.moveTo(0, size.height);

    // Draw the speed graph
    for (int i = 0; i < speeds.length; i++) {
      final x = (i / (speeds.length - 1)) * size.width;
      final normalizedSpeed = speeds[i] / normalizer;
      final y = size.height - (normalizedSpeed * size.height);

      if (i == 0) {
        path.lineTo(x, y);
      } else {
        // Use quadratic bezier curves for smooth transitions
        final prevX = ((i - 1) / (speeds.length - 1)) * size.width;
        final prevNormalizedSpeed = speeds[i - 1] / normalizer;
        final prevY = size.height - (prevNormalizedSpeed * size.height);

        final controlX = (prevX + x) / 2;
        path.quadraticBezierTo(controlX, prevY, x, y);
      }
    }

    // Close the path along the bottom
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(SpeedGraphPainter oldDelegate) {
    return oldDelegate.positions != positions ||
        oldDelegate.maxSpeed != maxSpeed ||
        oldDelegate.color != color;
  }
}

