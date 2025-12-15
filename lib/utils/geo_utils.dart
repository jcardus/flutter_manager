import 'dart:math' as math;
import '../models/position.dart';

/// Converts degrees to radians
double toRadians(double degrees) {
  return degrees * math.pi / 180;
}

/// Calculates distance between two GPS coordinates using Haversine formula
/// Returns distance in kilometers
double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371.0; // Earth's radius in kilometers

  final dLat = toRadians(lat2 - lat1);
  final dLon = toRadians(lon2 - lon1);

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRadians(lat1)) * math.cos(toRadians(lat2)) *
      math.sin(dLon / 2) * math.sin(dLon / 2);

  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

  return earthRadius * c;
}

/// Calculates total distance traveled across a list of positions
/// Returns total distance in kilometers
double calculateTotalDistance(List<Position> positions) {
  if (positions.length < 2) return 0.0;

  double totalDistance = 0.0;
  for (int i = 0; i < positions.length - 1; i++) {
    totalDistance += calculateDistance(
      positions[i].latitude,
      positions[i].longitude,
      positions[i + 1].latitude,
      positions[i + 1].longitude,
    );
  }
  return totalDistance;
}
