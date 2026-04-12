import 'package:flutter/material.dart';

class ReportTable extends StatelessWidget {
  final List<String> columns;
  final List<List<String>> rows;

  const ReportTable({
    super.key,
    required this.columns,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        headingRowHeight: 40,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 52,
        columns: columns
            .map((c) => DataColumn(
                  label: Text(c,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                ))
            .toList(),
        rows: rows
            .map((row) => DataRow(
                  cells: row
                      .map((cell) => DataCell(
                            Text(cell, style: const TextStyle(fontSize: 12)),
                          ))
                      .toList(),
                ))
            .toList(),
      ),
    );
  }
}
