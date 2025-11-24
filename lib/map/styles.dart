import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:manager/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;

class MapStyles {
  static const String devicesSourceId = 'devices-source';
  static const String deviceRouteSourceId = 'device-route';
  static const String layerId = 'devices-layer';
  static const String routeLayerId = 'route-layer';
  static const String clusterLayerId = 'clusters';
  static const String clusterCountLayerId = 'cluster-count';
  static const String _mapbox = 'pk.eyJ1IjoiZ3VzdGF2by1mbGVldG1hcCIsImEiOiJjbWQ4bTUwZ2EwMXkyMmpzOGI0c25reGFpIn0.ftht2eo6PRXkAEWy9oQ65g';

  // Style configurations
  static const List<MapStyleConfig> configs = [
    MapStyleConfig(
      nameKey: 'mapbox',
      type: 'mapbox-style',
      tilesOrStyleUrl: 'mapbox://styles/mapbox/streets-v12',
      attribution: '&copy; Mapbox &copy; OpenStreetMap',
    ),
    MapStyleConfig(
      nameKey: 'google',
      type: 'raster',
      tilesOrStyleUrl: [
        'https://mt0.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
        'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
        'https://mt2.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
        'https://mt3.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
      ],
      attribution: '&copy; Google Maps',
    ),
    MapStyleConfig(
      nameKey: 'satellite',
      type: 'raster',
      tilesOrStyleUrl: [
        'https://mt0.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
        'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
        'https://mt2.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
        'https://mt3.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
      ],
      attribution: '&copy; Google Maps',
      textColor: '#FFFFFF',
      textHaloColor: '#000000',
    ),
    MapStyleConfig(
      nameKey: 'dark',
      type: 'mapbox-style',
      tilesOrStyleUrl: 'mapbox://styles/mapbox/dark-v11',
      attribution: '&copy; Mapbox &copy; OpenStreetMap',
      textColor: '#FFFFFF',
      textHaloColor: '#000000',
    ),
    MapStyleConfig(
      nameKey: 'light',
      type: 'mapbox-style',
      tilesOrStyleUrl: 'mapbox://styles/mapbox/light-v11',
      attribution: '&copy; Mapbox &copy; OpenStreetMap',
      textColor: '#FFFFFF',
      textHaloColor: '#000000',
    )
  ];

  /// Generate the devices source configuration with clustering
  static Map<String, dynamic> get _devicesSource => {
    'type': 'geojson',
    'data': {
      'type': 'FeatureCollection',
      'features': [],
    },
    'cluster': true,
    'clusterRadius': 20,
    'clusterMaxZoom': 14,
  };

  static Map<String, dynamic> get _routeSource => {
    'type': 'geojson',
    'data': {
      'type': 'FeatureCollection',
      'features': [],
    }
  };

  /// Generate the cluster circles layer
  static Map<String, dynamic> _clusterLayer(MapStyleConfig config) => {
    'id': clusterLayerId,
    'type': 'circle',
    'source': devicesSourceId,
    'filter': ['has', 'point_count'],
    'paint': {
      'circle-color': [
        'step',
        ['get', 'point_count'],
        config.clusterColorSmall,
        10,
        config.clusterColorMedium,
        20,
        config.clusterColorLarge,
      ],
      'circle-radius': [
        'step',
        ['get', 'point_count'],
        20,
        10,
        25,
        20,
        25,
      ],
    },
  };

  /// Generate the cluster count layer
  static Map<String, dynamic> _clusterCountLayer(MapStyleConfig config) => {
    'id': clusterCountLayerId,
    'type': 'symbol',
    'source': devicesSourceId,
    'filter': ['has', 'point_count'],
    'layout': {
      'text-field': '{point_count_abbreviated}',
      'text-font': ['Noto Sans Regular', 'Arial Unicode MS Regular'],
      'text-size': 14,
      'text-allow-overlap': true
    },
    'paint': {
      'text-color': '#ffffff',
    },
  };

  /// Generate the devices layer configuration (for unclustered points)
  static Map<String, dynamic> _devicesLayer(MapStyleConfig config, double devicePixelRatio) => {
    'id': layerId,
    'type': 'symbol',
    'source': devicesSourceId,
    'filter': ['!', ['has', 'point_count']],
    'layout': {
      'icon-image': '{category}_{color}_{baseRotation}',
      'icon-size': devicePixelRatio,
      'text-field': '{name}',
      'text-size': 20,
      'text-font': ['Noto Sans Regular', 'Arial Unicode MS Regular'],
      'text-offset': [0, 2],
      'text-anchor': 'top',
      'icon-allow-overlap': true,
      'text-allow-overlap': true,
      'icon-rotate': ['get', 'rotate']
    },
    'paint': {
      'text-color': config.textColor,
      'text-halo-color': config.textHaloColor,
      'text-halo-width': 2,
    },
  };

