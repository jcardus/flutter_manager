class Summary {
  final int deviceId;
  final String? deviceName;
  final double distance; // meters
  final double? averageSpeed; // knots
  final double? maxSpeed; // knots
  final int engineHours; // milliseconds
  final double? spentFuel;

  Summary({
    required this.deviceId,
    this.deviceName,
    required this.distance,
    this.averageSpeed,
    this.maxSpeed,
    required this.engineHours,
    this.spentFuel,
  });

  factory Summary.fromJson(Map<String, dynamic> json) {
    return Summary(
      deviceId: json['deviceId'] as int,
      deviceName: json['deviceName'] as String?,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      averageSpeed: (json['averageSpeed'] as num?)?.toDouble(),
      maxSpeed: (json['maxSpeed'] as num?)?.toDouble(),
      engineHours: json['engineHours'] as int? ?? 0,
      spentFuel: (json['spentFuel'] as num?)?.toDouble(),
    );
  }

  double get distanceKm => distance / 1000;
  double? get averageSpeedKmh => averageSpeed != null ? averageSpeed! * 1.852 : null;
  double? get maxSpeedKmh => maxSpeed != null ? maxSpeed! * 1.852 : null;
  Duration get engineHoursDuration => Duration(milliseconds: engineHours);
}
