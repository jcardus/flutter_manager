import 'package:flutter/material.dart';
import 'package:manager/widgets/street_view.dart';

import '../l10n/app_localizations.dart';
import '../models/device.dart';
import '../models/position.dart';

class DeviceDetail extends StatelessWidget {
  final Device device;
  final Position? position;
  final VoidCallback? onClose;

  const DeviceDetail({
    super.key,
    required this.device,
    required this.position,
    required this.onClose
  });

  String _formatSpeed(BuildContext context, double? speed) {
    final l10n = AppLocalizations.of(context)!;
    if (speed == null) return l10n.speedNotAvailable;
    final kmh = speed * 1.852;
    return l10n.speedKmh(kmh.round());
  }

  String _formatLastUpdate(BuildContext context, DateTime? lastUpdate) {
    final l10n = AppLocalizations.of(context)!;
    if (lastUpdate == null) return l10n.never;

    final difference = DateTime.now().difference(lastUpdate);

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
    switch (device.status?.toLowerCase()) {
      case 'online':
        return Theme.of(context).colorScheme.tertiary;
      case 'offline':
        return Theme.of(context).colorScheme.error;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  IconData _getDeviceIcon() {
    switch (device.category?.toLowerCase()) {
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


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final l10n = AppLocalizations.of(context)!;
    final statusColor = _getStatusColor(context);
    final pos = position;

    return
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 0),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 50,
              height: 2,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: statusColor.withValues(alpha: 0.2),
                  child: Icon(
                    _getDeviceIcon(),
                    color: statusColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 10, color: statusColor),
                          const SizedBox(width: 6),
                          Text(
                            device.status?.toUpperCase() ??
                                l10n.statusUnknown,
                            style: textTheme.bodyMedium?.copyWith(
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
                    onPressed: onClose
                ),
              ],
            ),
            if (pos != null) ...[
              // Street View
              StreetView(position:position),
              // Info rows
              _InfoRow(
                icon: Icons.speed,
                label: 'Speed',
                value: _formatSpeed(context, pos.speed),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.navigation,
                label: 'Course',
                value: '${pos.course.toStringAsFixed(0)}°',
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.access_time,
                label: 'Last Update',
                value: _formatLastUpdate(context, device.lastUpdate),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.location_on,
                label: 'Coordinates',
                value:
                '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
              ),
            ]],
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
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
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
