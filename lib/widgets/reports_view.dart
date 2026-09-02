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
  late DateTime _dateFrom = () {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return DateTime(yesterday.year, yesterday.month, yesterday.day, 0, 0);
  }();
  late DateTime _dateTo = () {
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day, 23, 59);
  }();
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
      final from = _dateFrom;
      final to = _dateTo;

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

  String _selectedDeviceLabel(AppLocalizations l10n) {
    if (_selectedDeviceId == null) {
      return _reportType == ReportType.summary ? l10n.allDevices : l10n.selectDevice;
    }
    return widget.devices[_selectedDeviceId]?.name ?? l10n.selectDevice;
  }

  Future<void> _pickDevice(List<Device> sortedDevices) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showModalBottomSheet<_DevicePick>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _DevicePickerSheet(
        devices: sortedDevices,
        showAllOption: _reportType == ReportType.summary,
        allLabel: l10n.allDevices,
        searchHint: l10n.searchDevices,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedDeviceId = selected.deviceId);
  }

  Future<void> _pickDateFrom() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dateFrom,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateFrom),
    );
    if (!mounted) return;
    setState(() => _dateFrom = DateTime(
      pickedDate.year, pickedDate.month, pickedDate.day,
      pickedTime?.hour ?? _dateFrom.hour, pickedTime?.minute ?? _dateFrom.minute,
    ));
  }

  Future<void> _pickDateTo() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dateTo,
      firstDate: _dateFrom,
      lastDate: DateTime.now(),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTo),
    );
    if (!mounted) return;
    setState(() => _dateTo = DateTime(
      pickedDate.year, pickedDate.month, pickedDate.day,
      pickedTime?.hour ?? _dateTo.hour, pickedTime?.minute ?? _dateTo.minute,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
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
            child: InkWell(
              onTap: () => _pickDevice(sortedDevices),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.selectDevice,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                ),
                child: Text(
                  _selectedDeviceLabel(l10n),
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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

class _DevicePick {
  final int? deviceId;
  const _DevicePick(this.deviceId);
}

class _DevicePickerSheet extends StatefulWidget {
  final List<Device> devices;
  final bool showAllOption;
  final String allLabel;
  final String searchHint;

  const _DevicePickerSheet({
    required this.devices,
    required this.showAllOption,
    required this.allLabel,
    required this.searchHint,
  });

  @override
  State<_DevicePickerSheet> createState() => _DevicePickerSheetState();
}

class _DevicePickerSheetState extends State<_DevicePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.devices
        : widget.devices.where((d) => d.name.toLowerCase().contains(q)).toList();
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.8;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _query = ''),
                        )
                      : null,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length + (widget.showAllOption && q.isEmpty ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (widget.showAllOption && q.isEmpty && i == 0) {
                    return ListTile(
                      leading: const Icon(Icons.select_all),
                      title: Text(widget.allLabel),
                      onTap: () => Navigator.of(ctx).pop(const _DevicePick(null)),
                    );
                  }
                  final idx = widget.showAllOption && q.isEmpty ? i - 1 : i;
                  final d = filtered[idx];
                  return ListTile(
                    title: Text(d.name, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.of(ctx).pop(_DevicePick(d.id)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
