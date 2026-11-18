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

String get reportsBaseUrl {
  const envValue = String.fromEnvironment('REPORTS_BASE_URL');
  if (envValue.isNotEmpty) { return envValue; }
  // Session tokens are only valid on the issuing Traccar instance. When a brand
  // overrides TRACCAR_BASE_URL, reuse that host for reports unless explicitly set.
  const traccarEnv = String.fromEnvironment('TRACCAR_BASE_URL');
  if (traccarEnv.isNotEmpty) { return traccarEnv; }
  return 'https://clientes.frotaweb.com';
}

String get resellerApiUrl {
  const envValue = String.fromEnvironment('SUPABASE_URL');
  if (envValue.isNotEmpty) { return '$envValue/functions/v1/reseller-api'; }
  return 'https://ncaqkjpxwmufscronbpk.supabase.co/functions/v1/reseller-api';
}

const double selectedZoomLevel=14;
const int maxGeofences=100;

String get appStoreCountry {
  const envValue = String.fromEnvironment('APP_STORE_COUNTRY');
  if (envValue.isNotEmpty) { return envValue; }
  return 'br';
}

String get mapillaryBaseUrl {
  const envValue = String.fromEnvironment('MAPILLARY_BASE_URL');
  if (envValue.isNotEmpty) { return envValue; }
  return 'https://rntba7aqifqx3iywrenb7pq6km0liwsr.lambda-url.us-east-1.on.aws/pinmeapi';
}
