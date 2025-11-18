import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:manager/widgets/position_detail.dart';
import 'package:manager/widgets/street_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io' show Platform;

import '../l10n/app_localizations.dart';
import '../models/device.dart';
import '../models/position.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';

class DeviceDetail extends StatelessWidget {
  final Device device;
  final Position? position;
  final VoidCallback? onClose;

  const DeviceDetail({
    super.key,
    required this.device,
    required this.position,
    required this.onClose
  });

  Color _getStatusColor(BuildContext context) {
    switch (device.status?.toLowerCase()) {
      case 'online':
        return Theme.of(context).colorScheme.tertiary;
      case 'offline':
        return Theme.of(context).colorScheme.error;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  IconData _getDeviceIcon() {
    switch (device.category?.toLowerCase()) {
      case 'car':
      case 'vehicle':
        return Icons.directions_car;
      case 'truck':
        return Icons.local_shipping;
      case 'bus':
        return Icons.directions_bus;
      case 'motorcycle':
        return Icons.two_wheeler;
      case 'bicycle':
        return Icons.pedal_bike;
      case 'person':
        return Icons.person;
      default:
        return Icons.navigation;
    }
  }

  Future<void> _openDirections(BuildContext context) async {
    if (position == null) return;

    final lat = position!.latitude;
    final lng = position!.longitude;
    final color = Theme.of(context).primaryColor;

    if (Platform.isIOS) {
      // Check which map apps are available on iOS
      final availableApps = <MapApp>[];

      // Apple Maps is always available on iOS
      availableApps.add(MapApp(
        name: 'Apple Maps',
        iconWidget: FaIcon(FontAwesomeIcons.apple, color: color, size: 40),
        uri: Uri.parse('http://maps.apple.com/?daddr=$lat,$lng'),
      ));

      // Check for Google Maps
      final googleMapsUri = Uri.parse('comgooglemaps://?daddr=$lat,$lng&directionsmode=driving');
      if (await canLaunchUrl(googleMapsUri)) {
        availableApps.add(MapApp(
          name: 'Google Maps',
          iconWidget: FaIcon(FontAwesomeIcons.google, color: color, size: 40),
          uri: googleMapsUri,
          fallbackUri: Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
        ));
      }

      // Check for Waze
      final wazeUri = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
      if (await canLaunchUrl(wazeUri)) {
        availableApps.add(MapApp(
          name: 'Waze',
          iconWidget: FaIcon(FontAwesomeIcons.waze, color: color, size: 40),
          uri: wazeUri,
        ));
      }

      if (!context.mounted) return;

      // Show action sheet with available apps
      showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...availableApps.map((app) => ListTile(
                  leading: SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(child: app.iconWidget),
                  ),
                  title: Text(app.name),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      if (!await launchUrl(app.uri, mode: LaunchMode.externalApplication)) {
                        if (app.fallbackUri != null) {
                          await launchUrl(app.fallbackUri!, mode: LaunchMode.externalApplication);
                        }
                      }
                    } catch (e) {
                      if (app.fallbackUri != null) {
                        await launchUrl(app.fallbackUri!, mode: LaunchMode.externalApplication);
                      }
                    }
                  },
                )),
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        },
      );
    } else {
      // Use Google Maps on Android
      final mapUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
      try {
        final launched = await launchUrl(mapUri, mode: LaunchMode.externalApplication);
        if (!launched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open maps'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error opening maps'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  Future<void> _shareLocation(BuildContext context) async {
    if (position == null) return;

    final apiService = ApiService();

    try {
      // Calculate expiration date (24 hours from now)
      final expiration = DateTime.now().add(const Duration(hours: 24));

      // Call API service to share device
      final shareToken = await apiService.shareDevice(device.id, expiration);

      if (shareToken != null) {
        final shareUrl = '$traccarBaseUrl?token=$shareToken';
        // Use native share dialog
        await SharePlus.instance.share(
            ShareParams(uri: Uri.parse(shareUrl))
          // subject: '${device.name} location',
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create share link'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      dev.log('Error sharing location: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error creating share link'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _sendBlockCommand(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final apiService = ApiService();

    try {
      final success = await apiService.sendCommand(device.id, 'engineStop');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? l10n.blockCommandSent : l10n.blockCommandFailed),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      dev.log('Error sending block command: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.blockCommandFailed),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final l10n = AppLocalizations.of(context)!;
    final statusColor = _getStatusColor(context);
    final pos = position;

    return
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              width: 50,
              height: 2,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (pos != null) Container(
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
              child: Column(children: [
              // Street View with Title Overlay
              LayoutBuilder(
                builder: (context, constraints) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        StreetView(
                          position: pos,
                          width: constraints.maxWidth,
                        ),
                        // Title overlay with gradient background
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.7),
                                  Colors.black.withValues(alpha: 0.3),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: statusColor.withValues(alpha: 0.9),
                                  child: Icon(
                                    _getDeviceIcon(),
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        device.name,
                                        style: textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                              blurRadius: 8,
                                              color: Colors.black.withValues(alpha: 0.5),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.circle, size: 10, color: statusColor),
                                          const SizedBox(width: 6),
                                          Text(
                                            device.status?.toUpperCase() ??
                                                l10n.statusUnknown,
                                            style: textTheme.bodyMedium?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              shadows: [
                                                Shadow(
                                                  blurRadius: 4,
                                                  color: Colors.black.withValues(alpha: 0.5),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  onPressed: onClose,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              PositionDetail(pos: pos, device: device),
              const SizedBox(height: 16),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.directions,
                      label: l10n.directions,
                      onPressed: () => _openDirections(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.share_location,
                      label: l10n.share,
                      onPressed: () => _shareLocation(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.block,
                      label: l10n.block,
                      onPressed: () => _sendBlockCommand(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ]))
      ]));
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: colors.primary,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MapApp {
  final String name;
  final Widget iconWidget;
  final Uri uri;
  final Uri? fallbackUri;

  MapApp({
    required this.name,
    required this.iconWidget,
    required this.uri,
    this.fallbackUri,
  });
}

