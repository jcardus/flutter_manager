import '../l10n/app_localizations.dart';

/// The device's Traccar status (`online`, `offline`, `unknown`) in the
/// user's language, upper-cased like the status chips show it.
String deviceStatusLabel(AppLocalizations l10n, String? status) {
  final label = switch (status?.toLowerCase()) {
    'online' => l10n.online,
    'offline' => l10n.offline,
    _ => l10n.unknown,
  };
  return label.toUpperCase();
}
