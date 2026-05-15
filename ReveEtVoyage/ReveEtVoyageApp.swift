import SwiftUI
import UserNotifications

/// Singleton observable that broadcasts deep-link intents from tapped notifications.
@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()
    @Published var pendingVoyageId: Int? = nil
    private init() {}
}

@main
struct ReveEtVoyageApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(AuthService.shared)
                .environmentObject(DeepLinkRouter.shared)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Display banner even when app is in foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }

    /// User tapped a notification — extract voyage_id and route.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        if let voyageId = info["voyage_id"] as? Int {
            await MainActor.run {
                DeepLinkRouter.shared.pendingVoyageId = voyageId
            }
        }
    }
}
