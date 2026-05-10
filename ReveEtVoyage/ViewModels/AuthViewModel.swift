import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var prenom = ""
    @Published var nom = ""
    @Published var passwordConfirmation = ""

    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        authService.$isLoading
            .assign(to: &$isLoading)
        authService.$errorMessage
            .assign(to: &$errorMessage)
    }

    func login() async {
        await authService.login(email: email, password: password)
    }

    func register() async {
        await authService.register(
            prenom: prenom,
            nom: nom,
            email: email,
            password: password,
            passwordConfirmation: passwordConfirmation
        )
    }

    func resetForm() {
        email = ""
        password = ""
        prenom = ""
        nom = ""
        passwordConfirmation = ""
    }
}
