import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../models/position.dart';
import 'report_table.dart';

class RouteReport extends StatelessWidget {
  final List<Position> positions;

  const RouteReport({super.key, required this.positions});

  static List<String> headers(AppLocalizations l10n) =>
      [l10n.time, l10n.speed, l10n.address, 'Lat', 'Lon'];

  static List<List<String>> buildRows(List<Position> positions) {
    final fmt = DateFormat('dd/MM HH:mm:ss');
    return positions.map((p) => [
      fmt.format(p.fixTime.toLocal()),
      '${(p.speed * 1.852).toStringAsFixed(0)} km/h',
      p.address ?? '',
      p.latitude.toStringAsFixed(5),
      p.longitude.toStringAsFixed(5),
    ]).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ReportTable(columns: headers(AppLocalizations.of(context)!), rows: buildRows(positions));
  }
}
