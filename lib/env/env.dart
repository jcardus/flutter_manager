class Env {
  static String traccarBaseUrl = const String.fromEnvironment(
    'TRACCAR_BASE_URL',
    defaultValue: 'http://gps.frotaweb.com',
  );
}