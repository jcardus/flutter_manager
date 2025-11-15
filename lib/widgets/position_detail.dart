import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/device.dart';
import '../models/position.dart';

class PositionDetail extends StatelessWidget {
  const PositionDetail({super.key, required this.pos, required this.device});
  final Position pos;
  final Device device;

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


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
      ],
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
