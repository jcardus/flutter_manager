import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manager/l10n/app_localizations.dart';
import 'package:manager/l10n/app_localizations_en.dart';
import 'package:manager/l10n/app_localizations_pt.dart';
import 'package:manager/models/event.dart';
import 'package:manager/models/notification_rule.dart';
import 'package:manager/services/notification_service.dart' show PushTap;
import 'package:manager/services/notifications_controller.dart';
import 'package:manager/widgets/notifications_view.dart';
import 'package:manager/utils/event_display.dart';

Event _event(String type, {int id = 1, Map<String, dynamic>? attributes}) => Event(
      id: id,
      type: type,
      eventTime: DateTime(2026, 10, 4),
      deviceId: 1,
      attributes: attributes,
    );

void main() {
  group('NotificationRule', () {
    test('parses alarms list', () {
      final rule = NotificationRule.fromJson({
        'type': 'alarm',
        'attributes': {'alarms': 'sos, powerCut,'},
      });
      expect(rule.type, 'alarm');
      expect(rule.alarms, {'sos', 'powerCut'});
    });

    test('handles missing attributes', () {
      final rule = NotificationRule.fromJson({'type': 'ignitionOn'});
      expect(rule.alarms, isEmpty);
    });
  });

  group('EventDisplay.label', () {
    final en = AppLocalizationsEn();
    final pt = AppLocalizationsPt();

    test('translates known event types', () {
      expect(EventDisplay.label(en, _event('ignitionOn')), 'Ignition On');
      expect(EventDisplay.label(pt, _event('deviceOnline')), 'Dispositivo online');
    });

    test('uses the alarm key for alarms', () {
      expect(
        EventDisplay.label(en, _event('alarm', attributes: {'alarm': 'sos'})),
        'SOS',
      );
      expect(
        EventDisplay.label(pt, _event('alarm', attributes: {'alarm': 'powerCut'})),
        'Corte de alimentação',
      );
    });

    test('falls back to a readable name for unknown keys', () {
      expect(
        EventDisplay.label(en, _event('alarm', attributes: {'alarm': 'highRpm'})),
        'Alarm: High rpm',
      );
      expect(EventDisplay.label(en, _event('deviceExpiration')), 'Device expiration');
      expect(EventDisplay.label(en, _event('alarm')), 'Alarm');
    });
  });

  testWidgets('notifications tab renders the empty state', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: NotificationsView(devices: {}, geofences: {}),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('No notifications in this period'), findsOneWidget);
    expect(find.text('Load older'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('read state', () {
    final controller = NotificationsController.instance;
    tearDown(controller.reset);

    test('tracks reads by event id, regardless of time', () async {
      // id 12 happened earlier but reached the server later (buffered).
      final late = Event(
          id: 12, type: 'ignitionOff', eventTime: DateTime(2026, 10, 1), deviceId: 1);
      controller.debugSetState(events: [
        _event('ignitionOn', id: 11),
        late,
        _event('ignitionOn', id: 9),
      ], lastSeenId: 10);
      expect(controller.unreadCount, 2);

      await controller.markRead(late);
      expect(controller.unreadCount, 1);
      expect(controller.isUnread(late), isFalse);

      await controller.markAllRead();
      expect(controller.unreadCount, 0);
      expect(controller.lastSeenId, 12);
    });

    test('keeps reads made before read state loads', () async {
      // e.g. a push tapped at launch, before the first load.
      final event = _event('ignitionOn', id: 5);
      await controller.markRead(event);
      controller.debugSetState(events: [event], lastSeenId: 1);
      expect(controller.isUnread(event), isFalse);
    });

    testWidgets('opening the tab keeps alerts unread until tapped', (tester) async {
      controller.debugSetState(events: [
        _event('ignitionOn', id: 11),
        _event('ignitionOff', id: 10),
        _event('ignitionOn', id: 9),
      ], lastSeenId: 9);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: NotificationsView(devices: {}, geofences: {}),
        ),
      ));
      await tester.pumpAndSettle();
      expect(controller.unreadCount, 2);
      expect(find.byKey(const ValueKey('unreadDot')), findsNWidgets(2));

      await tester.tap(find.text('Ignition Off'));
      await tester.pumpAndSettle();
      expect(controller.unreadCount, 1);
      expect(find.byKey(const ValueKey('unreadDot')), findsOneWidget);

      await tester.tap(find.text('Mark all as read'));
      await tester.pumpAndSettle();
      expect(controller.unreadCount, 0);
      expect(find.byKey(const ValueKey('unreadDot')), findsNothing);
      expect(find.text('Mark all as read'), findsNothing);
    });
  });

  group('PushTap', () {
    test('reads the event id Traccar puts in the push', () {
      expect(PushTap.fromMessage(const RemoteMessage(data: {'eventId': '42'})).eventId, 42);
    });

    test('has no event id when the push has none', () {
      expect(PushTap.fromMessage(const RemoteMessage()).eventId, isNull);
      expect(PushTap.fromMessage(const RemoteMessage(data: {'eventId': 'x'})).eventId, isNull);
    });
  });
}
