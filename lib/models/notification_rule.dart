/// A Traccar notification as configured by the user: which event type it
/// fires for and, for alarms, which alarm keys.
class NotificationRule {
  final int? id;
  final String type;
  final Set<String> alarms;
  final String? description;
  final String? notificators;
  final int? calendarId;
  final bool? always;

  NotificationRule({
    this.id,
    required this.type,
    required this.alarms,
    this.description,
    this.notificators,
    this.calendarId,
    this.always,
  });

  factory NotificationRule.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? {};
    final alarms = (attributes['alarms'] as String? ?? '')
        .split(',')
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toSet();
    return NotificationRule(
      id: json['id'] as int?,
      type: json['type'] as String? ?? '',
      alarms: alarms,
      description: json['description'] as String?,
      notificators: json['notificators'] as String?,
      calendarId: json['calendarId'] as int?,
      always: json['always'] as bool?,
    );
  }
}
