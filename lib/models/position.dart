class Position {
  final int id;
  final int deviceId;
  final DateTime fixTime;
  final DateTime serverTime;
  final bool valid;
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;
  final double course;
  final String? address;
  final double? accuracy;
  final String? network;
  final int? batteryLevel;
  final Map<String, dynamic>? attributes;

  Position({
    required this.id,
    required this.deviceId,
    required this.fixTime,
    required this.serverTime,
    required this.valid,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed,
    required this.course,
    this.address,
    this.accuracy,
    this.network,
    this.batteryLevel,
    this.attributes,
  });

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      id: json['id'] as int,
      deviceId: json['deviceId'] as int,
      fixTime: _parseDateTime(json['fixTime']),
      serverTime: _parseDateTime(json['serverTime']),
      valid: json['valid'] as bool? ?? false,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble() ?? 0.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      course: (json['course'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] as String?,
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      batteryLevel: json['attributes']?['batteryLevel'] as int?,
      attributes: json['attributes'] as Map<String, dynamic>?,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is int) {
      // Unix milliseconds
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is String) {
      // ISO 8601 string
      return DateTime.parse(value);
    } else {
      throw FormatException('Invalid datetime format: $value');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'fixTime': fixTime.toIso8601String(),
      'serverTime': serverTime.toIso8601String(),
      'valid': valid,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speed': speed,
      'course': course,
      'address': address,
      'accuracy': accuracy,
      'network': network,
      'attributes': attributes,
    };
  }
}
