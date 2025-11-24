import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/device.dart';
import '../models/position.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import 'common/handle_bar.dart';
import '../icons/Icons.dart' as platform_icons;

class DeviceRoute extends StatefulWidget {
  final Device device;
  final Position? position;
  final VoidCallback? onBack;
  final ValueChanged<List<Position>>? onRoutePositionsLoaded;
  final ValueChanged<Position>? onEventTap;

  const DeviceRoute({
    super.key,
    required this.device,
    required this.position,
    this.onBack,
    this.onRoutePositionsLoaded,
    this.onEventTap,
  });

  @override
  State<DeviceRoute> createState() => _DeviceRouteState();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, color: colors.primary, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat.yMMMMd().format(_selectedDate),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_drop_down, color: colors.onSurfaceVariant, size: 20),
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
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(vertical: 10),
              itemCount: _events.length,
              separatorBuilder: (context, index) => const SizedBox(height: 1),
              itemBuilder: (context, index) {
                final event = _events[index];
                final position = event.positionId != null
                    ? _positions.firstWhere(
                        (p) => p.id == event.positionId,
                        orElse: () => _positions.first,
                      )
                    : null;
                return _EventCard(
                  event: event,
                  position: position,
                  onTap: position != null
                      ? () => widget.onEventTap?.call(position)
                      : null,
                );
              },
            ),

        ],
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

  String _formatEventType(String type) {
    // Convert camelCase to Title Case with spaces
    final regex = RegExp(r'(?<=[a-z])(?=[A-Z])');
    return type.replaceAllMapped(regex, (match) => ' ').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getEventIcon(event.type),
                color: colors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatEventType(event.type),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.jm().format(event.eventTime.toLocal()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.location_on,
                color: colors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

