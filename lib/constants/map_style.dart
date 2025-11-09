import 'dart:convert';

/// Map style with Google Maps tiles and devices source
final String mapStyle = jsonEncode({
  'version': 8,
  'name': 'Map Style',
  'sources': {
    'google-maps-raster': {
      'type': 'raster',
      'tiles': [
        'https://mt0.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
        'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
        'https://mt2.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
        'https://mt3.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
      ],
      'tileSize': 256,
      'attribution': '© Google Maps',
    },
    'devices-source': {
      'type': 'geojson',
      'data': {
        'type': 'FeatureCollection',
        'features': [],
      },
    },
  },
  'layers': [
    {
      'id': 'google-maps-layer',
      'type': 'raster',
      'source': 'google-maps-raster',
      'minzoom': 0,
      'maxzoom': 22,
    },
    {
      'id': 'devices-layer',
      'type': 'circle',
      'source': 'devices-source',
      'paint': {
        'circle-radius': 8,
        'circle-color': '#FF0000',
        'circle-stroke-width': 2,
        'circle-stroke-color': '#FFFFFF',
      },
    },
  ],
});
