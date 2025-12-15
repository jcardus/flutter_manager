class Stop {
  final int deviceId;
  final int? positionId;
  final DateTime startTime;
  final DateTime endTime;
  final int duration; // milliseconds
  final double? latitude;
  final double? longitude;
  final String? address;
  final Map<String, dynamic>? attributes;

  Stop({
    required this.deviceId,
    this.positionId,
    required this.startTime,
    required this.endTime,
    required this.duration,
    this.latitude,
    this.longitude,
    this.address,
    this.attributes,
  });

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      deviceId: json['deviceId'] as int,
      positionId: json['positionId'] as int?,
      startTime: _parseDateTime(json['startTime']),
      endTime: _parseDateTime(json['endTime']),
      duration: json['duration'] as int? ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
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

  // Duration as Duration object
  Duration get durationDuration => Duration(milliseconds: duration);
}
