import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, ValueNotifier, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  dev.log('Background message received: ${message.messageId}', name: 'FCM');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  final _foregroundMessages = StreamController<RemoteMessage>.broadcast();

  /// Push messages received while the app is open. The system does not
  /// display these, so the app shows them itself.
  Stream<RemoteMessage> get foregroundMessages => _foregroundMessages.stream;

  /// Set when the user taps a push notification. The main page opens the
  /// alert it is about (or the notifications list) and resets it to null.
  final pushTapped = ValueNotifier<PushTap?>(null);

  /// Initialize Firebase Cloud Messaging
  Future<void> initialize() async {
    if (kIsWeb) {
      dev.log('Notifications not supported on web', name: 'FCM');
      return;
    }

    try {
      // Request permission for iOS
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        dev.log('User granted notification permission', name: 'FCM');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        dev.log('User granted provisional notification permission', name: 'FCM');
      } else {
        dev.log('User declined notification permission', name: 'FCM');
        return;
      }

      // Listen to token refresh — catches token even if initial fetch fails
      _fcm.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        dev.log('FCM Token refreshed: $newToken', name: 'FCM');
        registerTokenWithBackend();
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a notification. Not awaited: on iOS
      // with the UIScene lifecycle this has been known to never complete,
      // and it must not hold up the token and handlers below.
      _fcm.getInitialMessage().then(
        (message) {
          if (message != null) _handleNotificationTap(message);
        },
        onError: (Object e) =>
            dev.log('getInitialMessage failed', name: 'FCM', error: e),
      );

      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      dev.log('Notification service initialized', name: 'FCM');

      await ensureToken();
    } catch (e, stack) {
      dev.log('Error initializing notifications', name: 'FCM', error: e, stackTrace: stack);
    }
  }

  /// Returns the FCM token, fetching it if needed. On Apple platforms
  /// getToken() fails until APNS has delivered its device token, and
  /// onTokenRefresh does not reliably fire afterwards, so wait for it here.
  Future<String?> ensureToken() async {
    if (kIsWeb) return null;
    if (_fcmToken != null) return _fcmToken;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        for (var i = 0; i < 10 && await _fcm.getAPNSToken() == null; i++) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      final token = await _fcm.getToken();
      if (token != null && _fcmToken == null) {
        _fcmToken = token;
        dev.log('FCM Token: $token', name: 'FCM');
        registerTokenWithBackend();
      }
    } catch (e) {
      dev.log('FCM token not available yet', name: 'FCM', error: e);
    }
    return _fcmToken;
  }

  /// Handle messages received while app is in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    dev.log('Foreground message received: ${message.messageId}', name: 'FCM');
    dev.log('Title: ${message.notification?.title}', name: 'FCM');
    dev.log('Body: ${message.notification?.body}', name: 'FCM');
    dev.log('Data: ${message.data}', name: 'FCM');
    _foregroundMessages.add(message);
  }

  /// Handle notification tap (when user taps on notification)
  void _handleNotificationTap(RemoteMessage message) {
    dev.log('Notification tapped: ${message.messageId}', name: 'FCM');
    dev.log('Data: ${message.data}', name: 'FCM');
    pushTapped.value = PushTap.fromMessage(message);
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    if (kIsWeb) return;

    try {
      await _fcm.subscribeToTopic(topic);
      dev.log('Subscribed to topic: $topic', name: 'FCM');
    } catch (e) {
      dev.log('Error subscribing to topic $topic', name: 'FCM', error: e);
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (kIsWeb) return;

    try {
      await _fcm.unsubscribeFromTopic(topic);
      dev.log('Unsubscribed from topic: $topic', name: 'FCM');
    } catch (e) {
      dev.log('Error unsubscribing from topic $topic', name: 'FCM', error: e);
    }
  }

  /// Adds the FCM token to the Traccar user's `notificationTokens`
  /// attribute, which the server's firebase notificator sends pushes to.
  /// No-op when there is no token yet or no logged-in session.
  Future<void> registerTokenWithBackend() => _updateBackendToken(add: true);

  /// Removes the FCM token from the Traccar user so this device stops
  /// receiving their notifications. Call before the session is closed.
  Future<void> unregisterTokenFromBackend() => _updateBackendToken(add: false);

  Future<void> _updateBackendToken({required bool add}) async {
    final token = _fcmToken;
    if (kIsWeb || token == null) return;

    try {
      final headers = <String, String>{'accept': 'application/json'};
      final cookie = await AuthService().getCookie();
      if (cookie == null || cookie.isEmpty) return;
      headers['Cookie'] = cookie;

      final baseUrl = AuthService.baseUrl;
      final sessionResp =
          await http.get(Uri.parse('$baseUrl/api/session'), headers: headers);
      if (sessionResp.statusCode != 200) return;
      final user = jsonDecode(sessionResp.body) as Map<String, dynamic>;

      final attributes =
          Map<String, dynamic>.from((user['attributes'] as Map?) ?? {});
      final tokens = ((attributes['notificationTokens'] as String?) ?? '')
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      if (tokens.contains(token) == add) return;
      if (add) {
        tokens.add(token);
      } else {
        tokens.remove(token);
      }
      if (tokens.isEmpty) {
        attributes.remove('notificationTokens');
      } else {
        attributes['notificationTokens'] = tokens.join(',');
      }
      user['attributes'] = attributes;

      headers['content-type'] = 'application/json';
      final resp = await http.put(
        Uri.parse('$baseUrl/api/users/${user['id']}'),
        headers: headers,
        body: jsonEncode(user),
      );
      final action = add ? 'registration' : 'removal';
      if (resp.statusCode == 200) {
        dev.log('FCM token $action succeeded', name: 'FCM');
      } else {
        dev.log('FCM token $action failed: ${resp.statusCode} ${resp.body}',
            name: 'FCM');
      }
    } catch (e) {
      dev.log('Error updating FCM token on server', name: 'FCM', error: e);
    }
  }
}

/// A tapped push notification. Traccar's Firebase notifier puts the id of
/// the event that triggered it in the message data as `eventId`.
class PushTap {
  final int? eventId;

  const PushTap(this.eventId);

  factory PushTap.fromMessage(RemoteMessage message) =>
      PushTap(int.tryParse('${message.data['eventId'] ?? ''}'));
}
