import 'package:flutter_test/flutter_test.dart';
import 'package:manager/utils/vehicle_icon_cache.dart';

// Shaped like the icon server's response, with the placeholder colours the
// cache requests.
const _template = '<svg viewBox="0 0 700 700"><defs><style>'
    '.cls-2{fill:#0A0B0C;}.cls-5{fill:#0D0E0F;}</style></defs>'
    '<path class="cls-2" d="M0 0"/><path class="cls-5" d="M1 1"/></svg>';

void main() {
  late List<Uri> requests;

  setUp(() {
    VehicleIconCache.debugReset();
    VehicleIconCache.useDisk = false;
    requests = [];
    VehicleIconCache.fetch = (url) async {
      requests.add(url);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return _template;
    };
  });

  group('VehicleIcon.forDevice', () {
    test('snaps the angle and tints the truck box with the status colour', () {
      final icon = VehicleIcon.forDevice('truck', 'green', 50);
      expect(icon.shape, 'cam_caja_60');
      expect(icon.angle, 45);
      expect(icon.cabHex, '22c55e');
      expect(icon.bodyHex, 'BDEECF');
      expect(VehicleIcon.rotationRemainder(50), 5);
    });

    test('keeps the default body for other shapes', () {
      final icon = VehicleIcon.forDevice('car', 'red', 0);
      expect(icon.shape, 'sedan_50');
      expect(icon.bodyHex, 'F0F0F0');
      expect(VehicleIcon.forDevice('unknown', 'red', 0).shape, 'sedan_50');
    });
  });

  group('VehicleIconCache', () {
    test('downloads a shape and angle once and colours it locally', () async {
      final moving = VehicleIcon.forDevice('truck', 'green', 90);
      final offline = VehicleIcon.forDevice('truck', 'red', 90);
      final results = await Future.wait([
        VehicleIconCache.load(moving),
        VehicleIconCache.load(moving),
        VehicleIconCache.load(offline),
      ]);

      expect(requests, hasLength(1));
      expect(requests.single.queryParameters['c'], '0A0B0C');
      expect(results[0], contains('fill="#22c55e"'));
      expect(results[0], contains('fill="#BDEECF"'));
      expect(results[2], contains('fill="#ef4444"'));
      for (final svg in results) {
        expect(svg, isNot(contains('<style')));
        expect(svg, isNot(contains('0A0B0C')));
      }
      // Other colours of the same shape and angle are now instant.
      expect(VehicleIconCache.svgSync(VehicleIcon.forDevice('truck', 'yellow', 90)),
          contains('fill="#eab308"'));
    });

    test('does not retry a failed download straight away', () async {
      VehicleIconCache.fetch = (url) async {
        requests.add(url);
        return null;
      };
      final icon = VehicleIcon.forDevice('bus', 'green', 0);
      expect(await VehicleIconCache.load(icon), isNull);
      expect(await VehicleIconCache.load(icon), isNull);
      expect(requests, hasLength(1));
    });

    test('prefetches every angle of a shape once', () async {
      await VehicleIconCache.prefetch(['bus_85']);
      expect(requests, hasLength(16));
      await VehicleIconCache.prefetch(['bus_85']);
      expect(requests, hasLength(16));
      expect(VehicleIconCache.svgSync(VehicleIcon.forDevice('bus', 'green', 200)), isNotNull);
    });
  });
}
