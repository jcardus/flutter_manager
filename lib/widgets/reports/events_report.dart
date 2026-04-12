import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../models/event.dart';
import 'report_table.dart';

class EventsReport extends StatelessWidget {
  final List<Event> events;

  const EventsReport({super.key, required this.events});

  static List<String> headers(AppLocalizations l10n) =>
      [l10n.time, l10n.eventType];

  static List<List<String>> buildRows(List<Event> events) {
    final fmt = DateFormat('dd/MM HH:mm');
    return events.map((e) => [
      fmt.format(e.eventTime.toLocal()),
      e.displayType,
    ]).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ReportTable(columns: headers(AppLocalizations.of(context)!), rows: buildRows(events));
  }
}
