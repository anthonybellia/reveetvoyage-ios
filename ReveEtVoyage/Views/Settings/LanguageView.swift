import SwiftUI

struct LanguageView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var selected: String = "fr"
    @State private var saving: Bool = false

    let languages: [(code: String, label: String, flag: String)] = [
        ("fr", "Français", "🇫🇷"),
        ("en", "English", "🇬🇧"),
        ("nl", "Nederlands", "🇳🇱")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(languages, id: \.code) { lang in
                        languageRow(lang)
                    }
                }
                .padding(20)
            }
            .background(
                LinearGradient(colors: [Color.revYellow.opacity(0.06), Color.revBackground],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationTitle("Langue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") { dismiss() }
                }
            }
            .onAppear {
                selected = authService.currentUser?.language ?? "fr"
            }
        }
    }

    private func languageRow(_ lang: (code: String, label: String, flag: String)) -> some View {
        Button {
            Task { await pick(lang.code) }
        } label: {
            GlassCard(padding: 16) {
                HStack(spacing: 14) {
                    Text(lang.flag)
                        .font(.system(size: 32))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(lang.label)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.revText)
                        Text(lang.code.uppercased())
                            .font(.system(size: 11))
                            .foregroundColor(.revTextSecondary)
                    }

                    Spacer()

                    if saving && selected == lang.code {
                        ProgressView().tint(.revOrange)
                    } else if selected == lang.code {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.revOrange)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(saving)
    }

    private func pick(_ code: String) async {
        guard code != selected else { return }
        let previous = selected
        selected = code
        saving = true
        defer { saving = false }

        let req = UpdatePreferencesRequest(
            language: code,
            notif_emails: nil, notif_promo: nil, notif_voyages: nil
        )

        if !(await authService.updatePreferences(req)) {
            selected = previous
        }
    }
}
