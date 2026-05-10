import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        NavigationStack {
            List {
                if let user = authService.currentUser {
                    Section("Compte") {
                        LabeledContent("Nom", value: user.fullName)
                        LabeledContent("Email", value: user.email)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task { await authService.logout() }
                    } label: {
                        Text("Se déconnecter")
                    }
                }

                Section {
                    Text("Version 1.0 (Phase 3)")
                        .font(.caption)
                        .foregroundColor(.revTextSecondary)
                }
            }
            .navigationTitle("Paramètres")
        }
    }
}
