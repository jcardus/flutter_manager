// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Manager';

  @override
  String get signIn => 'Sign in';

  @override
  String get emailOrUsername => 'Email or Username';

  @override
  String get password => 'Password';

  @override
  String get required => 'Required';

  @override
  String get login => 'Login';

  @override
  String get loginFailed => 'Login failed';

  @override
  String get noDevicesFound => 'No devices found';

  @override
  String get waitingForData => 'Waiting for data...';

  @override
  String get total => 'Total';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get searchDevices => 'Search devices...';

  @override
  String get tryDifferentSearch => 'Try a different search term';

  @override
  String get statusUnknown => 'UNKNOWN';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String hoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String daysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String get never => 'Never';

  @override
  String get speedNotAvailable => 'N/A';

  @override
  String speedKmh(int speed) {
    return '$speed km/h';
  }

  @override
  String get user => 'User';

  @override
  String get statistics => 'Statistics';

  @override
  String get devices => 'Devices';

  @override
  String get active => 'Active';

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirmation => 'Are you sure you want to logout?';

  @override
  String get cancel => 'Cancel';

  @override
  String get mapStyleMapbox => 'Mapbox';

  @override
  String get mapStyleGoogle => 'Google';

  @override
  String get mapStyleSatellite => 'Satellite';

  @override
  String get mapStyleDark => 'Dark';

  @override
  String get mapStyleLight => 'Light';

  @override
  String get loading => 'Loading...';
}
