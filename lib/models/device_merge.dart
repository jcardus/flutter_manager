class DeviceMerge {
  final String id;
  final String resellerId;
  final int primaryDeviceId;
  final int secondaryDeviceId;
  final String? displayName;
  final String createdAt;

  DeviceMerge({
    required this.id,
    required this.resellerId,
    required this.primaryDeviceId,
    required this.secondaryDeviceId,
    this.displayName,
    required this.createdAt,
  });

  factory DeviceMerge.fromJson(Map<String, dynamic> json) {
    return DeviceMerge(
      id: json['id'] as String,
      resellerId: json['reseller_id'] as String,
      primaryDeviceId: json['primary_device_id'] as int,
      secondaryDeviceId: json['secondary_device_id'] as int,
      displayName: json['display_name'] as String?,
      createdAt: json['created_at'] as String,
    );
  }
}
