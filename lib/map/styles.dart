import 'package:flutter/material.dart';
import 'package:manager/l10n/app_localizations.dart';

class MapStyles {
  static const List<MapStyleConfig> configs = [
    MapStyleConfig(
      nameKey: 'roads',
      urlTemplate: 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&scale=2',
      subdomains: ['0', '1', '2', '3'],
      attribution: '© Google Maps',
    ),
    MapStyleConfig(
      nameKey: 'satellite',
      urlTemplate: 'https://mt{s}.google.com/vt/lyrs=s&x={x}&y={y}&z={z}&scale=2',
      subdomains: ['0', '1', '2', '3'],
      attribution: '© Google Maps',
      isDark: true,
    ),
    MapStyleConfig(
      nameKey: 'hybrid',
      urlTemplate: 'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}&scale=2',
      subdomains: ['0', '1', '2', '3'],
      attribution: '© Google Maps',
      isDark: true,
    ),
    MapStyleConfig(
      nameKey: 'traffic',
      urlTemplate: 'https://mt{s}.google.com/vt/lyrs=m,traffic&x={x}&y={y}&z={z}&scale=2',
      subdomains: ['0', '1', '2', '3'],
      attribution: '© Google Maps',
    ),
  ];
}

class MapStyleConfig {
  final String nameKey;
  final String urlTemplate;
  final List<String> subdomains;
  final String attribution;
  final bool isDark;

  const MapStyleConfig({
    required this.nameKey,
    required this.urlTemplate,
    this.subdomains = const [],
    required this.attribution,
    this.isDark = false,
  });

  String getLocalizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (nameKey) {
      case 'roads':
        return l10n.mapStyleRoads;
      case 'satellite':
        return l10n.mapStyleSatellite;
      case 'hybrid':
        return l10n.mapStyleHybrid;
      case 'traffic':
        return l10n.mapStyleTraffic;
      default:
        return nameKey;
    }
  }
}
