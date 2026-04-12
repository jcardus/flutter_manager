import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../models/trip.dart';
import 'report_table.dart';

class TripsReport extends StatelessWidget {
  final List<Trip> trips;

  const TripsReport({super.key, required this.trips});

  static List<String> headers(AppLocalizations l10n) =>
      [l10n.startTime, l10n.endTime, l10n.distance, l10n.duration, l10n.avgSpeed, l10n.maxSpeed, l10n.from, l10n.to];

  static List<List<String>> buildRows(List<Trip> trips) {
    final fmt = DateFormat('dd/MM HH:mm');
    return trips.map((t) {
      final dur = t.durationDuration;
      return [
        fmt.format(t.startTime.toLocal()),
        fmt.format(t.endTime.toLocal()),
        '${t.distanceKm.toStringAsFixed(1)} km',
        '${dur.inHours}h ${dur.inMinutes.remainder(60)}m',
        '${t.averageSpeedKmh?.toStringAsFixed(0) ?? '-'} km/h',
        '${t.maxSpeedKmh?.toStringAsFixed(0) ?? '-'} km/h',
        t.startAddress ?? '',
        t.endAddress ?? '',
      ];
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ReportTable(columns: headers(AppLocalizations.of(context)!), rows: buildRows(trips));
  }
}
