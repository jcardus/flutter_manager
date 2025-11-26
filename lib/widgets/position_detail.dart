import 'package:flutter/material.dart';
import '../icons/Icons.dart';
import '../l10n/app_localizations.dart';
import '../models/device.dart';
import '../models/position.dart';

class PositionDetail extends StatelessWidget {
  const PositionDetail({super.key, required this.pos, required this.device, this.compact = false, this.showStatus = false});
  final Position pos;
  final Device device;
  final bool compact;
  final bool showStatus;

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

  String _formatIgnition(bool? ignition) {
    if (ignition == null) return 'Unknown';
    return ignition ? 'Ignition On' : 'Ignition Off';
  }

  String _formatAddress(String? address) {
    if (address == null || address.isEmpty) return 'Address not available';
    return address;
  }

  String _formatOdometer(double? odometer) {
    if (odometer == null) return 'N/A';
    final km = odometer / 1000; // Convert meters to kilometers
    return '${km.toStringAsFixed(1)} km';
  }


  @override
  Widget build(BuildContext context) {
    final ignition = pos.attributes?['ignition'] as bool?;
    final odometer = pos.attributes?['totalDistance'] as num?;

    if (compact) {
      return Column(
        children: [
          _InfoRow(
            icon: PlatformIcons.location,
            label: '',
            value: _formatAddress(pos.address),
            compact: true,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Expanded(
                child: _InfoRow(
                  icon: PlatformIcons.lastLocationTime,
                  label: '',
                  value: _formatLastUpdate(context, device.lastUpdate),
                  compact: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoRow(
                  icon: pos.speed >= 90 ? PlatformIcons.speedFast : pos.speed > 0 ? PlatformIcons.speedMedium : PlatformIcons.speedSlow,
                  label: '',
                  value: _formatSpeed(context, pos.speed),
                  compact: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoRow(
                  icon: PlatformIcons.odometer,
                  label: '',
                  value: _formatOdometer(odometer?.toDouble()),
                  compact: true,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        // Address row spanning full width
        _InfoRow(
          icon: PlatformIcons.location,
          label: '',
          value: _formatAddress(pos.address),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _InfoRow(
                icon: pos.speed >= 90 ? PlatformIcons.speedFast : pos.speed > 0 ? PlatformIcons.speedMedium : PlatformIcons.speedSlow,
                label: '',
                value: _formatSpeed(context, pos.speed),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoRow(
                icon: ignition != null && ignition ? PlatformIcons.ignitionOn : PlatformIcons.ignitionOff,
                label: '',
                value: _formatIgnition(ignition),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _InfoRow(
                icon: PlatformIcons.lastLocationTime,
                label: '',
                value: _formatLastUpdate(context, device.lastUpdate),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoRow(
                icon: PlatformIcons.odometer,
                label: '',
                value: _formatOdometer(odometer?.toDouble()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool compact;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: compact ? 14 : 20,
          color: theme.colorScheme.primary,
        ),
        SizedBox(width: compact ? 6 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label.isNotEmpty)
                Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (label.isNotEmpty) const SizedBox(height: 2),
              Text(
                value,
                style: (compact ? theme.textTheme.bodySmall : theme.textTheme.bodyLarge)?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
