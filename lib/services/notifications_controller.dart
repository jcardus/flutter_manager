import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';
import '../models/notification_rule.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Loads the events the user is notified about from the Traccar server and
/// tracks which ones are new since the list was last opened on this phone.
class NotificationsController extends ChangeNotifier with WidgetsBindingObserver {
  NotificationsController._() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final NotificationsController instance = NotificationsController._();

  static const _pageSpan = Duration(days: 1);
  static const _lastSeenKeyPrefix = 'notifications_last_seen_';

  final ApiService _api = ApiService();

  List<int> _deviceIds = [];
  List<NotificationRule> _rules = [];
  List<Event> _events = [];
  DateTime? _loadedFrom;
  DateTime? _lastSeen;
  String? _lastSeenKey;
  bool _loading = false;
  bool _loadingOlder = false;
  bool _rulesLoaded = false;
  Object? _error;
  int _generation = 0;
  Timer? _refreshDebounce;

  List<Event> get events => _events;
  DateTime? get loadedFrom => _loadedFrom;
  DateTime? get lastSeen => _lastSeen;
  bool get loading => _loading;
  bool get loadingOlder => _loadingOlder;
  Object? get error => _error;

  /// True once rules are known and the user has none that can fire.
  bool get notConfigured => _rulesLoaded && _types.isEmpty;

  int get unreadCount {
    final seen = _lastSeen;
    if (seen == null) return 0;
    return _events.where((e) => e.eventTime.isAfter(seen)).length;
  }

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
      await _ensureLastSeen();
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

  Future<void> markAllSeen() async {
    final now = DateTime.now();
    _lastSeen = now;
    notifyListeners();
    final key = _lastSeenKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, now.millisecondsSinceEpoch);
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
    _lastSeen = null;
    _lastSeenKey = null;
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

  /// Read status is kept per user on this phone. On first use start from
  /// now so existing history doesn't all show up as unread.
  Future<void> _ensureLastSeen() async {
    if (_lastSeenKey != null) return;
    final user = await AuthService().getUser();
    final key = '$_lastSeenKeyPrefix${user?['id'] ?? 'unknown'}';
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(key);
    if (stored != null) {
      _lastSeen = DateTime.fromMillisecondsSinceEpoch(stored);
    } else {
      _lastSeen = DateTime.now();
      await prefs.setInt(key, _lastSeen!.millisecondsSinceEpoch);
    }
    _lastSeenKey = key;
  }

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
