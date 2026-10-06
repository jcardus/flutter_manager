import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manager/models/position.dart';
import 'package:manager/widgets/device_route.dart';

Position _at(int id, DateTime time, {double speed = 0, String? address}) => Position(
      id: id,
      deviceId: 1,
      fixTime: time,
      serverTime: time,
      valid: true,
      latitude: 38.7 + id * 0.001,
      longitude: -9.1,
      altitude: 0,
      speed: speed,
      course: 0,
      address: address,
    );

void main() {
  testWidgets('slides through every position of the day', (tester) async {
    final day = DateTime(2026, 10, 6);
    final positions = [
      _at(1, day.add(const Duration(hours: 8)), address: 'Depot'),
      _at(2, day.add(const Duration(hours: 9)), speed: 27, address: 'Highway'),
      _at(3, day.add(const Duration(hours: 18)), address: 'Customer'),
    ];
    final scrubbed = <Position>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DayScrubber(positions: positions, onScrub: scrubbed.add),
      ),
    ));

    expect(find.textContaining('08:00 – 18:00'), findsOneWidget);
    expect(find.text('Depot'), findsOneWidget);

    final slider = find.byKey(const ValueKey('daySlider'));
    await tester.drag(slider, const Offset(2000, 0));
    await tester.pump();
    expect(scrubbed.last.id, 3);
    expect(find.text('Customer'), findsOneWidget);

    await tester.drag(slider, const Offset(-2000, 0));
    await tester.pump();
    expect(scrubbed.last.id, 1);
    expect(scrubbed.map((p) => p.id), contains(2), reason: 'passes the trip');
  });
}
