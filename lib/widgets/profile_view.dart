import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:manager/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/notification_rule.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/notifications_controller.dart';
import '../utils/event_display.dart';

class ProfileView extends StatefulWidget {
  final int deviceCount;
  final int activeCount;
  final bool wsConnected;
  final DateTime? wsLastMessage;
  final VoidCallback? onOpenNotifications;

  const ProfileView({
    super.key,
    required this.deviceCount,
    required this.activeCount,
    required this.wsConnected,
    this.wsLastMessage,
    this.onOpenNotifications,
  });

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _controller = NotificationsController.instance;
  bool _showAllNotifications = false;

  @override
  void initState() {
    super.initState();
    if (!_controller.rulesLoaded) {
      _controller.loadRules().ignore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authService = AuthService();

    return FutureBuilder<Map<String, dynamic>?>(
      future: authService.getUser(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        return Padding(
          padding: const EdgeInsets.only(bottom: 80),
          child: ListView(
            children: [
              const SizedBox(height: 20),
              // User Info Card
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user?['name'] ?? l10n.user,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?['email'] ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Stats Card
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.statistics,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            context: context,
                            icon: Icons.devices,
                            label: l10n.devices,
                            value: '${widget.deviceCount}',
                          ),
                          _buildStatItem(
                            context: context,
                            icon: Icons.location_on,
                            label: l10n.active,
                            value: '${widget.activeCount}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Active Notifications Card
              _buildActiveNotificationsCard(context, l10n),

              // WebSocket Status Card
              if (!kIsWeb)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WebSocket',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              widget.wsConnected ? Icons.wifi : Icons.wifi_off,
                              size: 20,
                              color: widget.wsConnected
                                  ? Theme.of(context).colorScheme.tertiary
                                  : Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.wsConnected ? 'Connected' : 'Disconnected',
                              style: TextStyle(
                                color: widget.wsConnected
                                    ? Theme.of(context).colorScheme.tertiary
                                    : Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (widget.wsLastMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Last message: ${_formatTime(widget.wsLastMessage!)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // Server URL Card
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.dns, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AuthService.baseUrl,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Show FCM Token Button (only on mobile)
              if (!kIsWeb)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton.icon(
                    onPressed: () => _showFcmToken(context),
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('Show FCM Token'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
              const SizedBox(height: 8),

              // Logout Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () => _handleLogout(context, authService),
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.logout),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),

              // Version Information
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final info = snapshot.data!;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Text(
                          'Version ${info.version} (${info.buildNumber})',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    return isToday
        ? DateFormat('HH:mm:ss').format(dt)
        : DateFormat('dd/MM HH:mm:ss').format(dt);
  }

  Future<void> _showFcmToken(BuildContext context) async {
    final token = await NotificationService().ensureToken();
    if (!context.mounted) return;

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('FCM token not available yet. Please try again in a moment.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('FCM Token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Use this token to send test notifications from Firebase Console:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            SelectableText(
              token,
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: token));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Token copied to clipboard!'),
                  duration: Duration(seconds: 2),
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, AuthService authService) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logout),
        content: Text(l10n.logoutConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Must run while the session is still valid.
      await NotificationService().unregisterTokenFromBackend();
      NotificationsController.instance.reset();
      await authService.logout();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  Widget _buildStatItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveNotificationsCard(BuildContext context, AppLocalizations l10n) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final rules = _controller.rules;
        final rulesLoaded = _controller.rulesLoaded;
        final loading = _controller.loading && !rulesLoaded;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.notifications_active,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.activeNotifications,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (rulesLoaded && rules.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${rules.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                    if (widget.onOpenNotifications != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        tooltip: l10n.notifications,
                        onPressed: widget.onOpenNotifications,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (rulesLoaded && rules.isEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.notificationsNotConfigured,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  )
                else ...[
                  ..._buildNotificationRuleItems(context, l10n, rules),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildNotificationRuleItems(
    BuildContext context,
    AppLocalizations l10n,
    List<NotificationRule> rules,
  ) {
    const limit = 4;
    final hasOverflow = rules.length > limit;
    final displayedRules = (_showAllNotifications || !hasOverflow)
        ? rules
        : rules.take(limit).toList();

    final items = <Widget>[];
    for (var i = 0; i < displayedRules.length; i++) {
      final rule = displayedRules[i];
      if (i > 0) {
        items.add(const Divider(height: 16));
      }
      items.add(_buildRuleTile(context, l10n, rule));
    }

    if (hasOverflow) {
      items.add(
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showAllNotifications = !_showAllNotifications;
                });
              },
              icon: Icon(
                _showAllNotifications ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(
                _showAllNotifications
                    ? l10n.showLess
                    : '${l10n.showMore} (${rules.length - limit})',
              ),
            ),
          ),
        ),
      );
    }

    return items;
  }

  Widget _buildRuleTile(
    BuildContext context,
    AppLocalizations l10n,
    NotificationRule rule,
  ) {
    final title = (rule.description != null && rule.description!.trim().isNotEmpty)
        ? rule.description!
        : EventDisplay.typeLabel(l10n, rule.type);
    final iconColor = EventDisplay.color(context, rule.type);
    final icon = EventDisplay.icon(rule.type);
    final channels = _parseChannels(rule.notificators);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              if (rule.type == 'alarm') ...[
                const SizedBox(height: 4),
                if (rule.alarms.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: rule.alarms.map((alarm) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          EventDisplay.alarmLabel(l10n, alarm),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      );
                    }).toList(),
                  )
                else
                  Text(
                    l10n.allAlarms,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
              if (channels.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: channels.map((channel) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 0.8,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        channel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<String> _parseChannels(String? notificators) {
    if (notificators == null || notificators.trim().isEmpty) return const [];
    return notificators
        .split(',')
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .map((n) {
          switch (n.toLowerCase()) {
            case 'firebase':
              return 'Push';
            case 'web':
              return 'Web';
            case 'mail':
              return 'Email';
            case 'sms':
              return 'SMS';
            case 'telegram':
              return 'Telegram';
            case 'traccar':
              return 'Traccar';
            default:
              return n.length > 1
                  ? n[0].toUpperCase() + n.substring(1)
                  : n.toUpperCase();
          }
        })
        .toList();
  }
}
