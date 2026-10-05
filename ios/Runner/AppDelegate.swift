import Flutter
import UIKit
import firebase_messaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // With the implicit engine (UIScene), plugins register after launch.
    // iOS needs the notification center delegate set before this returns,
    // or taps on notifications never reach the app (onMessageOpenedApp,
    // getInitialMessage).
    FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()
    // Plugins also miss firebase_messaging's own APNs registration.
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
