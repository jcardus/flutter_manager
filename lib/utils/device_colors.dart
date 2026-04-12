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

  static Color getStatusColor(Device device, BuildContext context) {
    switch (device.status?.toLowerCase()) {
      case 'online':
        return Theme.of(context).colorScheme.tertiary;
      case 'offline':
        return Theme.of(context).colorScheme.error;
      case 'unknown':
        return Theme.of(context).colorScheme.outline;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  /// Get color name as string (for 3D icon URL color parameter)
  /// Returns: 'green', 'yellow', 'orange', or 'red'
  /// Matches traccar-dash logic: offline→red, moving→green, idle→yellow, parked→orange
  static String getDeviceColorName(Device device, Position? position) {
    if (device.status?.toLowerCase() != 'online') {
      return 'red'; // offline
    }

    if (position == null) {
      return 'red';
    }

    if (position.speed > 0) {
      return 'green'; // moving
    }

    final ignition = position.attributes?['ignition'] == true;
    if (ignition) {
      return 'yellow'; // idle (ignition on, stopped)
    }

    return 'orange'; // parked (ignition off)
  }
}
