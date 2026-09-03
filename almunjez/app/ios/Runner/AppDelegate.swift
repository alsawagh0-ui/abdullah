import Flutter
import UIKit
import UserNotifications

/// Native side of push: asks for permission, registers with APNs, hands the
/// device token and notification taps to Dart over `almunjez/push`.
/// No Firebase: the backend outbox talks to APNs directly (doc 08 §1).
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var channel: FlutterMethodChannel?
  private var pendingToken: String?
  private var pendingRoute: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any], let route = remote["route"] as? String {
      pendingRoute = route
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    let ch = FlutterMethodChannel(name: "almunjez/push", binaryMessenger: messenger)
    channel = ch
    ch.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "requestPermission":
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
          DispatchQueue.main.async {
            if granted { UIApplication.shared.registerForRemoteNotifications() }
            result(granted)
          }
        }
      case "getToken":
        result(self.pendingToken)
      case "getInitialRoute":
        let r = self.pendingRoute
        self.pendingRoute = nil
        result(r)
      case "setBadge":
        UIApplication.shared.applicationIconBadgeNumber = (call.arguments as? Int) ?? 0
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    pendingToken = token
    channel?.invokeMethod("onToken", arguments: token)
  }

  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    channel?.invokeMethod("onTokenError", arguments: error.localizedDescription)
  }

  // Foreground: no system banner (doc 08 §8); Dart refreshes through Realtime.
  override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    channel?.invokeMethod("onForeground", arguments: notification.request.content.userInfo["route"] as? String)
    completionHandler([.badge])
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
    if let route = response.notification.request.content.userInfo["route"] as? String {
      pendingRoute = route
      channel?.invokeMethod("onTap", arguments: route)
    }
    completionHandler()
  }
}
