import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var saving: Bool = false
    @State private var saveError: String?
    @State private var success: Bool = false

    private var isValid: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= 8 &&
        newPassword == confirmPassword
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Mot de passe actuel", text: $currentPassword)
                        .textContentType(.password)
                } header: {
                    Text("Identification")
                }

                Section {
                    SecureField("Nouveau mot de passe", text: $newPassword)
                        .textContentType(.newPassword)
                    SecureField("Confirmer le nouveau", text: $confirmPassword)
                        .textContentType(.newPassword)
                } header: {
                    Text("Nouveau mot de passe")
                } footer: {
                    Text("Minimum 8 caractères. Tu seras déconnecté de tes autres appareils.")
                        .font(.caption)
                }

                if !newPassword.isEmpty && newPassword.count < 8 {
                    Section {
                        Label("Trop court (min 8 caractères)", systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundColor(.revRed)
                    }
                }

                if !confirmPassword.isEmpty && newPassword != confirmPassword {
                    Section {
                        Label("Les mots de passe ne correspondent pas", systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundColor(.revRed)
                    }
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .font(.caption)
                            .foregroundColor(.revRed)
                    }
                }

                if success {
                    Section {
                        Label("Mot de passe mis à jour", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(colors: [Color.revYellow.opacity(0.06), Color.revBackground],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationTitle("Changer mon mot de passe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if saving { ProgressView().tint(.revOrange) }
                        else { Text("Enregistrer").bold() }
                    }
                    .disabled(!isValid || saving)
                }
            }
        }
    }

    private func save() async {
        saving = true
        saveError = nil
        defer { saving = false }

        if await authService.updatePassword(current: currentPassword, new: newPassword, confirm: confirmPassword) {
            success = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { dismiss() }
        } else {
            saveError = authService.errorMessage ?? "Erreur de mise à jour"
        }
    }
}
