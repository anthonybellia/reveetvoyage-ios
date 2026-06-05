import Foundation

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    /// Mode "aperçu client" : quand un admin l'active, toute l'UI réservée aux
    /// admins est masquée afin de prévisualiser l'expérience d'un voyageur normal.
    /// N'affecte JAMAIS les permissions réelles côté serveur ni le `role` réel.
    ///
    /// La valeur est persistée dans `UserDefaults` (clé `PreviewState`) pour que
    /// le client HTTP (`APIClient`, non isolé sur le MainActor) puisse la lire sans
    /// franchir de frontière d'acteur. Tout changement déclenche un rafraîchissement
    /// de la liste des voyages via la notification `.voyagesShouldRefresh`.
    @Published var previewAsUser: Bool = PreviewState.isPreviewing {
        didSet {
            guard previewAsUser != oldValue else { return }
            PreviewState.isPreviewing = previewAsUser
            NotificationCenter.default.post(name: .voyagesShouldRefresh, object: nil)
        }
    }

    /// Vrai si l'utilisateur est admin ET qu'il n'est pas en mode aperçu client.
    /// À utiliser pour TOUTES les conditions qui affichent des contrôles admin.
    /// Pour connaître le rôle réel (ex. afficher le toggle), lire `currentUser?.role`.
    var isAdmin: Bool {
        (currentUser?.role == "admin") && !previewAsUser
    }

    /// Vrai si le compte connecté est réellement admin, indépendamment du mode aperçu.
    /// Sert uniquement à décider d'afficher le bouton de bascule admin/aperçu.
    var isRealAdmin: Bool {
        currentUser?.role == "admin"
    }

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
            PreviewState.isRealAdmin = (me.user.role == "admin")
            keychain.saveUserId(me.user.id)
        } catch NetworkError.unauthorized {
            // Token réellement rejeté par le serveur (401) : on déconnecte.
            clearLocalSession()
        } catch {
            // Réseau indisponible / serveur KO : on garde la session pour le mode
            // hors-ligne (avion). Surtout ne pas effacer le token du Keychain ici,
            // sinon l'ouverture sans réseau déconnecte l'utilisateur.
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
        PreviewState.isRealAdmin = (auth.user.role == "admin")
        errorMessage = nil
        Task { await PushService.shared.registerIfAuthenticated() }
        LocationService.shared.startIfPermitted()
    }

    private func clearLocalSession() {
        apiClient.clearToken()
        keychain.deleteUserId()
        // Purge le cache hors-ligne : sur un appareil partagé, le compte suivant
        // ne doit pas voir les voyages/données mis en cache par le précédent.
        OfflineCache.shared.clearAll()
        // Idem pour les écritures en file : ne pas les rejouer sur un autre compte.
        OfflineOutbox.shared.clearAll()
        Task { await ImageCacheService.shared.clearCache() }
        LocationService.shared.stopTracking()
        currentUser = nil
        isAuthenticated = false
        errorMessage = nil
        previewAsUser = false
        PreviewState.isRealAdmin = false
    }
}

// MARK: - Preview state (partagé avec APIClient)

/// Petit miroir des deux booléens nécessaires à l'injection de l'en-tête
/// `X-Preview-As-User` côté `APIClient`. Stocké dans `UserDefaults` afin d'être
/// lisible depuis un contexte non isolé sur le MainActor (le client HTTP) sans
/// dépendre de `AuthService` (`@MainActor`).
enum PreviewState {
    private static let previewKey = "previewAsUser"
    private static let realAdminKey = "previewState.isRealAdmin"

    /// Vrai si l'admin a activé l'aperçu client.
    static var isPreviewing: Bool {
        get { UserDefaults.standard.bool(forKey: previewKey) }
        set { UserDefaults.standard.set(newValue, forKey: previewKey) }
    }

    /// Vrai si le compte connecté est réellement admin (indépendant de l'aperçu).
    static var isRealAdmin: Bool {
        get { UserDefaults.standard.bool(forKey: realAdminKey) }
        set { UserDefaults.standard.set(newValue, forKey: realAdminKey) }
    }

    /// L'en-tête `X-Preview-As-User: 1` ne doit partir QUE si un vrai admin
    /// est en mode aperçu client. Tout autre cas → aucun en-tête.
    static var shouldSendPreviewHeader: Bool {
        isRealAdmin && isPreviewing
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
