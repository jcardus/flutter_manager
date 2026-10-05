import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';
import '../models/notification_rule.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Loads the events the user is notified about from the Traccar server and
/// tracks which ones the user has seen on this phone.
///
/// An event is read once the user taps it or marks all as read. Read state
/// is a watermark id (everything up to it is read) plus the ids read
/// individually above it. Ids, not times: they grow in the order the server
/// stores events, while event times follow the device's clock and can
/// arrive late (buffered data, delayed pushes).
class NotificationsController extends ChangeNotifier with WidgetsBindingObserver {
  NotificationsController._() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final NotificationsController instance = NotificationsController._();

  static const _pageSpan = Duration(days: 1);
  static const _lastSeenKeyPrefix = 'notifications_last_seen_id_';
  static const _readIdsKeyPrefix = 'notifications_read_ids_';
  static const _maxReadIds = 1000;

  final ApiService _api = ApiService();

  List<int> _deviceIds = [];
  List<NotificationRule> _rules = [];
  List<Event> _events = [];
  DateTime? _loadedFrom;
  int? _lastSeenId;
  Set<int> _readIds = {};
  String? _userKey;
  bool _loading = false;
  bool _loadingOlder = false;
  bool _rulesLoaded = false;
  Object? _error;
  int _generation = 0;
  Timer? _refreshDebounce;

  List<Event> get events => _events;
  DateTime? get loadedFrom => _loadedFrom;
  /// Events up to this id are read. Null until the first load.
  int? get lastSeenId => _lastSeenId;
  bool get loading => _loading;
  bool get loadingOlder => _loadingOlder;
  Object? get error => _error;

  /// True once rules are known and the user has none that can fire.
  bool get notConfigured => _rulesLoaded && _types.isEmpty;

  int get unreadCount => _events.where(isUnread).length;

  bool isUnread(Event event) =>
      _lastSeenId != null &&
      event.id > _lastSeenId! &&
      !_readIds.contains(event.id);

  /// Alarm rules only fire for the alarms they list, so a rule without
  /// alarms never produces a notification.
  Set<String> get _alarms => _rules
      .where((r) => r.type == 'alarm')
      .expand((r) => r.alarms)
      .toSet();

  Set<String> get _types => _rules
      .map((r) => r.type)
      .where((t) => t != 'alarm' || _alarms.isNotEmpty)
      .toSet();

  bool _matches(Event event) {
    if (!_types.contains(event.type)) return false;
    if (event.type != 'alarm') return true;
    return _alarms.contains(event.attributes?['alarm']);
  }

  /// Called with the user's devices once they are known; reloads when the
  /// set changes.
  void setDevices(Iterable<int> deviceIds) {
    final ids = deviceIds.toList()..sort();
    if (_listEquals(ids, _deviceIds)) return;
    _deviceIds = ids;
    refresh();
  }

