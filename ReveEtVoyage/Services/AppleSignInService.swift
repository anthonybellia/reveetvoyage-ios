import AuthenticationServices
import Foundation

/// Encapsulates the Sign In with Apple flow: shows the system dialog, hands back the
/// identity token + user info to whoever requested it.
@MainActor
final class AppleSignInService: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = AppleSignInService()

    private var continuation: CheckedContinuation<AppleSignInPayload, Error>?

    private override init() { super.init() }

    /// Present the Apple sign-in sheet and wait for the user's choice.
    func signIn() async throws -> AppleSignInPayload {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            controller.performRequests()
        }
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        defer { continuation = nil }

        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let identityToken = String(data: tokenData, encoding: .utf8)
        else {
            continuation?.resume(throwing: AppleSignInError.missingToken)
            return
        }

        let payload = AppleSignInPayload(
            identityToken: identityToken,
            userId: credential.user,
            email: credential.email,
            firstName: credential.fullName?.givenName,
            lastName: credential.fullName?.familyName
        )
        continuation?.resume(returning: payload)
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        defer { continuation = nil }
        continuation?.resume(throwing: error)
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
            ?? ASPresentationAnchor()
    }
}

struct AppleSignInPayload {
    let identityToken: String
    let userId: String
    let email: String?
    let firstName: String?
    let lastName: String?
}

enum AppleSignInError: LocalizedError {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken: return "Apple n'a pas retourné de jeton valide."
        }
    }
}
