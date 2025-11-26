import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/position.dart';

class DeviceColors {
  /// Get the appropriate theme color for a device based on its status and position
  /// Returns:
  /// - tertiary: Ignition on and moving (speed > 0)
  /// - Color(0xFFFFA500): Ignition on but stopped (speed = 0) - Orange
  /// - error: Ignition off
  /// - outline: No position data or ignition attribute missing
  static Color getDeviceColor(Device device, Position? position, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (position == null) {
      return colorScheme.outline;
    }

    final attributes = position.attributes;
    if (attributes == null || !attributes.containsKey('ignition')) {
      return colorScheme.outline;
    }

    final ignition = attributes['ignition'] == true;
    if (ignition) {
      // Ignition is on - check speed
      return position.speed > 0 ? colorScheme.tertiary : const Color(0xFFFFA500);
    } else {
      // Ignition is off
      return colorScheme.error;
    }
  }

  /// Get color name as string (for map GeoJSON properties)
  /// Returns: 'green', 'yellow', 'red', or 'grey'
  static String getDeviceColorName(Device device, Position? position) {
    if (position == null) {
      return 'grey';
    }

    final attributes = position.attributes;
    if (attributes == null || !attributes.containsKey('ignition')) {
      return 'grey';
    }

    final ignition = attributes['ignition'] == true;
    if (ignition) {
      // Ignition is on - check speed
      return position.speed > 0 ? 'green' : 'yellow';
    } else {
      // Ignition is off
      return 'red';
    }
  }
}
