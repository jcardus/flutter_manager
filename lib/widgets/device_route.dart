import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/device.dart';
import '../models/position.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import 'common/handle_bar.dart';
import '../icons/Icons.dart' as platform_icons;
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
  final List<Position> positions;
  final Event startEvent;
  final Event endEvent;

  _StateSeparator(this.state, this.duration, this.distance, this.positions, this.startEvent, this.endEvent);
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
    final tomorrow = _selectedDate.add(const Duration(days: 1));
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);

    if (!tomorrow.isAfter(todayMidnight)) {
      setState(() {
        _selectedDate = tomorrow;
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
    // Find positions between the two events
    final positionsBetween = _positions.where((p) {
      final posTime = p.deviceTime;
      return posTime.isAfter(startTime) && posTime.isBefore(endTime);
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
          items.add(_StateSeparator(state, gap, distance, positions, event, nextEvent));
        }
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
          else if (_events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Text(
                  'No events for ${DateFormat.yMd().format(_selectedDate)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            Builder(
              builder: (context) {
                final items = _buildListItems();
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
  final bool isHighlighted;
  final VoidCallback? onTap;

  const _StateRow({
    required this.state,
    required this.duration,
    this.distance,
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? colors.primary.withValues(alpha: 0.2)
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
                      color: isMoving ? colors.primary : colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${isMoving ? localizations.stateMoving : localizations.stateStopped} - ${_formatDuration(duration)}${distance != null ? ' · ${distance!.toStringAsFixed(1)} km' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isMoving ? colors.primary : colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
                        DateFormat.jm(locale).format(position.deviceTime.toLocal()),
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

