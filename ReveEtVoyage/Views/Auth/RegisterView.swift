import SwiftUI

struct RegisterView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Binding var showRegister: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Inscription")
                    .font(.largeTitle.bold())
                    .foregroundColor(.revBrown)
                    .padding(.top, 32)

                TextField("Prénom", text: $viewModel.prenom)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.givenName)

                TextField("Nom", text: $viewModel.nom)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.familyName)

                TextField("Email", text: $viewModel.email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)

                SecureField("Mot de passe", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)

                SecureField("Confirmer", text: $viewModel.passwordConfirmation)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.revError)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }

                Button(action: { Task { await viewModel.register() } }) {
                    Group {
                        if viewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("S'inscrire").foregroundColor(.white).fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.revOrange)
                    .cornerRadius(8)
                }
                .disabled(viewModel.isLoading)

                HStack(spacing: 10) {
                    Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.2))
                    Text("ou").font(.caption).foregroundColor(.revTextSecondary)
                    Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.2))
                }
                .padding(.vertical, 4)

                AppleSignInButton {
                    Task { await viewModel.loginWithApple() }
                }
                .frame(height: 48)

                GoogleSignInButton {
                    Task { await viewModel.loginWithGoogle() }
                }

                Button("Retour à la connexion") {
                    showRegister = false
                }
                .foregroundColor(.revBrown)
            }
            .padding()
        }
        .background(Color.revBackground.ignoresSafeArea())
    }
}
