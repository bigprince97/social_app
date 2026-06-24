import Flutter
import FirebaseCore
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    UNUserNotificationCenter.current().delegate = self
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let badgeChannel = FlutterMethodChannel(
        name: "omega/app_badge",
        binaryMessenger: controller.binaryMessenger
      )
      badgeChannel.setMethodCallHandler { call, result in
        guard call.method == "setBadgeCount" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let args = call.arguments as? [String: Any]
        let count = max(0, args?["count"] as? Int ?? 0)
        UIApplication.shared.applicationIconBadgeNumber = count
        result(nil)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
