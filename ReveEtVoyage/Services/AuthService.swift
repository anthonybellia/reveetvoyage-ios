import Foundation

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiClient = APIClient.shared
    private let keychain = KeychainHelper.shared

    private init() {
        if apiClient.isAuthenticated() {
            isAuthenticated = true
            Task { await loadCurrentUser() }
        }
    }

    // MARK: - Login

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let body = LoginRequest(email: email, password: password, device_name: "iOS App")

        do {
            let auth: AuthResponse = try await apiClient.post(
                path: APIConfig.Endpoints.login,
                body: body
            )
            handleAuth(auth)
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
        }
    }

    // MARK: - Register

    func register(prenom: String, nom: String, email: String, password: String, passwordConfirmation: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let body = RegisterRequest(
            prenom: prenom,
            nom: nom,
            email: email,
            password: password,
            password_confirmation: passwordConfirmation,
            device_name: "iOS App"
        )

        do {
            let auth: AuthResponse = try await apiClient.post(
                path: APIConfig.Endpoints.register,
                body: body
            )
            handleAuth(auth)
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
        }
    }

    // MARK: - Sign in with Apple

    func loginWithApple() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let payload = try await AppleSignInService.shared.signIn()
            let body = AppleLoginRequest(
                identity_token: payload.identityToken,
                email: payload.email,
                first_name: payload.firstName,
                last_name: payload.lastName,
                device_token: PushService.shared.currentToken
            )
            let auth: AuthResponse = try await apiClient.post(
                path: APIConfig.Endpoints.appleLogin,
                body: body
            )
            handleAuth(auth)
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
        }
    }

    // MARK: - Sign in with Google (id_token from GIDSignIn SDK)

    func loginWithGoogle(idToken: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let body = GoogleLoginRequest(
            id_token: idToken,
            device_token: PushService.shared.currentToken
        )
        do {
            let auth: AuthResponse = try await apiClient.post(
                path: APIConfig.Endpoints.googleLogin,
                body: body
            )
            handleAuth(auth)
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
        }
    }

    // MARK: - Logout

    func logout() async {
        await PushService.shared.unregister()
        do {
            try await apiClient.postVoid(path: APIConfig.Endpoints.logout, requiresAuth: true)
        } catch {
            #if DEBUG
            print("[AuthService] Server-side logout failed: \(error)")
            #endif
        }
        clearLocalSession()
    }

    // MARK: - Refresh user

    func loadCurrentUser() async {
        do {
            let me: MeResponse = try await apiClient.get(
                path: APIConfig.Endpoints.me,
                requiresAuth: true
            )
            currentUser = me.user
            isAuthenticated = true
            keychain.saveUserId(me.user.id)
        } catch {
            clearLocalSession()
        }
    }

    // MARK: - Update profile

    func updateProfile(_ request: UpdateProfileRequest) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let me: MeResponse = try await apiClient.put(
                path: APIConfig.Endpoints.me,
                body: request,
                requiresAuth: true
            )
            currentUser = me.user
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Update password

    func updatePassword(current: String, new: String, confirm: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let body = UpdatePasswordRequest(
            current_password: current,
            password: new,
            password_confirmation: confirm
        )

        do {
            try await apiClient.postVoid(
                path: APIConfig.Endpoints.updatePassword,
                body: body,
                requiresAuth: true
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Update preferences

    func updatePreferences(_ request: UpdatePreferencesRequest) async -> Bool {
        do {
            let me: MeResponse = try await apiClient.put(
                path: APIConfig.Endpoints.updatePreferences,
                body: request,
                requiresAuth: true
            )
            currentUser = me.user
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Forgot password

    func forgotPassword(email: String) async -> Bool {
        do {
            try await apiClient.postVoid(
                path: APIConfig.Endpoints.forgotPassword,
                body: ForgotPasswordRequest(email: email)
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Helpers

    private func handleAuth(_ auth: AuthResponse) {
        apiClient.setToken(auth.token)
        keychain.saveUserId(auth.user.id)
        currentUser = auth.user
        isAuthenticated = true
        errorMessage = nil
        Task { await PushService.shared.registerIfAuthenticated() }
        LocationService.shared.startIfPermitted()
    }

    private func clearLocalSession() {
        apiClient.clearToken()
        keychain.deleteUserId()
        currentUser = nil
        isAuthenticated = false
        errorMessage = nil
    }
}

// MARK: - Request bodies

struct LoginRequest: Encodable {
    let email: String
    let password: String
    let device_name: String
}

struct RegisterRequest: Encodable {
    let prenom: String
    let nom: String
    let email: String
    let password: String
    let password_confirmation: String
    let device_name: String
}

struct ForgotPasswordRequest: Encodable {
    let email: String
}

struct UpdateProfileRequest: Encodable {
    let prenom: String?
    let nom: String?
    let phone: String?
    let date_naissance: String?
    let nationalite: String?
    let adresse: String?
    let code_postal: String?
    let ville: String?
    let pays: String?
}

struct UpdatePasswordRequest: Encodable {
    let current_password: String
    let password: String
    let password_confirmation: String
}

struct UpdatePreferencesRequest: Encodable {
    let language: String?
    let notif_emails: Bool?
    let notif_promo: Bool?
    let notif_voyages: Bool?
}

struct AppleLoginRequest: Encodable {
    let identity_token: String
    let email: String?
    let first_name: String?
    let last_name: String?
    let device_token: String?
}

struct GoogleLoginRequest: Encodable {
    let id_token: String
    let device_token: String?
}

// MARK: - Response wrappers (matching real Laravel API shapes)

struct MeResponse: Decodable {
    let user: User
}
