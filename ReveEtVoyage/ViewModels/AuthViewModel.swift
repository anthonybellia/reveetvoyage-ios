import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var prenom = ""
    @Published var nom = ""
    @Published var passwordConfirmation = ""

    private let authService = AuthService.shared

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
