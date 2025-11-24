import 'package:flutter/widgets.dart';

/// Minimal icon mapping for the platform-font icon font.
/// Make sure pubspec.yaml includes:
///
/// flutter:
///   fonts:
///     - family: platform-font
///       fonts:
///         - asset: assets/fonts/icons.ttf
///
class PlatformIcons {
  PlatformIcons._();

  static const String _fontFamily = 'platform-font';

  static const IconData odometer = IconData(0xe974, fontFamily: _fontFamily);
  static const IconData route = IconData(0xeae0, fontFamily: _fontFamily);
  static const IconData ignitionOn = IconData(0xea7b, fontFamily: _fontFamily);
  static const IconData ignitionOff = IconData(0xea7a, fontFamily: _fontFamily);
  static const IconData speedSlow = IconData(0xe90d, fontFamily: _fontFamily);
  static const IconData speedMedium = IconData(0xe90c, fontFamily: _fontFamily);
  static const IconData speedFast = IconData(0xe90b, fontFamily: _fontFamily);
  static const IconData update = IconData(0xe9ff, fontFamily: _fontFamily);
  static const IconData lastLocationTime = IconData(0xea40, fontFamily: _fontFamily);
  static const IconData location = IconData(0xe935, fontFamily: _fontFamily);
  static const IconData stop = IconData(0xe90e, fontFamily: _fontFamily);
  static const IconData play = IconData(0xe9bd, fontFamily: _fontFamily);


}