  static Map<String, dynamic> _routeLayer(MapStyleConfig config, double devicePixelRatio) => {
    'source': deviceRouteSourceId,
    'id': routeLayerId,
    'type': 'line',
    'layout': {
      'line-join': 'round',
      'line-cap': 'round',
    },
    'paint': {
      'line-color': '#2196F3',
      'line-width': 3,
    },
  };


  /// Generate a complete MapLibre style JSON string from a config (for raster tiles only)
  static String generateStyleJson(MapStyleConfig config, double devicePixelRatio) {
    final Map<String, dynamic> baseSource = {
      'type': config.type,
      'tiles': config.tiles,
      'attribution': config.attribution,
      'tileSize': 256,
    };

    final style = {
      'version': 8,
      'name': config.nameKey,
      'glyphs': 'https://demotiles.maplibre.org/font/{fontstack}/{range}.pbf',
      'sources': {
        'base-map': baseSource,
        devicesSourceId: _devicesSource,
        deviceRouteSourceId: _routeSource,
      },
      'layers': [
        {
          'id': 'base-map-layer',
          'type': 'raster',
          'source': 'base-map',
          'minzoom': 0,
          'maxzoom': 22,
        },
        _routeLayer(config, devicePixelRatio),
        _clusterLayer(config),
        _clusterCountLayer(config),
        _devicesLayer(config, devicePixelRatio),
      ],
    };

    return jsonEncode(style);
  }

  /// Parse a mapbox:// URL into components
  static Map<String, String> _parseUrl(String url) {
    final regex = RegExp(r'^(\w+)://([^/?]*)(/[^?]+)?\??(.+)?');
    final match = regex.firstMatch(url);
    if (match == null) return {};

    return {
      'protocol': match.group(1) ?? '',
      'authority': match.group(2) ?? '',
      'path': match.group(3) ?? '',
      'params': match.group(4) ?? '',
    };
  }

  /// Normalize style URL
  static String _normalizeStyleURL(String url, String accessToken) {
    final parts = _parseUrl(url);
    if (parts.isEmpty) return url;

    final path = parts['path'] ?? '';
    // Remove any projection suffix
    final cleanPath = path.replaceFirst(RegExp(r'/draft$'), '');

    return 'https://api.mapbox.com/styles/v1$cleanPath?access_token=$accessToken';
  }

  /// Normalize sprite URL
  static String _normalizeSpriteURL(String url, String accessToken) {
    final parts = _parseUrl(url);
    if (parts.isEmpty) return url;

    var path = parts['path'] ?? '';
    // Handle @2x and file extensions
    final match = RegExp(r'^(.*?)(@[0-9]+x)?(\.[^.]+)?$').firstMatch(path);
    if (match != null) {
      final basePath = match.group(1) ?? '';
      final ratio = match.group(2) ?? '';
      final extension = match.group(3) ?? '.json';
      path = '$basePath/sprite$ratio$extension';
    }

    return 'https://api.mapbox.com/styles/v1$path?access_token=$accessToken';
  }

  /// Normalize glyphs URL
  static String _normalizeGlyphsURL(String url, String accessToken) {
    final parts = _parseUrl(url);
    if (parts.isEmpty) {
      dev.log('Failed to parse glyphs URL: $url');
      return url;
    }

    // For mapbox://fonts/mapbox/{fontstack}/{range}.pbf
    // path includes '/mapbox/{fontstack}/{range}.pbf'
    final path = parts['path'] ?? '';

    dev.log('Glyphs URL parts - path: $path');

    // Construct: https://api.mapbox.com/fonts/v1{path}
    // path already starts with '/', so we don't add one
    return 'https://api.mapbox.com/fonts/v1$path?access_token=$accessToken';
  }

  /// Normalize source/tile URL
  static String _normalizeSourceURL(String url, String accessToken) {
    final parts = _parseUrl(url);
    if (parts.isEmpty) return url;

    // For mapbox:// URLs, construct proper v4 tileset URL
    // mapbox://mapbox.mapbox-streets-v8 -> https://api.mapbox.com/v4/mapbox.mapbox-streets-v8.json
    final authority = parts['authority'] ?? '';
    final path = parts['path'] ?? '';

    // Combine authority and path to get the full tileset ID
    final tilesetId = path.isNotEmpty ? '$authority$path' : authority;

    return 'https://api.mapbox.com/v4/$tilesetId.json?secure&access_token=$accessToken';
  }

  /// Transform Mapbox URLs to work with MapLibre
  static String _transformMapboxUrl(String url) {
    if (!url.contains('mapbox:')) return url;

    if (url.startsWith('mapbox://styles/')) {
      return _normalizeStyleURL(url, _mapbox);
    } else if (url.startsWith('mapbox://sprites/')) {
      return _normalizeSpriteURL(url, _mapbox);
    } else if (url.startsWith('mapbox://fonts/') || url.startsWith('mapbox://glyphs/')) {
      return _normalizeGlyphsURL(url, _mapbox);
    } else if (url.startsWith('mapbox://tiles/') || url.startsWith('mapbox://')) {
      return _normalizeSourceURL(url, _mapbox);
    }

    return url;
  }

