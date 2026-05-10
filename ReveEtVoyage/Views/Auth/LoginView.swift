import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Binding var showRegister: Bool

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Connexion")
                .font(.largeTitle.bold())
                .foregroundColor(.revBrown)

            TextField("Email", text: $viewModel.email)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)

            SecureField("Mot de passe", text: $viewModel.password)
                .textFieldStyle(.roundedBorder)
                .textContentType(.password)

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.revError)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }

            Button(action: { Task { await viewModel.login() } }) {
                Group {
                    if viewModel.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Se connecter").foregroundColor(.white).fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.revOrange)
                .cornerRadius(8)
            }
            .disabled(viewModel.isLoading)

            Button("Créer un compte") {
                showRegister = true
            }
            .foregroundColor(.revBrown)

            Spacer()
        }
        .padding()
        .background(Color.revBackground.ignoresSafeArea())
    }
}
