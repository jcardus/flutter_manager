const categoryIcons = [
  'truck', 'car', 'person'
];

const colors = [
  'green', 'red', 'yellow', 'grey'
];

const rotationFrames = 16;

String get traccarBaseUrl {
  const envValue = String.fromEnvironment('TRACCAR_BASE_URL');
  if (envValue.isNotEmpty) { return envValue; }
  return 'https://dash.frotaweb.com/traccar';
}

String get resellerApiUrl {
  const envValue = String.fromEnvironment('SUPABASE_URL');
  if (envValue.isNotEmpty) { return '$envValue/functions/v1/reseller-api'; }
  return 'https://ncaqkjpxwmufscronbpk.supabase.co/functions/v1/reseller-api';
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

const double selectedZoomLevel=14;
const int maxGeofences=100;

String get appStoreCountry {
  const envValue = String.fromEnvironment('APP_STORE_COUNTRY');
  if (envValue.isNotEmpty) { return envValue; }
  return 'br';
}

String get mapillaryToken {
  const envValue = String.fromEnvironment('MAPILLARY_TOKEN');
  if (envValue.isNotEmpty) { return envValue; }
  return '';
}
