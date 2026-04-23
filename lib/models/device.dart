class Device {
  final int id;
  final String name;
  final String? uniqueId;
  final String? status;
  final bool disabled;
  final DateTime? lastUpdate;
  final int? positionId;
  final int? groupId;
  final String? phone;
  final String? model;
  final String? contact;
  final String? category;
  final Map<String, dynamic>? attributes;

  Device({
    required this.id,
    required this.name,
    this.uniqueId,
    this.status,
    this.disabled = false,
    this.lastUpdate,
    this.positionId,
    this.groupId,
    this.phone,
    this.model,
    this.contact,
    this.category,
    this.attributes,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as int,
      name: json['name'] as String,
      uniqueId: json['uniqueId'] as String?,
      status: json['status'] as String?,
      disabled: json['disabled'] as bool? ?? false,
      lastUpdate: json['lastUpdate'] != null
          ? DateTime.parse(json['lastUpdate'] as String)
          : null,
      positionId: json['positionId'] as int?,
      groupId: json['groupId'] as int?,
      phone: json['phone'] as String?,
      model: json['model'] as String?,
      contact: json['contact'] as String?,
      category: json['category'] as String?,
      attributes: json['attributes'] as Map<String, dynamic>?,
    );
  }

  Device copyWith({String? status}) {
    return Device(
      id: id,
      name: name,
      uniqueId: uniqueId,
      status: status ?? this.status,
      disabled: disabled,
      lastUpdate: lastUpdate,
      positionId: positionId,
      groupId: groupId,
      phone: phone,
      model: model,
      contact: contact,
      category: category,
      attributes: attributes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'uniqueId': uniqueId,
      'status': status,
      'disabled': disabled,
      'lastUpdate': lastUpdate?.toIso8601String(),
      'positionId': positionId,
      'groupId': groupId,
      'phone': phone,
      'model': model,
      'contact': contact,
      'category': category,
      'attributes': attributes,
    };
  }
}