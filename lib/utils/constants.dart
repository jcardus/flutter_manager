const categoryIcons = [
  'truck'
];

const colors = [
  'green', 'red'
];

const rotationFrames = 16;

String get traccarBaseUrl {
  const envValue = String.fromEnvironment('TRACCAR_BASE_URL');
  if (envValue.isNotEmpty) { return envValue; }
  return 'https://dash.frotaweb.com/traccar';
}

String get googleMapsSigningSecret {
  const envValue = String.fromEnvironment('GOOGLE_MAPS_SIGNING_SECRET');
  if (envValue.isNotEmpty) { return envValue; }
  return '';
}

String get googleMapsClientId {
  const envValue = String.fromEnvironment('GOOGLE_MAPS_CLIENT_ID');
  if (envValue.isNotEmpty) { return envValue; }
  return '';
}

const double selectedZoomLevel=15;
