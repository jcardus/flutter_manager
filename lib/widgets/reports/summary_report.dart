import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/summary.dart';
import 'report_table.dart';

class SummaryReport extends StatelessWidget {
  final List<Summary> summaries;

  const SummaryReport({super.key, required this.summaries});

  static List<String> headers(AppLocalizations l10n) =>
      [l10n.device, l10n.distance, l10n.avgSpeed, l10n.maxSpeed, l10n.engineHours, l10n.fuel];

  static List<List<String>> buildRows(List<Summary> summaries) {
    return summaries.map((s) {
      final eh = s.engineHoursDuration;
      return [
        s.deviceName ?? '${s.deviceId}',
        '${s.distanceKm.toStringAsFixed(1)} km',
        '${s.averageSpeedKmh?.toStringAsFixed(0) ?? '-'} km/h',
        '${s.maxSpeedKmh?.toStringAsFixed(0) ?? '-'} km/h',
        '${eh.inHours}h ${eh.inMinutes.remainder(60)}m',
        s.spentFuel != null ? '${s.spentFuel!.toStringAsFixed(1)} L' : '-',
      ];
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ReportTable(columns: headers(AppLocalizations.of(context)!), rows: buildRows(summaries));
  }
}
