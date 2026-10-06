import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// One 3D vehicle icon: a shape (vehicle type seen from one of 16 angles)
/// painted with a cab and a body colour.
@immutable
class VehicleIcon {
  /// Icon name on the icon server, e.g. `cam_caja_60`.
  final String shape;

  /// Angle in degrees, a multiple of [rotationStep].
  final double angle;

  /// Cab / main colour and body (cargo box) colour, as `RRGGBB`.
  final String cabHex;
  final String bodyHex;

  const VehicleIcon({
    required this.shape,
    required this.angle,
    required this.cabHex,
    required this.bodyHex,
  });

  static const rotationStep = 22.5; // 16 frames per 360°

  static const _shapeByCategory = {
    'default': 'sedan_50',
    'car': 'sedan_50',
    'van': 'furgoneta_60',
    'camper': 'furgoneta_ventana',
    'truck': 'cam_caja_60',
    'bus': 'bus_85',
    'tractor': 'tractor_v2',
    'crane': 'grua_v2',
    'trailer': 'remolque_caja_70',
    'trailer2': 'remolque_jaula',
    'motorcycle': 'moto_50',
    'scooter': 'motoneta_45',
    'construction': 'retroex',
    'freightelevator': 'montacarga',
    'boat': 'barco',
    'ship': 'barco',
    'plane': 'helicoptero',
    'helicopter': 'helicoptero',
    'bicycle': 'bici_40',
    'person': 'sedan_50',
    'animal': 'sedan_50',
    'pickup': 'pickup_60',
    'taxi': 'taxi',
    'planer': 'aplanadora_75',
    'excavator': 'excavadora',
    'excavatorcrane': 'grua_excavadora_85',
  };

  static const _hexByColorName = {
    'green': '22c55e', // moving
    'yellow': 'eab308', // idle (ignition on, stopped)
    'orange': 'f97316', // parked (ignition off)
    'red': 'ef4444', // offline
  };

  /// Shapes whose body is a cargo box, tinted with the status colour so the
  /// whole vehicle reads at a glance.
  static const _statusTintedBodyShapes = {'cam_caja_60'};

  /// Default body colour for the other shapes.
  static const _defaultBodyHex = 'F0F0F0';

  static String shapeFor(String? category) =>
      _shapeByCategory[category?.toLowerCase()] ?? _shapeByCategory['default']!;

  factory VehicleIcon.forDevice(String? category, String colorName, double course) {
    final shape = shapeFor(category);
    final cab = _hexByColorName[colorName] ?? _hexByColorName['red']!;
    return VehicleIcon(
      shape: shape,
      angle: (course % 360 ~/ rotationStep) * rotationStep,
      cabHex: cab,
      bodyHex: _statusTintedBodyShapes.contains(shape)
          ? lightenHex(cab, 0.7)
          : _defaultBodyHex,
    );
  }

  /// Degrees left over after snapping [course] to an icon angle.
  static double rotationRemainder(double course) =>
      (course % 360) - (course % 360 ~/ rotationStep) * rotationStep;

  /// Mixes an RRGGBB colour toward white by [amount] (0 = unchanged, 1 = white).
  static String lightenHex(String hex, double amount) {
    final value = int.parse(hex, radix: 16);
    String channel(int shift) {
      final c = (value >> shift) & 0xFF;
      final mixed = (c + (255 - c) * amount).round();
      return mixed.toRadixString(16).padLeft(2, '0');
    }

    return '${channel(16)}${channel(8)}${channel(0)}'.toUpperCase();
  }

  String get _templateKey => '${shape}_${(angle * 10).round()}';

  @override
  bool operator ==(Object other) =>
      other is VehicleIcon &&
      other.shape == shape &&
      other.angle == angle &&
      other.cabHex == cabHex &&
      other.bodyHex == bodyHex;

  @override
  int get hashCode => Object.hash(shape, angle, cabHex, bodyHex);
}

