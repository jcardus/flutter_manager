class Trip {
  final int deviceId;
  final int? startPositionId;
  final int? endPositionId;
  final DateTime startTime;
  final DateTime endTime;
  final double distance; // meters
  final double? averageSpeed; // knots
  final double? maxSpeed; // knots
  final int duration; // milliseconds
  final double? startLat;
  final double? startLon;
  final double? endLat;
  final double? endLon;
  final String? startAddress;
  final String? endAddress;
  final Map<String, dynamic>? attributes;

  Trip({
    required this.deviceId,
    this.startPositionId,
    this.endPositionId,
    required this.startTime,
    required this.endTime,
    required this.distance,
    this.averageSpeed,
    this.maxSpeed,
    required this.duration,
    this.startLat,
    this.startLon,
    this.endLat,
    this.endLon,
    this.startAddress,
    this.endAddress,
    this.attributes,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      deviceId: json['deviceId'] as int,
      startPositionId: json['startPositionId'] as int?,
      endPositionId: json['endPositionId'] as int?,
      startTime: _parseDateTime(json['startTime']),
      endTime: _parseDateTime(json['endTime']),
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      averageSpeed: (json['averageSpeed'] as num?)?.toDouble(),
      maxSpeed: (json['maxSpeed'] as num?)?.toDouble(),
      duration: json['duration'] as int? ?? 0,
      startLat: (json['startLat'] as num?)?.toDouble(),
      startLon: (json['startLon'] as num?)?.toDouble(),
      endLat: (json['endLat'] as num?)?.toDouble(),
      endLon: (json['endLon'] as num?)?.toDouble(),
      startAddress: json['startAddress'] as String?,
      endAddress: json['endAddress'] as String?,
      attributes: json['attributes'] as Map<String, dynamic>?,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is String) {
      return DateTime.parse(value);
    } else {
      throw FormatException('Invalid datetime format: $value');
    }
  }

  // Distance in kilometers
  double get distanceKm => distance / 1000;

  // Average speed in km/h
  double? get averageSpeedKmh => averageSpeed != null ? averageSpeed! * 1.852 : null;

  // Max speed in km/h
  double? get maxSpeedKmh => maxSpeed != null ? maxSpeed! * 1.852 : null;

  // Duration as Duration object
  Duration get durationDuration => Duration(milliseconds: duration);
}
