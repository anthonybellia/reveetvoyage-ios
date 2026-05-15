import SwiftUI

struct NotificationsSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var notifEmails: Bool = true
    @State private var notifPromo: Bool = true
    @State private var notifVoyages: Bool = true
    @State private var saving: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $notifEmails) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Emails généraux")
                                Text("Comptes, sécurité, factures")
                                    .font(.caption)
                                    .foregroundColor(.revTextSecondary)
                            }
                        } icon: {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.revOrange)
                        }
                    }

                    Toggle(isOn: $notifPromo) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Emails promotionnels")
                                Text("Bons plans, offres spéciales, newsletter")
                                    .font(.caption)
                                    .foregroundColor(.revTextSecondary)
                            }
                        } icon: {
                            Image(systemName: "tag.fill")
                                .foregroundColor(.revYellow)
                        }
                    }
                } header: {
                    Text("Communication par email")
                }

                Section {
                    Toggle(isOn: $notifVoyages) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Notifications voyage")
                                Text("Rappels J-15, J-7, J-2 et J-1 avant départ")
                                    .font(.caption)
                                    .foregroundColor(.revTextSecondary)
                            }
                        } icon: {
                            Image(systemName: "airplane.circle.fill")
                                .foregroundColor(.revRed)
                        }
                    }
                } header: {
                    Text("Notifications voyage")
                } footer: {
                    Text("On t'envoie un rappel 15 jours, 7 jours, 48h et 24h avant ton départ avec l'heure idéale d'arrivée à l'aéroport.")
                        .font(.caption)
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(colors: [Color.revYellow.opacity(0.06), Color.revBackground],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if saving { ProgressView().tint(.revOrange) }
                }
            }
            .onAppear { hydrate() }
            .onChange(of: notifEmails)  { _ in Task { await persist() } }
            .onChange(of: notifPromo)   { _ in Task { await persist() } }
            .onChange(of: notifVoyages) { _ in Task { await persist() } }
        }
    }

    private func hydrate() {
        if let user = authService.currentUser {
            notifEmails  = user.notif_emails ?? true
            notifPromo   = user.notif_promo ?? true
            notifVoyages = user.notif_voyages ?? true
        }
    }

    private func persist() async {
        guard !saving else { return }
        saving = true
        defer { saving = false }

        let req = UpdatePreferencesRequest(
            language: nil,
            notif_emails: notifEmails,
            notif_promo: notifPromo,
            notif_voyages: notifVoyages
        )
        _ = await authService.updatePreferences(req)
    }
}