/// Loads 3D vehicle icons quickly and with as few downloads as possible:
///
/// - The server's SVG for a shape and angle differs between colours only in
///   two fill values, so each shape/angle is downloaded once with
///   placeholder colours (a template) and recoloured locally.
/// - Templates are saved on the device, so icons show instantly after the
///   first run and offline. Stale ones are refreshed in the background.
/// - Concurrent requests for the same template share one download.
/// - [prefetch] loads every angle of the fleet's shapes in the background,
///   so turning vehicles don't wait.
class VehicleIconCache {
  VehicleIconCache._();

  static const _baseUrl =
      'https://library.service24gps.com/img/iconUber/iconsDinamicos_new_medidas/';

  // Distinctive colours the server echoes verbatim; replaced locally.
  static const _cabPlaceholder = '0A0B0C';
  static const _bodyPlaceholder = '0D0E0F';

  static const _maxAge = Duration(days: 7);
  static const _retryAfterFailure = Duration(seconds: 30);
  static const _prefetchConcurrency = 4;
  static const _diskFolder = 'vehicle_icons_v1';

  static final _templates = <String, String>{};
  static final _colored = <VehicleIcon, String>{};
  static final _inFlight = <String, Future<String?>>{};
  static final _failedAt = <String, DateTime>{};
  static final _stale = <String>{};
  static final _prefetchedShapes = <String>{};
  static Future<Directory?>? _diskReady;

  /// Downloads an SVG; replaceable in tests.
  @visibleForTesting
  static Future<String?> Function(Uri url) fetch = _httpFetch;

  /// Whether to use the on-device cache; off in tests.
  @visibleForTesting
  static bool useDisk = true;

  /// The coloured SVG if its template is already in memory, else null.
  static String? svgSync(VehicleIcon icon) {
    final cached = _colored[icon];
    if (cached != null) return cached;
    final template = _templates[icon._templateKey];
    return template == null ? null : _colorize(icon, template);
  }

  /// The coloured SVG, loading its template from disk or the network if
  /// needed. Null if it can't be loaded.
  static Future<String?> load(VehicleIcon icon) async {
    final template = await _template(icon.shape, icon.angle);
    return template == null ? null : _colorize(icon, template);
  }

  /// Loads every angle of [shapes] in the background, a few at a time.
  static Future<void> prefetch(Iterable<String> shapes) async {
    final todo = shapes.where(_prefetchedShapes.add).toList();
    if (todo.isEmpty) return;
    final angles = [
      for (var a = 0.0; a < 360; a += VehicleIcon.rotationStep) a,
    ];
    final jobs = [
      for (final shape in todo)
        for (final angle in angles) (shape, angle),
    ];
    for (var i = 0; i < jobs.length; i += _prefetchConcurrency) {
      await Future.wait(jobs
          .skip(i)
          .take(_prefetchConcurrency)
          .map((job) => _template(job.$1, job.$2)));
    }
  }

  @visibleForTesting
  static void debugReset() {
    _templates.clear();
    _colored.clear();
    _inFlight.clear();
    _failedAt.clear();
    _stale.clear();
    _prefetchedShapes.clear();
    _diskReady = null;
  }

  static String _colorize(VehicleIcon icon, String template) {
    return _colored.putIfAbsent(
      icon,
      () => template
          .replaceAll(RegExp(_cabPlaceholder, caseSensitive: false), icon.cabHex)
          .replaceAll(RegExp(_bodyPlaceholder, caseSensitive: false), icon.bodyHex),
    );
  }

  static Future<String?> _template(String shape, double angle) async {
    final key = VehicleIcon(shape: shape, angle: angle, cabHex: '', bodyHex: '')._templateKey;
    final dir = await _openDisk();
    final cached = _templates[key];
    if (cached != null) {
      if (_stale.remove(key)) unawaited(_download(key, shape, angle, dir));
      return cached;
    }
    final failedAt = _failedAt[key];
    if (failedAt != null && DateTime.now().difference(failedAt) < _retryAfterFailure) {
      return null;
    }
    return _download(key, shape, angle, dir);
  }

