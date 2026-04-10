import 'package:flutter/material.dart';
import 'package:manager/l10n/app_localizations.dart';

class MapStyles {
  static const String _mapboxToken =
      'pk.eyJ1IjoiZ3VzdGF2by1mbGVldG1hcCIsImEiOiJjbWQ4bTUwZ2EwMXkyMmpzOGI0c25reGFpIn0.ftht2eo6PRXkAEWy9oQ65g';

  static const List<MapStyleConfig> configs = [
    MapStyleConfig(
      nameKey: 'google',
      urlTemplate: 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
      subdomains: ['0', '1', '2', '3'],
      attribution: '© Google Maps',
    ),
    MapStyleConfig(
      nameKey: 'mapbox',
      urlTemplate:
          'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token=$_mapboxToken',
      attribution: '© Mapbox © OpenStreetMap',
    ),
    MapStyleConfig(
      nameKey: 'satellite',
      urlTemplate: 'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
      subdomains: ['0', '1', '2', '3'],
      attribution: '© Google Maps',
      isDark: true,
    ),
    MapStyleConfig(
      nameKey: 'dark',
      urlTemplate:
          'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token=$_mapboxToken',
      attribution: '© Mapbox © OpenStreetMap',
      isDark: true,
    ),
    MapStyleConfig(
      nameKey: 'light',
      urlTemplate:
          'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/{z}/{x}/{y}?access_token=$_mapboxToken',
      attribution: '© Mapbox © OpenStreetMap',
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
      case 'mapbox':
        return l10n.mapStyleMapbox;
      case 'google':
        return l10n.mapStyleGoogle;
      case 'satellite':
        return l10n.mapStyleSatellite;
      case 'dark':
        return l10n.mapStyleDark;
      case 'light':
        return l10n.mapStyleLight;
      default:
        return nameKey;
    }
  }
}
