import 'dart:math' as math;
import 'dart:ui';

class TurboColormap {
  // Polynomial coefficients for turbo colormap
  static const List<double> _rCoeffs = [
    0.13572138,
    4.61539260,
    -42.66032258,
    132.13108234,
    -152.94239396,
    59.28637943
  ];

  static const List<double> _gCoeffs = [
    0.09140261,
    2.19418839,
    4.84296658,
    -14.18503333,
    4.27729857,
    2.82956604
  ];

  static const List<double> _bCoeffs = [
    0.10667330,
    12.64194608,
    -60.58204836,
    110.36276771,
    -89.90310912,
    27.34824973
  ];

  /// Interpolate a single color channel using polynomial coefficients
  static double _interpolateChannel(double normalizedValue, List<double> coeffs) {
    double result = 0.0;
    for (int i = 0; i < coeffs.length; i++) {
      result += coeffs[i] * math.pow(normalizedValue, i);
    }
    return math.max(0.0, math.min(1.0, result));
  }

  /// Generate RGB color from normalized value (0.0 to 1.0)
  static Color interpolateTurbo(double value) {
    final normalizedValue = math.max(0.0, math.min(1.0, value));

    final r = (255 * _interpolateChannel(normalizedValue, _rCoeffs)).round();
    final g = (255 * _interpolateChannel(normalizedValue, _gCoeffs)).round();
    final b = (255 * _interpolateChannel(normalizedValue, _bCoeffs)).round();

    return Color.fromARGB(255, r, g, b);
  }

  /// Get color for a speed value within a min-max range
  static Color getSpeedColor(double speed, double minSpeed, double maxSpeed) {
    if (maxSpeed <= minSpeed) {
      return interpolateTurbo(0.5); // Return middle color if range is invalid
    }

    final normalizedSpeed = (speed - minSpeed) / (maxSpeed - minSpeed);
    return interpolateTurbo(normalizedSpeed);
  }

  /// Get color as hex string (e.g., "#FF5722")
  static String getSpeedColorHex(double speed, double minSpeed, double maxSpeed) {
    final color = getSpeedColor(speed, minSpeed, maxSpeed);
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  /// Get color as RGB array [r, g, b] for MapLibre
  static List<int> getSpeedColorRgb(double speed, double minSpeed, double maxSpeed) {
    final color = getSpeedColor(speed, minSpeed, maxSpeed);
    return [color.red, color.green, color.blue];
  }
}
