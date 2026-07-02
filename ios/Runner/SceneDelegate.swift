import Flutter
import UIKit
import UserNotifications

class SceneDelegate: FlutterSceneDelegate {
  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    UIApplication.shared.applicationIconBadgeNumber = 0
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(0)
    }
  }
}
