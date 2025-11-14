import 'package:flutter/material.dart';
import 'package:manager/l10n/app_localizations.dart';
import '../models/device.dart';
import '../models/position.dart';
import '../utils/constants.dart';
import '../utils/google_url_signer.dart';

class DeviceBottomSheet extends StatefulWidget {
  final Device device;
  final Position? position;
  final VoidCallback? onClose;

  const DeviceBottomSheet({
    super.key,
    required this.device,
    this.position,
    this.onClose,
  });

  @override
  State<DeviceBottomSheet> createState() => _DeviceBottomSheetState();
}

class _DeviceBottomSheetState extends State<DeviceBottomSheet> {
  double _sheetHeight = 0.5; // Start at 50% of screen height
  final double _minHeight = 0.25;
  final double _maxHeight = 0.75;

  String _formatSpeed(BuildContext context, double? speed) {
    final l10n = AppLocalizations.of(context)!;
    if (speed == null) return l10n.speedNotAvailable;
    final kmh = speed * 1.852;
    return l10n.speedKmh(kmh.round());
  }

  String _formatLastUpdate(BuildContext context, DateTime? lastUpdate) {
    final l10n = AppLocalizations.of(context)!;
    if (lastUpdate == null) return l10n.never;

    final now = DateTime.now();
    final difference = now.difference(lastUpdate);

    if (difference.inMinutes < 1) {
      return l10n.justNow;
    } else if (difference.inMinutes < 60) {
      return l10n.minutesAgo(difference.inMinutes);
    } else if (difference.inHours < 24) {
      return l10n.hoursAgo(difference.inHours);
    } else {
      return l10n.daysAgo(difference.inDays);
    }
  }

  Color _getStatusColor(BuildContext context) {
    switch (widget.device.status?.toLowerCase()) {
      case 'online':
        return Theme.of(context).colorScheme.tertiary;
      case 'offline':
        return Theme.of(context).colorScheme.error;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  IconData _getDeviceIcon() {
    switch (widget.device.category?.toLowerCase()) {
      case 'car':
      case 'vehicle':
        return Icons.directions_car;
      case 'truck':
        return Icons.local_shipping;
      case 'bus':
        return Icons.directions_bus;
      case 'motorcycle':
        return Icons.two_wheeler;
      case 'bicycle':
        return Icons.pedal_bike;
      case 'person':
        return Icons.person;
      default:
        return Icons.navigation;
    }
  }

  String _getStreetViewUrl(double latitude, double longitude, double heading) {
    final size = '300x200';
    final fov = '90'; // Field of view
    final pitch = '0'; // Camera pitch (0 = horizontal)

    final baseUrl = 'https://maps.googleapis.com/maps/api/streetview?'
        'size=$size'
        '&location=$latitude,$longitude'
        '&heading=${heading.toStringAsFixed(0)}'
        '&fov=$fov'
        '&pitch=$pitch';

    return GoogleUrlSigner.signUrl(
      baseUrl,
      googleMapsSigningSecret,
      clientId: googleMapsClientId,
    );
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      final screenHeight = MediaQuery.of(context).size.height;
      // Convert drag delta to height percentage (negative because dragging up increases height)
      final delta = -details.delta.dy / screenHeight;
      _sheetHeight = (_sheetHeight + delta).clamp(_minHeight, _maxHeight);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusColor = _getStatusColor(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onVerticalDragUpdate: _onVerticalDragUpdate,
      child: Container(
        height: screenHeight * _sheetHeight,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Device Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: statusColor.withValues(alpha: 0.2),
                    child: Icon(_getDeviceIcon(), color: statusColor, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.device.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.circle, size: 10, color: statusColor),
                            const SizedBox(width: 6),
                            Text(
                              widget.device.status?.toUpperCase() ?? l10n.statusUnknown,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            // Content (no scrolling)
            if (widget.position != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      _getStreetViewUrl(widget.position!.latitude, widget.position!.longitude, widget.position!.course),
                      fit: BoxFit.fitWidth,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.streetview,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Street View unavailable',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              // Device Info
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.speed,
                      label: 'Speed',
                      value: _formatSpeed(context, widget.position?.speed),
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.navigation,
                      label: 'Course',
                      value: '${widget.position?.course.toStringAsFixed(0)}°',
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.access_time,
                      label: 'Last Update',
                      value: _formatLastUpdate(context, widget.device.lastUpdate),
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.location_on,
                      label: 'Coordinates',
                      value: '${widget.position?.latitude.toStringAsFixed(6)}, ${widget.position?.longitude.toStringAsFixed(6)}',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