  /// Reloads the newest page, keeping how far back the user has scrolled.
  Future<void> refresh() async {
    if (_deviceIds.isEmpty) return;
    final generation = ++_generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _loadReadState();
      _rules = await _api.fetchNotificationRules();
      _rulesLoaded = true;
      final now = DateTime.now();
      final from = _loadedFrom != null && _loadedFrom!.isBefore(now.subtract(_pageSpan))
          ? _loadedFrom!
          : now.subtract(_pageSpan);
      final events = await _fetch(from, now);
      if (generation != _generation) return;
      _events = events;
      _loadedFrom = from;
      // First use on this phone: don't flag existing history as unread.
      if (_lastSeenId == null) await _saveReadState(lastSeenId: _maxId(events));
    } catch (e) {
      dev.log('Notifications load failed', name: 'Notifications', error: e);
      if (generation != _generation) return;
      _error = e;
    }
    _loading = false;
    notifyListeners();
  }

  /// Coalesces bursts of triggers (several pushes at once) into one reload.
  void refreshSoon() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(seconds: 2), refresh);
  }

  Future<void> loadOlder() async {
    final until = _loadedFrom;
    if (until == null || _loadingOlder || _loading) return;
    final generation = _generation;
    _loadingOlder = true;
    notifyListeners();
    try {
      final from = until.subtract(_pageSpan);
      final older = await _fetch(from, until);
      if (generation == _generation) {
        _events = _merge(_events, older);
        _loadedFrom = from;
      }
    } catch (e) {
      dev.log('Older notifications load failed', name: 'Notifications', error: e);
    }
    _loadingOlder = false;
    notifyListeners();
  }

  /// Adds events pushed over the live connection.
  void addLiveEvents(Iterable<Event> events) {
    final matching = events.where(_matches).toList();
    if (matching.isEmpty) return;
    _events = _merge(_events, matching);
    notifyListeners();
  }

  /// Works before read state has loaded (e.g. a push tapped at launch):
  /// the id is kept and merged in when it loads.
  Future<void> markRead(Event event) async {
    final watermark = _lastSeenId;
    if (watermark != null && event.id <= watermark) return;
    if (_readIds.contains(event.id)) return;
    _readIds = {..._readIds, event.id};
    notifyListeners();
    await _saveReadState();
  }

  /// Marks the events currently loaded as read. Events that arrive later
  /// stay unread.
  Future<void> markAllRead() async {
    if (_lastSeenId == null || _events.isEmpty) return;
    final maxId = _maxId(_events);
    if (maxId <= _lastSeenId!) return;
    // Updates state before its first await, so listeners see it now.
    final saving = _saveReadState(lastSeenId: maxId);
    notifyListeners();
    await saving;
  }

  @visibleForTesting
  void debugSetState({
    required List<Event> events,
    int? lastSeenId,
    Set<int>? readIds,
  }) {
    _events = events;
    _lastSeenId = lastSeenId;
    if (readIds != null) _readIds = readIds;
    notifyListeners();
  }

  /// Clears everything on logout so the next user starts fresh.
  void reset() {
    _generation++;
    _refreshDebounce?.cancel();
    _deviceIds = [];
    _rules = [];
    _rulesLoaded = false;
    _events = [];
    _loadedFrom = null;
    _lastSeenId = null;
    _readIds = {};
    _userKey = null;
    _loading = false;
    _loadingOlder = false;
    _error = null;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshSoon();
  }

  Future<List<Event>> _fetch(DateTime from, DateTime to) {
    return _api.fetchEventsForDevices(
      deviceIds: _deviceIds,
      types: _types,
      alarms: _alarms,
      from: from,
      to: to,
    );
  }

  /// Read status is kept per user on this phone.
  Future<void> _loadReadState() async {
    if (_userKey != null) return;
    final user = await AuthService().getUser();
    final userKey = '${user?['id'] ?? 'unknown'}';
    final prefs = await SharedPreferences.getInstance();
    _lastSeenId = prefs.getInt('$_lastSeenKeyPrefix$userKey');
    final stored = (prefs.getStringList('$_readIdsKeyPrefix$userKey') ?? [])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    final markedEarly = _readIds.difference(stored);
    _readIds = {...stored, ..._readIds};
    _userKey = userKey;
    if (markedEarly.isNotEmpty) await _saveReadState();
  }

  /// Saves read state, optionally raising the watermark. Ids at or below the
  /// watermark are dropped from the individual set, which keeps it small.
  Future<void> _saveReadState({int? lastSeenId}) async {
    if (lastSeenId != null) _lastSeenId = lastSeenId;
    final watermark = _lastSeenId;
    if (watermark != null) {
      _readIds = _readIds.where((id) => id > watermark).toSet();
    }
    if (_readIds.length > _maxReadIds) {
      // Never cleared by "mark all as read": keep only the newest.
      _readIds = (_readIds.toList()..sort()).reversed.take(_maxReadIds).toSet();
    }
    final userKey = _userKey;
    if (userKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (watermark != null) {
      await prefs.setInt('$_lastSeenKeyPrefix$userKey', watermark);
    }
    await prefs.setStringList(
      '$_readIdsKeyPrefix$userKey',
      _readIds.map((id) => '$id').toList(),
    );
  }

  static int _maxId(List<Event> events) =>
      events.fold(0, (max, e) => e.id > max ? e.id : max);

  static List<Event> _merge(List<Event> a, List<Event> b) {
    final byId = <int, Event>{for (final e in a) e.id: e};
    for (final e in b) {
      byId[e.id] = e;
    }
    return byId.values.toList()
      ..sort((x, y) => y.eventTime.compareTo(x.eventTime));
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
