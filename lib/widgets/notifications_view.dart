import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/device.dart';
import '../models/event.dart';
import '../models/geofence.dart';
import '../services/notifications_controller.dart';
import '../utils/event_display.dart';

/// Notifications tab: the events the user is notified about, newest first.
class NotificationsView extends StatefulWidget {
  final Map<int, Device> devices;
  final Map<int, Geofence> geofences;
  final void Function(Event event)? onEventTap;

  const NotificationsView({
    super.key,
    required this.devices,
    required this.geofences,
    this.onEventTap,
  });

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  final _controller = NotificationsController.instance;

  /// Events newer than this are highlighted for as long as the tab is open,
  /// even though the badge is cleared immediately.
  late final DateTime? _unreadSince = _controller.lastSeen;

  @override
  void initState() {
    super.initState();
    // These notify listeners (the badge in the menu), which must not happen
    // while this tab is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.markAllSeen();
      if (_controller.events.isEmpty && !_controller.loading) {
        _controller.refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              l10n.notifications,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _buildBody(context, l10n),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    final events = _controller.events;
    if (events.isEmpty) {
      if (_controller.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_controller.error != null) {
        return _message(
          context,
          Icons.cloud_off,
          l10n.notificationsLoadError,
          action: FilledButton(
            onPressed: _controller.refresh,
            child: Text(l10n.retry),
          ),
        );
      }
      if (_controller.notConfigured) {
        return _message(
          context,
          Icons.notifications_off_outlined,
          l10n.notificationsNotConfigured,
        );
      }
    }

    final locale = Localizations.localeOf(context).toString();
    final items = <Widget>[];
    DateTime? currentDay;
    for (final event in events) {
      final time = event.eventTime.toLocal();
      final day = DateTime(time.year, time.month, time.day);
      if (day != currentDay) {
        currentDay = day;
        items.add(_DayHeader(label: _dayLabel(l10n, locale, day)));
      }
      items.add(_buildTile(context, l10n, locale, event));
    }
    if (events.isEmpty) {
      items.add(Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          l10n.noNotifications,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ));
    }
    items.add(Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      child: Center(
        child: _controller.loadingOlder
            ? const CircularProgressIndicator()
            : OutlinedButton.icon(
                onPressed: _controller.loadOlder,
                icon: const Icon(Icons.history),
                label: Text(l10n.loadOlder),
              ),
      ),
    ));

    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: items,
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    AppLocalizations l10n,
    String locale,
    Event event,
  ) {
    final colors = Theme.of(context).colorScheme;
    final color = EventDisplay.color(context, event.type);
    final unread = _unreadSince != null && event.eventTime.isAfter(_unreadSince);
    final deviceName = widget.devices[event.deviceId]?.name ?? '#${event.deviceId}';
    final geofenceName = event.geofenceId != null && event.geofenceId != 0
        ? widget.geofences[event.geofenceId]?.name
        : null;
    final subtitle = [deviceName, ?geofenceName].join(' · ');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(EventDisplay.icon(event.type), color: color, size: 20),
      ),
      title: Text(
        EventDisplay.label(l10n, event),
        style: unread ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(DateFormat.Hm(locale).format(event.eventTime.toLocal())),
          if (unread) ...[
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
            ),
          ],
        ],
      ),
      onTap: () => widget.onEventTap?.call(event),
    );
  }

  String _dayLabel(AppLocalizations l10n, String locale, DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return l10n.today;
    if (day == today.subtract(const Duration(days: 1))) return l10n.yesterday;
    return DateFormat.MMMEd(locale).format(day);
  }

  Widget _message(
    BuildContext context,
    IconData icon,
    String text, {
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String label;

  const _DayHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
