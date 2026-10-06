import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manager/models/position.dart';
import 'package:manager/widgets/street_view.dart';

Position _position({String? address}) => Position(
      id: 1,
      deviceId: 1,
      fixTime: DateTime(2026, 10, 6),
      serverTime: DateTime(2026, 10, 6),
      valid: true,
      latitude: 38.7223,
      longitude: -9.1393,
      altitude: 0,
      speed: 0,
      course: 0,
      address: address,
    );

Future<void> _pumpStreetView(WidgetTester tester, Position position) async {
  // Test HTTP requests return 400, so there's no street-level photo.
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: StreetView(position: position, width: 400)),
  ));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.pump();
}

void main() {
  testWidgets('shows the address when there is no street-level photo', (tester) async {
    await _pumpStreetView(tester, _position(address: 'Rua Augusta 1, Lisboa'));
    expect(find.text('Rua Augusta 1, Lisboa'), findsOneWidget);
    expect(find.text('Loading...'), findsNothing);
    expect(find.byIcon(Icons.streetview), findsNothing);
  });

  testWidgets('shows the coordinates when the position has no address', (tester) async {
    await _pumpStreetView(tester, _position());
    expect(find.text('38.72230, -9.13930'), findsOneWidget);
  });
}
