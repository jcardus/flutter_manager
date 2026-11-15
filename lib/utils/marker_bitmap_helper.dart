import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:platform_maps_flutter/platform_maps_flutter.dart';
import 'vehicle_icon_cache.dart';

class MarkerBitmapHelper {
  MarkerBitmapHelper._();

  static final Map<String, BitmapDescriptor> _cache = {};
  static final Map<String, Future<BitmapDescriptor?>> _inFlight = {};

  /// Converts a [VehicleIcon] SVG into a native [BitmapDescriptor] for Apple/Google Maps.
  static Future<BitmapDescriptor?> getVehicleBitmap(VehicleIcon icon) async {
    final key = '${icon.shape}_${(icon.angle * 10).round()}_${icon.cabHex}_${icon.bodyHex}';
    final cached = _cache[key];
    if (cached != null) return cached;

    if (_inFlight.containsKey(key)) return _inFlight[key];

    final future = _loadVehicleBitmap(icon, key);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  static Future<BitmapDescriptor?> _loadVehicleBitmap(VehicleIcon icon, String key) async {
    try {
      final svgString = await VehicleIconCache.load(icon);
      if (svgString == null) return null;

      final pictureInfo = await vg.loadPicture(SvgStringLoader(svgString), null);
      final image = await pictureInfo.picture.toImage(80, 80);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      pictureInfo.picture.dispose();
      if (byteData == null) return null;

      final descriptor = BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
      _cache[key] = descriptor;
      return descriptor;
    } catch (_) {
      return null;
    }
  }

  /// Creates a circular badge marker for events, flags and stops.
  static Future<BitmapDescriptor> getCircleIconBitmap({
    required IconData icon,
    required Color color,
    Color backgroundColor = Colors.white,
    double size = 56,
  }) async {
    final key = 'circle_${icon.codePoint}_${color.toARGB32()}_${backgroundColor.toARGB32()}_$size';
    final cached = _cache[key];
    if (cached != null) return cached;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);
    final radius = (size - 6) / 2;

    // Background circle
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawCircle(center, radius, bgPaint);

    // Border circle
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, borderPaint);

    // Icon in the center
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size * 0.52,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();

    final descriptor = BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
    _cache[key] = descriptor;
    return descriptor;
  }
}
