import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../models/stop.dart';
import 'report_table.dart';

class StopsReport extends StatelessWidget {
  final List<Stop> stops;

  const StopsReport({super.key, required this.stops});

  static List<String> headers(AppLocalizations l10n) =>
      [l10n.startTime, l10n.endTime, l10n.duration, l10n.address];

  static List<List<String>> buildRows(List<Stop> stops) {
    final fmt = DateFormat('dd/MM HH:mm');
    return stops.map((s) {
      final dur = s.durationDuration;
      return [
        fmt.format(s.startTime.toLocal()),
        fmt.format(s.endTime.toLocal()),
        '${dur.inHours}h ${dur.inMinutes.remainder(60)}m',
        s.address ?? '',
      ];
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ReportTable(columns: headers(AppLocalizations.of(context)!), rows: buildRows(stops));
  }
}
