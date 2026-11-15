import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manager/l10n/app_localizations.dart';
import 'package:manager/models/notification_rule.dart';
import 'package:manager/services/notifications_controller.dart';
import 'package:manager/widgets/profile_view.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user': '{"name":"Test User","email":"test@example.com"}',
    });
    PackageInfo.setMockInitialValues(
      appName: 'Traccar Manager',
      packageName: 'org.traccar.manager',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    NotificationsController.instance.reset();
  });

  tearDown(() {
    NotificationsController.instance.reset();
  });

  Widget buildProfileView({VoidCallback? onOpenNotifications}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ProfileView(
          deviceCount: 5,
          activeCount: 3,
          wsConnected: true,
          wsLastMessage: DateTime.now(),
          onOpenNotifications: onOpenNotifications,
        ),
      ),
    );
  }

  testWidgets('shows empty state when no notifications are configured', (tester) async {
    NotificationsController.instance.debugSetState(rules: []);

    await tester.pumpWidget(buildProfileView());
    await tester.pumpAndSettle();

    expect(find.text('Active Notifications'), findsOneWidget);
    expect(find.text('No notifications are set up for your account'), findsOneWidget);
  });

  testWidgets('displays active notifications with icons, titles, alarms and channels', (tester) async {
    NotificationsController.instance.debugSetState(rules: [
      NotificationRule(
        type: 'ignitionOn',
        alarms: {},
        notificators: 'firebase,web',
      ),
      NotificationRule(
        type: 'alarm',
        alarms: {'sos', 'powerCut'},
        notificators: 'firebase',
      ),
      NotificationRule(
        type: 'deviceOverspeed',
        alarms: {},
        description: 'Speed Alert',
      ),
    ]);

    await tester.pumpWidget(buildProfileView());
    await tester.pumpAndSettle();

    expect(find.text('Active Notifications'), findsOneWidget);
    // Find badge container with text '3'
    expect(find.descendant(
      of: find.byType(Card),
      matching: find.text('3'),
    ), findsNWidgets(2)); // Stats activeCount=3 and notification badge=3
    expect(find.text('Ignition On'), findsOneWidget);
    expect(find.text('Alarm'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
    expect(find.text('Power cut'), findsOneWidget);
    expect(find.text('Speed Alert'), findsOneWidget);
    expect(find.text('Push'), findsWidgets);
    expect(find.text('Web'), findsOneWidget);
  });

  testWidgets('handles more than 4 notifications with show more / show less toggle', (tester) async {
    NotificationsController.instance.debugSetState(rules: [
      NotificationRule(type: 'ignitionOn', alarms: {}),
      NotificationRule(type: 'ignitionOff', alarms: {}),
      NotificationRule(type: 'deviceMoving', alarms: {}),
      NotificationRule(type: 'deviceStopped', alarms: {}),
      NotificationRule(type: 'deviceOverspeed', alarms: {}),
      NotificationRule(type: 'geofenceEnter', alarms: {}),
    ]);

    await tester.pumpWidget(buildProfileView());
    await tester.pumpAndSettle();

    expect(find.text('Active Notifications'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);

    // Initial view shows first 4 and "Show more (2)"
    expect(find.text('Ignition On'), findsOneWidget);
    expect(find.text('Ignition Off'), findsOneWidget);
    expect(find.text('Device Moving'), findsOneWidget);
    expect(find.text('Device Stopped'), findsOneWidget);
    expect(find.text('Device Overspeed'), findsNothing);

    final showMoreFinder = find.text('Show more (2)');
    await tester.ensureVisible(showMoreFinder);
    await tester.pumpAndSettle();
    expect(showMoreFinder, findsOneWidget);

    // Tap Show more
    await tester.tap(showMoreFinder);
    await tester.pumpAndSettle();

    final overspeedFinder = find.text('Device Overspeed');
    await tester.ensureVisible(overspeedFinder);
    await tester.pumpAndSettle();
    expect(overspeedFinder, findsOneWidget);
    expect(find.text('Geofence Enter'), findsOneWidget);

    final showLessFinder = find.text('Show less');
    await tester.ensureVisible(showLessFinder);
    await tester.pumpAndSettle();
    expect(showLessFinder, findsOneWidget);

    // Tap Show less
    await tester.tap(showLessFinder);
    await tester.pumpAndSettle();

    expect(find.text('Device Overspeed'), findsNothing);
    expect(find.text('Show more (2)'), findsOneWidget);
  });

  testWidgets('triggers onOpenNotifications when header arrow button is tapped', (tester) async {
    NotificationsController.instance.debugSetState(rules: [
      NotificationRule(type: 'ignitionOn', alarms: {}),
    ]);

    var opened = false;
    await tester.pumpWidget(buildProfileView(onOpenNotifications: () {
      opened = true;
    }));
    await tester.pumpAndSettle();

    final button = find.byTooltip('Notifications');
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(opened, isTrue);
  });
}
