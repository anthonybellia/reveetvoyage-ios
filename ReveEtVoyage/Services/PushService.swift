import Foundation
import UIKit

/// Stores the APNs device token captured in AppDelegate and exposes register/unregister
/// helpers that talk to the backend (`POST /api/devices`, `DELETE /api/devices/{token}`).
@MainActor
final class PushService {
    static let shared = PushService()

    private(set) var currentToken: String?

    private let apiClient = APIClient.shared
    private let tokenKey = "apns_device_token"

    private init() {
        currentToken = UserDefaults.standard.string(forKey: tokenKey)
    }

    /// Stash the token (called from AppDelegate). Best-effort POST to backend if authenticated.
    func saveAndRegister(_ token: String) {
        currentToken = token
        UserDefaults.standard.set(token, forKey: tokenKey)
        Task { await registerIfAuthenticated() }
    }

    /// Re-send the stored token to the backend (call after login).
    func registerIfAuthenticated() async {
        guard let token = currentToken else { return }
        guard apiClient.isAuthenticated() else { return }

        let body = RegisterDeviceRequest(
            token: token,
            platform: "ios",
            app_version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            locale: Locale.current.language.languageCode?.identifier
        )

        do {
            try await apiClient.postVoid(
                path: APIConfig.Endpoints.devices,
                body: body,
                requiresAuth: true
            )
        } catch {
            #if DEBUG
            print("[PushService] registerDevice failed: \(error)")
            #endif
        }
    }

    /// Tell the backend to forget the device (call before logout).
    func unregister() async {
        guard let token = currentToken else { return }
        guard apiClient.isAuthenticated() else { return }

        do {
            try await apiClient.deleteVoid(
                path: APIConfig.Endpoints.deviceByToken(token),
                requiresAuth: true
            )
        } catch {
            #if DEBUG
            print("[PushService] unregister failed: \(error)")
            #endif
        }
    }

    /// Ask iOS for permission and register for remote notifications (push).
    func requestAuthorizationAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}

private struct RegisterDeviceRequest: Encodable {
    let token: String
    let platform: String
    let app_version: String?
    let locale: String?
}
