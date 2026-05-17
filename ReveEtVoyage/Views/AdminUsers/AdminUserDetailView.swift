import SwiftUI

struct AdminUserDetailView: View {
    @State private var user: AdminUser
    let onChange: (AdminUser?) -> Void
    @State private var showEditSheet: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @Environment(\.dismiss) private var dismiss

    init(user: AdminUser, onChange: @escaping (AdminUser?) -> Void) {
        _user = State(initialValue: user)
        self.onChange = onChange
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                heroCard
                detailsCard
                if user.voyages_count != nil || user.passengers_count != nil {
                    statsCard
                }
            }
            .padding(18)
        }
        .background(
            LinearGradient(colors: [Color.revYellow.opacity(0.06), Color.revBackground],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        )
        .navigationTitle(user.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showEditSheet = true } label: { Label("Modifier", systemImage: "pencil") }
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill").foregroundColor(.revOrange)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AdminUserFormSheet(mode: .edit(user)) { updated in
                user = updated
                onChange(updated)
            }
        }
        .confirmationDialog("Supprimer cet utilisateur ?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                Task {
                    try? await UserAdminService.shared.delete(id: user.id)
                    onChange(nil)
                    dismiss()
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("\(user.fullName) sera supprimé définitivement.")
        }
        .task { await refresh() }
    }

    private var heroCard: some View {
        GlassCard(padding: 16) {
            VStack(spacing: 12) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [.revYellow, .revOrange],
                                                 startPoint: .top, endPoint: .bottom))
                        .frame(width: 72, height: 72)
                    Text(initials)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                }
                Text(user.fullName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.revText)
                Text(roleLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Capsule().fill(roleColor))
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var detailsCard: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(title: "Coordonnées", systemImage: "envelope.fill")
                row("Email", user.email)
                if let p = user.phone, !p.isEmpty { row("Téléphone", p) }
                if let a = user.adresse, !a.isEmpty { row("Adresse", a) }
                let city = [user.code_postal, user.ville, user.pays].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
                if !city.isEmpty { row("Ville", city) }
                if let l = user.language, !l.isEmpty { row("Langue", l.uppercased()) }
                if let last = user.last_login_at, let f = formatRelative(last) {
                    row("Dernière connexion", f)
                }
            }
        }
    }

    private var statsCard: some View {
        GlassCard(padding: 14) {
            HStack(spacing: 24) {
                stat("Voyages", value: user.voyages_count ?? 0, icon: "airplane.circle.fill")
                stat("Passagers", value: user.passengers_count ?? 0, icon: "person.2.fill")
                Spacer()
            }
        }
    }

    private func stat(_ label: String, value: Int, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.revTextSecondary)
            Text("\(value)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.revOrange)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12)).foregroundColor(.revTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.revText)
                .multilineTextAlignment(.trailing)
        }
    }

    private func refresh() async {
        if let fresh = try? await UserAdminService.shared.get(id: user.id) {
            user = fresh
        }
    }

    private var initials: String {
        let first = (user.prenom?.first).map(String.init) ?? ""
        let second = user.name.first.map(String.init) ?? ""
        let result = (first + second).uppercased()
        return result.isEmpty ? "?" : result
    }

    private var roleColor: Color {
        switch user.role {
        case "admin": return .red
        case "moderator": return .blue
        default: return .revOrange
        }
    }

    private var roleLabel: String {
        switch user.role {
        case "admin": return "Administrateur"
        case "moderator": return "Modérateur"
        case "customer": return "Client"
        default: return user.role.capitalized
        }
    }

    private func formatRelative(_ iso: String) -> String? {
        let f = ISO8601DateFormatter()
        guard let date = f.date(from: iso) else { return nil }
        let rf = RelativeDateTimeFormatter()
        rf.locale = Locale(identifier: "fr_FR")
        return rf.localizedString(for: date, relativeTo: Date())
    }
}
