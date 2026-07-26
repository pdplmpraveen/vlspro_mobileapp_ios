import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        requestPushPermission()
        return true
    }

    // MARK: - Push Notification Permission

    private func requestPushPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            guard granted else { return }
            // Remote notifications disabled for Personal Team compatibility
            // Uncomment the following when using a paid Apple Developer account:
            // DispatchQueue.main.async {
            //     UIApplication.shared.registerForRemoteNotifications()
            // }
        }
    }

    // MARK: - APNs Token

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("[VLSPro] APNs device token: \(token)")
        // TODO: send `token` to your server so you can target this device
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[VLSPro] Failed to register for APNs: \(error.localizedDescription)")
    }

    // MARK: - Foreground notification display

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    // MARK: - Notification tap handling

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        // Post so WebViewManager can navigate to a deep-link URL if provided
        NotificationCenter.default.post(
            name: .vlsproDeepLink,
            object: nil,
            userInfo: userInfo
        )
        completionHandler()
    }
}

extension Notification.Name {
    static let vlsproDeepLink = Notification.Name("vlsproDeepLink")
}
