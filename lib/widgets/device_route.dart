import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/device.dart';
import '../models/position.dart';
import '../models/event.dart';
import '../models/trip.dart';
import '../models/stop.dart';
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
  final Function(Position position, bool isFirst, String? label)? onPositionTap;
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
  final String? label;

  _PositionItem(this.position, {this.isFirst = false, this.label});
}

class _DeviceRouteState extends State<DeviceRoute> {
  DateTime _selectedDate = DateTime.now();
  List<Trip> _trips = [];
  List<Stop> _stops = [];
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

    final tripsFuture = _apiService.fetchTrips(
      deviceId: widget.device.id,
      from: startOfDay,
      to: endOfDay,
    );

    final stopsFuture = _apiService.fetchStops(
      deviceId: widget.device.id,
      from: startOfDay,
      to: endOfDay,
    );

    final positionsFuture = _apiService.fetchDevicePositions(
      deviceId: widget.device.id,
      from: startOfDay,
      to: endOfDay,
    );

    final results = await Future.wait([tripsFuture, stopsFuture, positionsFuture]);
    final trips = results[0] as List<Trip>;
    final stops = results[1] as List<Stop>;
    final positions = results[2] as List<Position>;

    // Notify parent about route positions
    widget.onRoutePositionsLoaded?.call(positions);

    setState(() {
      _trips = trips;
      _stops = stops;
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

  List<_ListItem> _buildListItems() {
    final items = <_ListItem>[];

    if (_positions.isEmpty) return items;

    // Add first position
    items.add(_PositionItem(_positions.first, isFirst: true));

    // Combine trips and stops into a sorted list
    final combined = <dynamic>[..._trips, ..._stops];
    combined.sort((a, b) => a.startTime.compareTo(b.startTime));

    // Process each trip/stop
    for (final item in combined) {
      if (item is Trip) {
        // Find start position for this trip
        Position? startPosition;

        if (item.startPositionId != null) {
          try {
            startPosition = _positions.firstWhere((p) => p.id == item.startPositionId);
          } catch (e) {
            // Position not found, use closest by time
            startPosition = _positions.where((p) =>
              p.fixTime.difference(item.startTime).abs().inSeconds < 60
            ).firstOrNull;
          }
        }

        // Add start position marker
        if (startPosition != null) {
          items.add(_PositionItem(startPosition, isFirst: false, label: 'Movement Start'));
        }

        // Get positions for this trip
        final tripPositions = _positions.where((p) {
          return !p.fixTime.isBefore(item.startTime) &&
                 !p.fixTime.isAfter(item.endTime);
        }).toList();

        // Create dummy events for trip start/end
        final startEvent = Event(
          id: -1,
          type: 'tripStart',
          deviceId: widget.device.id,
          eventTime: item.startTime,
          positionId: item.startPositionId,
          attributes: {},
        );

        final endEvent = Event(
          id: -2,
          type: 'tripEnd',
          deviceId: widget.device.id,
          eventTime: item.endTime,
          positionId: item.endPositionId,
          attributes: {},
        );

        items.add(_StateSeparator(
          'moving',
          item.durationDuration,
          item.distanceKm,
          item.maxSpeedKmh,
          tripPositions,
          startEvent,
          endEvent,
        ));
      } else if (item is Stop) {
        // Find position for this stop
        Position? stopPosition;

        if (item.positionId != null) {
          try {
            stopPosition = _positions.firstWhere((p) => p.id == item.positionId);
          } catch (e) {
            // Position not found, use closest by time
            stopPosition = _positions.where((p) =>
              p.fixTime.difference(item.startTime).abs().inSeconds < 60
            ).firstOrNull;
          }
        }

        // Add stop position marker
        if (stopPosition != null) {
          items.add(_PositionItem(stopPosition, isFirst: false, label: 'Stop'));
        }

        // Create dummy events for stop start/end
        final startEvent = Event(
          id: -3,
          type: 'stopStart',
          deviceId: widget.device.id,
          eventTime: item.startTime,
          positionId: item.positionId,
          attributes: {},
        );

        final endEvent = Event(
          id: -4,
          type: 'stopEnd',
          deviceId: widget.device.id,
          eventTime: item.endTime,
          positionId: item.positionId,
          attributes: {},
        );

        items.add(_StateSeparator(
          'stopped',
          item.durationDuration,
          null, // No distance for stops
          null, // No speed for stops
          [], // No positions for stops
          startEvent,
          endEvent,
        ));
      }
    }

    // Add last position (only if not already added)
    if (_positions.isNotEmpty) {
      final lastPosition = _positions.last;
      final lastItem = items.lastOrNull;

      // Check if last item is already this position
      final shouldAddLast = lastItem is! _PositionItem ||
                           lastItem.position.id != lastPosition.id;

      if (shouldAddLast) {
        items.add(_PositionItem(lastPosition, isFirst: false));
      }
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
                    if (item is _StateSeparator) {
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
                        label: item.label,
                        onTap: () => widget.onPositionTap?.call(item.position, item.isFirst, item.label),
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
  final String? label;
  final VoidCallback? onTap;

  const _PositionCard({
    required this.position,
    required this.isFirst,
    this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();

    // Determine icon and color based on label
    IconData icon;
    Color iconColor;

    if (label == 'Movement Start') {
      icon = platform_icons.PlatformIcons.play;
      iconColor = colors.tertiary;
    } else if (label == 'Stop') {
      icon = Icons.stop_circle;
      iconColor = colors.error;
    } else if (isFirst) {
      icon = Icons.flag;
      iconColor = colors.tertiary;
    } else {
      icon = Icons.flag_outlined;
      iconColor = colors.error;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
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

