import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manager/l10n/app_localizations.dart';
import 'package:manager/models/device.dart';
import 'package:manager/models/event.dart';
import 'package:manager/models/position.dart';
import 'package:manager/widgets/device_detail.dart';

Position _position(int id, {required double speed, required String address}) => Position(
      id: id,
      deviceId: 1,
      fixTime: DateTime.now(),
      serverTime: DateTime.now(),
      valid: true,
      latitude: 38.7,
      longitude: -9.1,
      altitude: 0,
      speed: speed,
      course: 0,
      address: address,
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ));
  // Test HTTP returns 400, so the Street View card falls back to the address.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.pump();
  await tester.pump();
}

void main() {
  final device = Device(id: 1, name: 'Truck 12', status: 'online');
  final live = _position(2, speed: 0, address: 'Live street');
  final alertPosition = _position(1, speed: 40, address: 'Alert street');
  final alert = Event(
    id: 7,
    type: 'ignitionOn',
    eventTime: DateTime.now(),
    deviceId: 1,
    positionId: 1,
  );

  testWidgets('live panel shows all actions and live status', (tester) async {
    await _pump(tester, DeviceDetail(device: device, position: live, onClose: () {}));
    expect(find.text('ONLINE'), findsOneWidget);
    expect(find.textContaining('Live street'), findsOneWidget, reason: 'card only');
    for (final label in ['Directions', 'Route', 'Share', 'Block']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Current position'), findsNothing);
  });

  testWidgets('alert panel shows the alert position and only safe actions', (tester) async {
    var showedCurrent = false;
    await _pump(
      tester,
      DeviceDetail(
        device: device,
        position: live,
        onClose: () {},
        alert: alert,
        alertPosition: alertPosition,
        onShowCurrent: () => showedCurrent = true,
      ),
    );
    expect(find.textContaining('Ignition On · Today'), findsOneWidget);
    expect(find.text('ONLINE'), findsNothing);
    expect(find.textContaining('Alert street'), findsOneWidget, reason: 'card only');
    expect(find.textContaining('Live street'), findsNothing);
    expect(find.text('Directions'), findsOneWidget);
    for (final label in ['Route', 'Share', 'Block', 'Unblock']) {
      expect(find.text(label), findsNothing, reason: label);
    }
    await tester.tap(find.text('Current position'));
    expect(showedCurrent, isTrue);
  });
}