  static Future<String?> _download(String key, String shape, double angle, Directory? dir) {
    return _inFlight.putIfAbsent(key, () async {
      try {
        final url = Uri.parse(
          '$_baseUrl$shape.php?grados=${angle.toStringAsFixed(1)}'
          '&c=$_cabPlaceholder&b=$_bodyPlaceholder',
        );
        final svg = await fetch(url);
        if (svg == null) {
          _failedAt[key] = DateTime.now();
          return _templates[key];
        }
        final template = _inlineStyles(svg);
        _templates[key] = template;
        _colored.removeWhere((icon, _) => icon._templateKey == key);
        _failedAt.remove(key);
        if (dir != null) {
          unawaited(File('${dir.path}/$key.svg')
              .writeAsString(template)
              .catchError((Object e) {
            dev.log('Icon save failed: $key', name: 'Icons', error: e);
            return File('');
          }));
        }
        return template;
      } finally {
        _inFlight.remove(key);
      }
    });
  }

  /// Loads every saved template into memory once.
  static Future<Directory?> _openDisk() {
    return _diskReady ??= () async {
      if (!useDisk) return null;
      try {
        final base = await getApplicationSupportDirectory();
        final dir = Directory('${base.path}/$_diskFolder');
        await dir.create(recursive: true);
        final now = DateTime.now();
        await for (final entity in dir.list()) {
          if (entity is! File || !entity.path.endsWith('.svg')) continue;
          final name = entity.uri.pathSegments.last;
          final key = name.substring(0, name.length - 4);
          try {
            _templates[key] = await entity.readAsString();
            if (now.difference(await entity.lastModified()) > _maxAge) {
              _stale.add(key);
            }
          } catch (e) {
            dev.log('Icon read failed: $name', name: 'Icons', error: e);
          }
        }
        return dir;
      } catch (e) {
        dev.log('Icon disk cache unavailable', name: 'Icons', error: e);
        return null;
      }
    }();
  }

  static Future<String?> _httpFetch(Uri url) async {
    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        dev.log('Icon ${response.statusCode}: $url', name: 'Icons');
        return null;
      }
      return response.body;
    } catch (e) {
      dev.log('Icon fetch failed: $url', name: 'Icons', error: e);
      return null;
    }
  }

  /// Inlines CSS `<style>` classes into element attributes, working around
  /// flutter_svg's lack of `<style>` support.
  static String _inlineStyles(String svg) {
    final styleMatch = RegExp(r'<style[^>]*>(.*?)</style>', dotAll: true).firstMatch(svg);
    if (styleMatch == null) return svg;

    // Parse CSS rules: .cls-1{fill:#fff;opacity:0.3;}
    final rules = <String, Map<String, String>>{};
    final rulePattern = RegExp(r'\.([\w-]+)\s*\{([^}]*)\}');
    for (final m in rulePattern.allMatches(styleMatch.group(1)!)) {
      final props = <String, String>{};
      for (final decl in m.group(2)!.split(';')) {
        final parts = decl.split(':');
        if (parts.length == 2) props[parts[0].trim()] = parts[1].trim();
      }
      rules[m.group(1)!] = props;
    }

    var result = svg.replaceAll(
      RegExp(r'<defs>\s*<style[^>]*>.*?</style>\s*</defs>', dotAll: true),
      '',
    );
    result = result.replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '');

    // Replace class="cls-X" with inline SVG attributes
    return result.replaceAllMapped(RegExp(r'class="([\w-]+)"'), (match) {
      final props = rules[match.group(1)!];
      if (props == null) return match.group(0)!;
      return props.entries.map((e) => '${e.key}="${e.value}"').join(' ');
    });
  }
}
