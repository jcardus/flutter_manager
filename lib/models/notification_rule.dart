/// A Traccar notification as configured by the user: which event type it
/// fires for and, for alarms, which alarm keys.
class NotificationRule {
  final String type;
  final Set<String> alarms;

  NotificationRule({required this.type, required this.alarms});

  factory NotificationRule.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? {};
    final alarms = (attributes['alarms'] as String? ?? '')
        .split(',')
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toSet();
    return NotificationRule(type: json['type'] as String, alarms: alarms);
  }
}
