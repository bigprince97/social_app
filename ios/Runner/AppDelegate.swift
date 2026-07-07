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

    // Scene 模式下启动时 window 为 nil,用插件注册表拿 messenger
    // (旧写法 window?.rootViewController 导致 channel 从未注册)
    if let registrar = self.registrar(forPlugin: "OmegaChannels") {
      let messenger = registrar.messenger()
      let badgeChannel = FlutterMethodChannel(
        name: "omega/app_badge",
        binaryMessenger: messenger
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

      // 按会话清除通知中心里的已达通知(进入会话页时由 Dart 调用),
      // 匹配推送里设置的 thread-id = conversation_id
      let notifChannel = FlutterMethodChannel(
        name: "omega/notifications",
        binaryMessenger: messenger
      )
      notifChannel.setMethodCallHandler { call, result in
        guard call.method == "clearThread",
              let args = call.arguments as? [String: Any],
              let threadId = args["threadId"] as? String else {
          result(FlutterMethodNotImplemented)
          return
        }
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { notifs in
          let ids = notifs
            .filter { $0.request.content.threadIdentifier == threadId }
            .map { $0.request.identifier }
          if !ids.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: ids)
          }
          DispatchQueue.main.async { result(nil) }
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
