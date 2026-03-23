import 'dart:developer' as dev;
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';

class MapillaryImage {
  final String id;
  final double compassAngle;
  final bool isPano;

  MapillaryImage({
    required this.id,
    required this.compassAngle,
    required this.isPano,
  });
}

class MapillaryService {
  static const double _radiusMeters = 14.0;

  /// Get image data for a given position and course
  static Future<MapillaryImage?> getImageData({
    required double latitude,
    required double longitude,
    required double course,
  }) async {
    return await _fetchMapillaryImage(
      latitude: latitude,
      longitude: longitude,
      course: course,
    );
  }

  /// Fetch Mapillary image from API
  static Future<MapillaryImage?> _fetchMapillaryImage({
    required double latitude,
    required double longitude,
    required double course,
  }) async {
    try {
      // Calculate bounding box using Turf-style circle
      final bbox = _calculateBoundingBox(latitude, longitude, _radiusMeters);

      // Build Mapillary API URL
      final url = Uri.parse(
        'https://graph.mapillary.com/images'
        '?access_token=$mapillaryToken'
        '&fields=id,computed_compass_angle,is_pano'
        '&bbox=${bbox.join(',')}',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> data = json['data'] ?? [];

        if (data.isEmpty) {
          return null;
        }

        // Sort by closest computed compass angle to the course
        data.sort((a, b) {
          final angleA = (a['computed_compass_angle'] ?? 0.0).toDouble();
          final angleB = (b['computed_compass_angle'] ?? 0.0).toDouble();
          final diffA = (course - angleA).abs();
          final diffB = (course - angleB).abs();
          return diffA.compareTo(diffB);
        });

        // Return the closest match with ID, computed compass angle, and isPano
        final best = data[0];
        return MapillaryImage(
          id: best['id'] as String,
          compassAngle: (best['computed_compass_angle'] ?? 0.0).toDouble(),
          isPano: best['is_pano'] as bool? ?? false,
        );
      }

      return null;
    } catch (e) {
      dev.log('Mapillary API error: $e');
      return null;
    }
  }

  /// Calculate bounding box around a point with a given radius
  /// Similar to @turf/bbox(@turf/circle(...))
  static List<double> _calculateBoundingBox(
    double latitude,
    double longitude,
    double radiusMeters,
  ) {
    // Earth's radius in meters
    const double earthRadius = 6371000.0;

    // Convert radius to degrees
    final latDelta = (radiusMeters / earthRadius) * (180 / pi);
    final lonDelta = (radiusMeters / (earthRadius * cos(latitude * pi / 180))) * (180 / pi);

    // Calculate bounding box [minLon, minLat, maxLon, maxLat]
    final minLon = longitude - lonDelta;
    final minLat = latitude - latDelta;
    final maxLon = longitude + lonDelta;
    final maxLat = latitude + latDelta;

    return [minLon, minLat, maxLon, maxLat];
  }
}
