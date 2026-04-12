import 'dart:io';
import 'package:csv/csv.dart' show CsvEncoder;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';

class ReportExportService {
  static Future<void> exportCsv({
    required String fileName,
    required List<String> headers,
    required List<List<String>> rows,
    required BuildContext context,
  }) async {
    final csvData = const CsvEncoder().convert([headers, ...rows]);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName.csv');
    await file.writeAsString(csvData);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.reportExported)),
      );
    }
  }

  static Future<void> exportPdf({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    required BuildContext context,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          pw.Header(level: 0, text: title),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 7),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellPadding: const pw.EdgeInsets.all(3),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/report_$title.pdf');
    await file.writeAsBytes(await pdf.save());
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.reportExported)),
      );
    }
  }
}
