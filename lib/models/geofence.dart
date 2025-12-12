import 'dart:math';

class Geofence {
  final int id;
  final String name;
  final String? description;
  final String? area;
  final Map<String, dynamic>? attributes;

  Geofence({
    required this.id,
    required this.name,
    this.description,
    this.area,
    this.attributes,
  });

  factory Geofence.fromJson(Map<String, dynamic> json) {
    return Geofence(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      area: json['area'] as String?,
      attributes: json['attributes'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'area': area,
      'attributes': attributes,
    };
  }

  List<double> polygonCentroid(List<List<double>> coords) {
    double area = 0;
    double cx = 0;
    double cy = 0;
    for (int i = 0; i < coords.length - 1; i++) {
      double x1 = coords[i][0];
      double y1 = coords[i][1];
      double x2 = coords[i + 1][0];
      double y2 = coords[i + 1][1];

      double a = x1 * y2 - x2 * y1;
      area += a;
      cx += (x1 + x2) * a;
      cy += (y1 + y2) * a;
    }

    area *= 0.5;

    return [cx / (6 * area), cy / (6 * area)];
  }

  Map<String, dynamic>? areaToGeometry() {
    if (area == null) return null;

    final areaValue = area!.trim();

    if (areaValue.startsWith("POLYGON")) {
      final coordsStr =
      areaValue.substring(areaValue.indexOf("((") + 2, areaValue.lastIndexOf("))"));
      final coords = coordsStr
          .split(",")
          .map((p) => p.trim().split(" ").map(double.parse).toList())
          .map((c) => [c[1], c[0]])
          .toList();
      return {
        "type": "Polygon",
        "coordinates": [coords],
      };
    }

    if (areaValue.startsWith("LINESTRING")) {
      final coordsStr =
      areaValue.substring(areaValue.indexOf("(") + 1, areaValue.lastIndexOf(")"));
      final coords = coordsStr
          .split(",")
          .map((p) => p.trim().split(" ").map(double.parse).toList())
          .map((c) => [c[1], c[0]])
          .toList();

      return {
        "type": "LineString",
        "coordinates": coords
      };
    }

    if (areaValue.startsWith("CIRCLE")) {
      final inside = areaValue.substring(areaValue.indexOf("(") + 1, areaValue.lastIndexOf(")"));
      final parts = inside.split(",");
      final center = parts[0].trim().split(" ").map(double.parse).toList();
      final radius = double.parse(parts[1].trim());

      final lon = center[1];
      final lat = center[0];

      final coords = generateCirclePolygon(lon, lat, radius);

      return {
        "type": "Polygon",
        "coordinates": [coords]
      };
    }

    throw Exception("Unsupported geometry type: $areaValue");
  }

  List<List<double>> generateCirclePolygon(double lon, double lat, double radiusMeters) {
    const double earthRadius = 6378137.0; // meters
    const points = 64;
    final double angDist = radiusMeters / earthRadius;
    final double latRad = lat * pi / 180;
    final double lonRad = lon * pi / 180;

    List<List<double>> coordinates = [];

    for (int i = 0; i <= points; i++) {
      double bearing = (i * 360 / points) * pi / 180;

      double lat2 = asin(
        sin(latRad) * cos(angDist) +
            cos(latRad) * sin(angDist) * cos(bearing),
      );

      double lon2 = lonRad +
          atan2(
            sin(bearing) * sin(angDist) * cos(latRad),
            cos(angDist) - sin(latRad) * sin(lat2),
          );

      coordinates.add([
        lon2 * 180 / pi,
        lat2 * 180 / pi,
      ]);
    }

    return coordinates;
  }

}
