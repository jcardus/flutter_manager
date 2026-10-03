import 'dart:convert';
import 'dart:developer' as dev;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

      // Try to get FCM token, but don't block if APNS isn't ready
      try {
        _fcmToken = await _fcm.getToken();
        if (_fcmToken != null) {
          dev.log('FCM Token: $_fcmToken', name: 'FCM');
          registerTokenWithBackend();
        }
      } catch (e) {
        dev.log('FCM token not available yet, will get via onTokenRefresh', name: 'FCM');
      }

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a notification
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      dev.log('Notification service initialized', name: 'FCM');
    } catch (e, stack) {
      dev.log('Error initializing notifications', name: 'FCM', error: e, stackTrace: stack);
    }
  }

  /// Handle messages received while app is in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    dev.log('Foreground message received: ${message.messageId}', name: 'FCM');
    dev.log('Title: ${message.notification?.title}', name: 'FCM');
    dev.log('Body: ${message.notification?.body}', name: 'FCM');
    dev.log('Data: ${message.data}', name: 'FCM');

    // TODO: Show in-app notification or update UI
  }

  /// Handle notification tap (when user taps on notification)
  void _handleNotificationTap(RemoteMessage message) {
    dev.log('Notification tapped: ${message.messageId}', name: 'FCM');
    dev.log('Data: ${message.data}', name: 'FCM');

    // TODO: Navigate to relevant screen based on notification data
    // For example, if notification contains deviceId, navigate to device details
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
