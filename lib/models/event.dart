class Event {
  final int id;
  final String type;
  final DateTime eventTime;
  final int deviceId;
  final int? positionId;
  final int? geofenceId;
  final int? maintenanceId;
  final Map<String, dynamic>? attributes;

  Event({
    required this.id,
    required this.type,
    required this.eventTime,
    required this.deviceId,
    this.positionId,
    this.geofenceId,
    this.maintenanceId,
    this.attributes,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as int,
      type: json['type'] as String,
      eventTime: DateTime.parse(
        (json['eventTime'] ?? json['serverTime']) as String,
      ),
      deviceId: json['deviceId'] as int,
      positionId: json['positionId'] as int?,
      geofenceId: json['geofenceId'] as int?,
      maintenanceId: json['maintenanceId'] as int?,
      attributes: json['attributes'] as Map<String, dynamic>?,
    );
  }
}
