import 'package:flutter/material.dart';
import '../models/device.dart';

class DeviceIcons {
  static IconData getCategoryIcon(Device device) {
    switch (device.category?.toLowerCase()) {
      case 'car':
      case 'vehicle':
        return Icons.directions_car;
      case 'truck':
        return Icons.local_shipping;
      case 'bus':
        return Icons.directions_bus;
      case 'motorcycle':
        return Icons.two_wheeler;
      case 'bicycle':
        return Icons.pedal_bike;
      case 'person':
        return Icons.person;
      case 'boat':
      case 'ship':
        return Icons.directions_boat;
      case 'plane':
      case 'helicopter':
        return Icons.flight;
      default:
        return Icons.navigation;
    }
  }
}
