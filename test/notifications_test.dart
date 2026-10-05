import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manager/l10n/app_localizations.dart';
import 'package:manager/l10n/app_localizations_en.dart';
import 'package:manager/l10n/app_localizations_pt.dart';
import 'package:manager/models/event.dart';
import 'package:manager/models/notification_rule.dart';
import 'package:manager/widgets/notifications_view.dart';
import 'package:manager/utils/event_display.dart';

Event _event(String type, {Map<String, dynamic>? attributes}) => Event(
      id: 1,
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
}
