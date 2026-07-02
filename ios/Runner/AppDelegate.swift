import Flutter
import FirebaseCore
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private func setApplicationBadge(_ count: Int, completion: ((Error?) -> Void)? = nil) {
    let safeCount = max(0, count)
    UIApplication.shared.applicationIconBadgeNumber = safeCount
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(safeCount) { error in
        completion?(error)
      }
    } else {
      completion?(nil)
    }
  }

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
        self.setApplicationBadge(count) { error in
          DispatchQueue.main.async {
            if let error = error {
              result(FlutterError(
                code: "BADGE_UPDATE_FAILED",
                message: error.localizedDescription,
                details: nil
              ))
            } else {
              result(nil)
            }
          }
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    setApplicationBadge(0)
  }
}
