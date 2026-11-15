import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manager/utils/marker_bitmap_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MarkerBitmapHelper', () {
    test('creates circular badge bitmap descriptor and caches result', () async {
      final bitmap1 = await MarkerBitmapHelper.getCircleIconBitmap(
        icon: Icons.flag,
        color: Colors.green,
      );

      expect(bitmap1, isNotNull);

      // Verify caching: requesting same configuration returns same future/descriptor
      final bitmap2 = await MarkerBitmapHelper.getCircleIconBitmap(
        icon: Icons.flag,
        color: Colors.green,
      );

      expect(identical(bitmap1, bitmap2), isTrue);
    });

    test('creates different bitmaps for different icons and colors', () async {
      final flagBitmap = await MarkerBitmapHelper.getCircleIconBitmap(
        icon: Icons.flag,
        color: Colors.green,
      );

      final stopBitmap = await MarkerBitmapHelper.getCircleIconBitmap(
        icon: Icons.stop,
        color: Colors.red,
      );

      expect(identical(flagBitmap, stopBitmap), isFalse);
    });
  });
}
