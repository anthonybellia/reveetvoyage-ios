import Foundation
import UIKit
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

/// Wraps GIDSignIn for SwiftUI. Reads the iOS OAuth client ID from `GIDClientID`
/// in Info.plist. The corresponding URL scheme must be declared in `CFBundleURLTypes`.
@MainActor
final class GoogleSignInHelper {
    static let shared = GoogleSignInHelper()
    private init() {}

    enum GoogleSignInError: LocalizedError {
        case sdkMissing
        case clientIdMissing
        case noPresenter
        case noIdToken
        case cancelled

        var errorDescription: String? {
            switch self {
            case .sdkMissing:    return "Google Sign-In SDK manquant. Lance `xcodegen generate` puis rebuild."
            case .clientIdMissing: return "GIDClientID absent de Info.plist."
            case .noPresenter:   return "Impossible d'afficher la fenêtre Google."
            case .noIdToken:     return "Google n'a pas retourné de jeton."
            case .cancelled:     return "Connexion Google annulée."
            }
        }
    }

    /// Trigger the Google Sign-In sheet; returns the ID token to send to the backend.
    func signIn() async throws -> String {
        #if canImport(GoogleSignIn)
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            throw GoogleSignInError.clientIdMissing
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presenter = Self.topMostViewController() else {
            throw GoogleSignInError.noPresenter
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)

        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleSignInError.noIdToken
        }
        return idToken
        #else
        throw GoogleSignInError.sdkMissing
        #endif
    }

    /// Handle the OAuth redirect URL coming back into the app.
    func handle(_ url: URL) -> Bool {
        #if canImport(GoogleSignIn)
        return GIDSignIn.sharedInstance.handle(url)
        #else
        return false
        #endif
    }

    private static func topMostViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        guard var top = keyWindow?.rootViewController else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
