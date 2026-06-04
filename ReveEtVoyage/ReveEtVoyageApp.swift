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
                .onOpenURL { url in
                    _ = GoogleSignInHelper.shared.handle(url)
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Cache disque large pour les images : AsyncImage utilise URLCache.shared.
        // Permet d'afficher hors-ligne (mode avion) les images déjà chargées en
        // ligne. À configurer avant tout premier usage du cache.
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,    // 50 Mo en mémoire
            diskCapacity: 500 * 1024 * 1024,     // 500 Mo sur disque
            diskPath: "rev_image_cache"
        )
        UNUserNotificationCenter.current().delegate = self
        DispatchQueue.main.async {
            PushService.shared.requestAuthorizationAndRegister()
            if APIClient.shared.isAuthenticated() {
                LocationService.shared.startIfPermitted()
            }
        }
        return true
    }

    /// Apple gave us a device token — pass it to PushService.
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in
            PushService.shared.saveAndRegister(token)
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("[AppDelegate] APNs registration failed: \(error)")
        #endif
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
