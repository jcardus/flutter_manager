import 'dart:developer' as dev;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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

      // Get FCM token
      _fcmToken = await _fcm.getToken();
      if (_fcmToken != null) {
        dev.log('FCM Token: $_fcmToken', name: 'FCM');
        // TODO: Send token to backend to register device
      }

      // Listen to token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        dev.log('FCM Token refreshed: $newToken', name: 'FCM');
        // TODO: Send new token to backend
      });

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

  /// Send FCM token to backend
  Future<void> registerTokenWithBackend() async {
    if (_fcmToken == null) return;

    // TODO: Implement API call to send token to backend
    // Example:
    // await ApiService().registerFcmToken(_fcmToken!);
    dev.log('TODO: Send FCM token to backend: $_fcmToken', name: 'FCM');
  }
}
