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
            let response: APIResponse<AuthResponse> = try await apiClient.post(
                path: APIConfig.Endpoints.login,
                body: body
            )
            try handleAuthResponse(response)
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
            let response: APIResponse<AuthResponse> = try await apiClient.post(
                path: APIConfig.Endpoints.register,
                body: body
            )
            try handleAuthResponse(response)
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
        }
    }

    // MARK: - Logout

    func logout() async {
        do {
            try await apiClient.postVoid(path: APIConfig.Endpoints.logout, requiresAuth: true)
        } catch {
            #if DEBUG
            print("[AuthService] Server-side logout failed (clearing local state anyway): \(error)")
            #endif
        }
        clearLocalSession()
    }

    // MARK: - Refresh user

    func loadCurrentUser() async {
        do {
            let response: APIResponse<User> = try await apiClient.get(
                path: APIConfig.Endpoints.me,
                requiresAuth: true
            )
            if let user = response.data {
                currentUser = user
                isAuthenticated = true
                keychain.saveUserId(user.id)
            }
        } catch {
            // Token invalid or network error — drop local session
            clearLocalSession()
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

    private func handleAuthResponse(_ response: APIResponse<AuthResponse>) throws {
        guard let auth = response.data else {
            errorMessage = response.message ?? "Réponse d'authentification invalide"
            isAuthenticated = false
            throw NetworkError.serverError(statusCode: 200, message: response.message)
        }
        apiClient.setToken(auth.token)
        keychain.saveUserId(auth.user.id)
        currentUser = auth.user
        isAuthenticated = true
        errorMessage = nil
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
