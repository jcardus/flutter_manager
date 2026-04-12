import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/trip.dart';
import '../../models/stop.dart';
import 'report_table.dart';

class ActivityReport extends StatelessWidget {
  final List<Trip> trips;
  final List<Stop> stops;

  const ActivityReport({super.key, required this.trips, required this.stops});

  static List<String> headers(AppLocalizations l10n) =>
      [l10n.movingTime, l10n.stoppedTime, l10n.distance, l10n.reportTrips, l10n.reportStops];

  static List<List<String>> buildRows(List<Trip> trips, List<Stop> stops) {
    final movingMs = trips.fold<int>(0, (sum, t) => sum + t.duration);
    final stoppedMs = stops.fold<int>(0, (sum, s) => sum + s.duration);
    final distanceKm = trips.fold<double>(0, (sum, t) => sum + t.distanceKm);
    final moving = Duration(milliseconds: movingMs);
    final stopped = Duration(milliseconds: stoppedMs);

    return [
      [
        '${moving.inHours}h ${moving.inMinutes.remainder(60)}m',
        '${stopped.inHours}h ${stopped.inMinutes.remainder(60)}m',
        '${distanceKm.toStringAsFixed(1)} km',
        '${trips.length}',
        '${stops.length}',
      ]
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ReportTable(columns: headers(AppLocalizations.of(context)!), rows: buildRows(trips, stops));
  }
}
