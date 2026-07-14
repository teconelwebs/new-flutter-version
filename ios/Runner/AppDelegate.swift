import Flutter
import UIKit
import GoogleMaps
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyBcHzsB2kgoQa01PHIuYhVYeiCZlSiyXNo")

    // Required so FCM / APNs can deliver visible push notifications.
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    if !engineBridge.pluginRegistry.hasPlugin("AppLinksIosPlugin") {
      GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }
  }
}