  /// Transform all Mapbox URLs in a style object
  static void _transformMapboxStyle(Map<String, dynamic> style) {
    // Remove projection.name as it causes incompatibility issues
    if (style.containsKey('projection') && style['projection'] is Map<String, dynamic>) {
      final projection = style['projection'] as Map<String, dynamic>;
      if (projection.containsKey('name')) {
        dev.log('Removing projection.name: ${projection['name']}');
        projection.remove('name');
      }
    }

    // Transform sprite URL
    if (style.containsKey('sprite') && style['sprite'] is String) {
      final transformed = _transformMapboxUrl(style['sprite'] as String);
      dev.log('Sprite: ${style['sprite']} -> $transformed');
      style['sprite'] = transformed;
    }

    // Transform glyphs URL
    if (style.containsKey('glyphs') && style['glyphs'] is String) {
      final original = style['glyphs'] as String;
      final transformed = _transformMapboxUrl(original);
      dev.log('Glyphs: $original -> $transformed');
      style['glyphs'] = transformed;
    }

    // Transform source URLs
    if (style.containsKey('sources')) {
      final sources = style['sources'] as Map<String, dynamic>;
      for (final source in sources.values) {
        if (source is Map<String, dynamic>) {
          if (source.containsKey('url') && source['url'] is String) {
            final original = source['url'] as String;
            final transformed = _transformMapboxUrl(original);
            dev.log('Source URL: $original -> $transformed');
            source['url'] = transformed;
          }
          if (source.containsKey('tiles') && source['tiles'] is List) {
            final tiles = source['tiles'] as List;
            for (int i = 0; i < tiles.length; i++) {
              if (tiles[i] is String) {
                final original = tiles[i] as String;
                final transformed = _transformMapboxUrl(original);
                dev.log('Tile[$i]: $original -> $transformed');
                tiles[i] = transformed;
              }
            }
          }
        }
      }
    }
  }

  /// Fetch a style from URL and add our devices layer
  static Future<String> _fetchAndModifyStyle(String styleUrl, MapStyleConfig config, double devicePixelRatio, {bool isMapbox = false}) async {
      final response = await http.get(Uri.parse(styleUrl));
      final style = jsonDecode(response.body) as Map<String, dynamic>;

      // Transform Mapbox URLs if needed
      if (isMapbox) {
        _transformMapboxStyle(style);
      }

      // Add our devices source
      final sources = style['sources'] as Map<String, dynamic>;
      sources[devicesSourceId] = _devicesSource;
      sources[deviceRouteSourceId] = _routeSource;

      // Add cluster layers and devices layer at the end (on top)
      final layers = style['layers'] as List<dynamic>;
      layers.add(_routeLayer(config, devicePixelRatio));
      layers.add(_clusterLayer(config));
      layers.add(_clusterCountLayer(config));
      layers.add(_devicesLayer(config, devicePixelRatio));
      return jsonEncode(style);
  }

  /// Generate the style string for a config
  static Future<String> getStyleString(MapStyleConfig config, double devicePixelRatio) async {
    // For Mapbox styles, transform the URL and fetch
    if (config.type == 'mapbox-style') {
      final transformedUrl = _transformMapboxUrl(config.styleUrl);
      return await _fetchAndModifyStyle(transformedUrl, config, devicePixelRatio, isMapbox: true);
    }
    // For other style URLs (MapTiler), fetch and modify
    if (config.isStyleUrl) {
      return await _fetchAndModifyStyle(config.styleUrl, config, devicePixelRatio);
    }
    // For raster tiles, generate the style JSON
    return generateStyleJson(config, devicePixelRatio);
  }
}

class MapStyleConfig {
  final String nameKey; // Key for localization
  final String type; // 'raster', 'style-url', or 'mapbox-style'
  final dynamic tilesOrStyleUrl; // List<String> for tiles or String for style URL
  final String attribution;
  final String textColor;
  final String textHaloColor;
  final String clusterColorSmall;
  final String clusterColorMedium;
  final String clusterColorLarge;

  const MapStyleConfig({
    required this.nameKey,
    required this.type,
    required this.tilesOrStyleUrl,
    required this.attribution,
    this.textColor = '#000000',
    this.textHaloColor = '#FFFFFF',
    this.clusterColorSmall = '#4CAF50',
    this.clusterColorMedium = '#FF9800',
    this.clusterColorLarge = '#F44336',
  });

  /// Get the localized name for this style
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

  bool get isStyleUrl => type == 'style-url';
  List<String> get tiles => tilesOrStyleUrl as List<String>;
  String get styleUrl => tilesOrStyleUrl as String;
}
