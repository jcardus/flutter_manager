import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/device.dart';
import '../models/trip.dart';
import '../models/stop.dart';
import '../models/event.dart';
import '../models/position.dart';
import '../models/summary.dart';
import '../services/api_service.dart';
import '../services/report_export_service.dart';
import 'reports/trips_report.dart';
import 'reports/stops_report.dart';
import 'reports/events_report.dart';
import 'reports/summary_report.dart';
import 'reports/activity_report.dart';
import 'reports/route_report.dart';

enum ReportType { trips, stops, events, summary, activity, route }

class ReportsView extends StatefulWidget {
  final Map<int, Device> devices;
  final VoidCallback? onBack;

  const ReportsView({super.key, required this.devices, this.onBack});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  ReportType _reportType = ReportType.trips;
  int? _selectedDeviceId;
  DateTime _dateFrom = DateTime.now().subtract(const Duration(days: 1));
  DateTime _dateTo = DateTime.now();
  bool _isLoading = false;

  // Report data
  List<Trip> _trips = [];
  List<Stop> _stops = [];
  List<Event> _events = [];
  List<Position> _positions = [];
  List<Summary> _summaries = [];
  bool _hasData = false;

  final _apiService = ApiService();

  String _reportTypeLabel(ReportType type, AppLocalizations l10n) {
    switch (type) {
      case ReportType.trips: return l10n.reportTrips;
      case ReportType.stops: return l10n.reportStops;
      case ReportType.events: return l10n.reportEvents;
      case ReportType.summary: return l10n.reportSummary;
      case ReportType.activity: return l10n.reportActivity;
      case ReportType.route: return l10n.reportRoute;
    }
  }

  Future<void> _generate() async {
    if (_reportType != ReportType.summary && _selectedDeviceId == null) return;

    setState(() {
      _isLoading = true;
      _hasData = false;
    });

    try {
      final from = DateTime(_dateFrom.year, _dateFrom.month, _dateFrom.day);
      final to = DateTime(_dateTo.year, _dateTo.month, _dateTo.day, 23, 59, 59);

      switch (_reportType) {
        case ReportType.trips:
          _trips = await _apiService.fetchTrips(
            deviceId: _selectedDeviceId!, from: from, to: to);
          break;
        case ReportType.stops:
          _stops = await _apiService.fetchStops(
            deviceId: _selectedDeviceId!, from: from, to: to);
          break;
        case ReportType.events:
          _events = await _apiService.fetchEvents(
            deviceId: _selectedDeviceId!, from: from, to: to);
          break;
        case ReportType.summary:
          final ids = _selectedDeviceId != null
              ? [_selectedDeviceId!]
              : widget.devices.keys.toList();
          _summaries = await _apiService.fetchSummary(
            deviceIds: ids, from: from, to: to);
          break;
        case ReportType.activity:
          final results = await Future.wait([
            _apiService.fetchTrips(deviceId: _selectedDeviceId!, from: from, to: to),
            _apiService.fetchStops(deviceId: _selectedDeviceId!, from: from, to: to),
          ]);
          _trips = results[0] as List<Trip>;
          _stops = results[1] as List<Stop>;
          break;
        case ReportType.route:
          _positions = await _apiService.fetchDevicePositions(
            deviceId: _selectedDeviceId!, from: from, to: to);
          break;
      }
      _hasData = true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading report')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _currentHeaders(AppLocalizations l10n) {
    switch (_reportType) {
      case ReportType.trips: return TripsReport.headers(l10n);
      case ReportType.stops: return StopsReport.headers(l10n);
      case ReportType.events: return EventsReport.headers(l10n);
      case ReportType.summary: return SummaryReport.headers(l10n);
      case ReportType.activity: return ActivityReport.headers(l10n);
      case ReportType.route: return RouteReport.headers(l10n);
    }
  }

  List<List<String>> get _currentRows {
    switch (_reportType) {
      case ReportType.trips: return TripsReport.buildRows(_trips);
      case ReportType.stops: return StopsReport.buildRows(_stops);
      case ReportType.events: return EventsReport.buildRows(_events);
      case ReportType.summary: return SummaryReport.buildRows(_summaries);
      case ReportType.activity: return ActivityReport.buildRows(_trips, _stops);
      case ReportType.route: return RouteReport.buildRows(_positions);
    }
  }

  Future<void> _pickDateFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateFrom = picked);
  }

  Future<void> _pickDateTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTo,
      firstDate: _dateFrom,
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateTo = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('dd/MM/yyyy');
    final sortedDevices = widget.devices.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return SafeArea(
      child: Column(
        children: [
          // Header with back button
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBack,
                ),
                Text(l10n.reports,
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),

          // Report type chips
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ReportType.values.map((type) {
                  final selected = _reportType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_reportTypeLabel(type, l10n)),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _reportType = type;
                        _hasData = false;
                      }),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Device selector
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: DropdownButtonFormField<int?>(
              initialValue: _selectedDeviceId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.selectDevice,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              items: [
                if (_reportType == ReportType.summary)
                  DropdownMenuItem<int?>(value: null, child: Text(l10n.allDevices)),
                ...sortedDevices.map((d) =>
                  DropdownMenuItem<int?>(value: d.id, child: Text(d.name, overflow: TextOverflow.ellipsis)),
                ),
              ],
              onChanged: (v) => setState(() => _selectedDeviceId = v),
            ),
          ),

          // Date range + Generate
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDateFrom,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.from,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      child: Text(dateFmt.format(_dateFrom), style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _pickDateTo,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.to,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      child: Text(dateFmt.format(_dateTo), style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isLoading ? null : _generate,
                  child: Text(l10n.generate),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_hasData
                    ? Center(
                        child: Text(l10n.noData,
                            style: TextStyle(color: colors.onSurfaceVariant)))
                    : _currentRows.isEmpty
                        ? Center(
                            child: Text(l10n.noData,
                                style: TextStyle(color: colors.onSurfaceVariant)))
                        : SingleChildScrollView(
                            child: _buildReport(),
                          ),
          ),

          // Export buttons
          if (_hasData && _currentRows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => ReportExportService.exportCsv(
                      fileName: 'report_${_reportType.name}',
                      headers: _currentHeaders(l10n),
                      rows: _currentRows,
                      context: context,
                    ),
                    icon: const Icon(Icons.table_chart, size: 18),
                    label: Text(l10n.exportCsv),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => ReportExportService.exportPdf(
                      title: _reportTypeLabel(_reportType, l10n),
                      headers: _currentHeaders(l10n),
                      rows: _currentRows,
                      context: context,
                    ),
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: Text(l10n.exportPdf),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReport() {
    switch (_reportType) {
      case ReportType.trips: return TripsReport(trips: _trips);
      case ReportType.stops: return StopsReport(stops: _stops);
      case ReportType.events: return EventsReport(events: _events);
      case ReportType.summary: return SummaryReport(summaries: _summaries);
      case ReportType.activity: return ActivityReport(trips: _trips, stops: _stops);
      case ReportType.route: return RouteReport(positions: _positions);
    }
  }
}
