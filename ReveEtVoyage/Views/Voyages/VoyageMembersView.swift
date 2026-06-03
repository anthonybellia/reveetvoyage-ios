import SwiftUI

/// Feuille de gestion des voyageurs / membres d'un voyage.
///
/// - Visible par tout membre du voyage : liste des membres + invitations en attente.
/// - Le propriétaire OU un administrateur peut en plus inviter par email
///   et retirer des membres (hors propriétaire).
///
/// Le serveur reste l'autorité finale : un 403 (pas propriétaire/admin) ou un
/// 422 (déjà propriétaire / email invalide) est affiché proprement à l'écran.
struct VoyageMembersView: View {
    let voyageId: Int
    /// Block propriétaire (présent uniquement pour les admins côté API).
    let owner: ApiOwner?

    @Environment(\.dismiss) private var dismiss

    @State private var members: [VoyageMember] = []
    @State private var pending: [PendingInvite] = []
    @State private var isLoading = false
    @State private var loadError: String? = nil

    @State private var inviteEmail: String = ""
    @State private var isInviting = false
    @State private var feedback: Feedback? = nil

    @State private var removingUserId: Int? = nil

    /// Message de retour affiché après une invitation / un retrait.
    private struct Feedback: Identifiable {
        let id = UUID()
        let text: String
        let isError: Bool
    }

    // MARK: - Gating propriétaire / admin

    private var currentUserId: Int? {
        AuthService.shared.currentUser?.id
    }

    private var isAdmin: Bool {
        AuthService.shared.isAdmin
    }

    /// Vrai si l'utilisateur courant peut gérer les membres.
    /// On combine deux signaux :
    ///  1. le block `owner` injecté par l'API pour les admins (owner.id == moi),
    ///  2. le membre marqué `is_owner` dans la liste qui correspond à mon id
    ///     (fiable même quand le block `owner` est absent, ex. propriétaire non-admin),
    ///  3. le rôle admin global.
    private var canManage: Bool {
        if isAdmin { return true }
        if let me = currentUserId, owner?.id == me { return true }
        if let me = currentUserId,
           members.contains(where: { $0.is_owner && $0.id == me }) {
            return true
        }
        return false
    }

    private var trimmedEmail: String {
        inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmitInvite: Bool {
        !isInviting && trimmedEmail.contains("@") && trimmedEmail.count >= 5
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.revYellow.opacity(0.10), Color.revBackground],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        if canManage {
                            inviteCard
                        }
                        membersCard
                        if !pending.isEmpty {
                            pendingCard
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
                .refreshable { await load() }

                if isLoading && members.isEmpty && pending.isEmpty {
                    ProgressView().tint(.revOrange)
                }
            }
            .navigationTitle("Voyageurs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                        .foregroundColor(.revOrange)
                }
            }
            .task { await load() }
        }
    }

    // MARK: - Carte invitation (propriétaire / admin uniquement)

    private var inviteCard: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Inviter un voyageur", systemImage: "person.badge.plus")

                Text("Saisis l'adresse e-mail de la personne à inviter sur ce voyage.")
                    .font(.system(size: 12))
                    .foregroundColor(.revTextSecondary)

                HStack(spacing: 10) {
                    TextField("adresse@email.com", text: $inviteEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .font(.system(size: 15))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.revCardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.revOrange.opacity(0.25), lineWidth: 1)
                        )
                }

                BrandButton(
                    title: "Inviter",
                    systemImage: "paperplane.fill",
                    isLoading: isInviting,
                    style: .primary
                ) {
                    Task { await invite() }
                }
                .disabled(!canSubmitInvite)
                .opacity(canSubmitInvite ? 1 : 0.5)

                if let feedback {
                    Text(feedback.text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(feedback.isError ? .revRed : .revOrange)
                        .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Carte liste des membres

    private var membersCard: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    title: "Membres",
                    systemImage: "person.2.fill",
                    trailing: members.isEmpty ? nil : "\(members.count)"
                )

                if let loadError {
                    Text(loadError)
                        .font(.system(size: 13))
                        .foregroundColor(.revRed)
                } else if members.isEmpty && !isLoading {
                    Text("Aucun membre pour l'instant.")
                        .font(.system(size: 13))
                        .foregroundColor(.revTextSecondary)
                        .padding(.vertical, 6)
                } else {
                    ForEach(members) { member in
                        memberRow(member)
                        if member.id != members.last?.id {
                            Divider().background(Color.gray.opacity(0.1))
                        }
                    }
                }
            }
        }
    }

    private func memberRow(_ member: VoyageMember) -> some View {
        HStack(spacing: 12) {
            AvatarView(
                firstName: firstNameOf(member.name),
                lastName: lastNameOf(member.name),
                size: 40
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(member.name.isEmpty ? member.email : member.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.revText)
                Text(member.email)
                    .font(.system(size: 12))
                    .foregroundColor(.revTextSecondary)
            }

            Spacer()

            roleBadge(isOwner: member.is_owner, role: member.role)

            // Le propriétaire/admin peut retirer un membre, sauf le propriétaire.
            if canManage && !member.is_owner {
                if removingUserId == member.id {
                    ProgressView().tint(.revRed).scaleEffect(0.7)
                        .frame(width: 28, height: 28)
                } else {
                    Button {
                        Task { await remove(member) }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.revRed)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Carte invitations en attente

    private var pendingCard: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    title: "Invitations en attente",
                    systemImage: "envelope.badge",
                    trailing: "\(pending.count)"
                )

                ForEach(pending, id: \.email) { invite in
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.revTextSecondary)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.gray.opacity(0.12)))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(invite.email)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.revTextSecondary)
                            Text("Invitation envoyée")
                                .font(.system(size: 11))
                                .foregroundColor(.revTextSecondary)
                        }

                        Spacer()
                    }
                    .opacity(0.7)
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Badge de rôle

    private func roleBadge(isOwner: Bool, role: String) -> some View {
        let label: String
        if isOwner {
            label = "Propriétaire"
        } else {
            switch role {
            case "admin": label = "Admin"
            case "collaborator": label = "Collaborateur"
            default: label = role.capitalized
            }
        }
        return Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(isOwner ? .white : .revBrown)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(
                    isOwner
                        ? AnyShapeStyle(LinearGradient(colors: [.revOrange, .revRed],
                                                       startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(Color.revYellow.opacity(0.25))
                )
            )
    }

    // MARK: - Réseau

    private func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let result = try await VoyageService.shared.fetchMembers(voyageId: voyageId)
            members = result.members
            pending = result.pending
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func invite() async {
        guard canSubmitInvite else { return }
        isInviting = true
        withAnimation { feedback = nil }
        defer { isInviting = false }
        do {
            try await VoyageService.shared.inviteMember(voyageId: voyageId, email: trimmedEmail, role: "collaborator")
            inviteEmail = ""
            withAnimation { feedback = Feedback(text: "Invitation envoyée.", isError: false) }
            await load()
        } catch {
            withAnimation { feedback = Feedback(text: inviteErrorMessage(error), isError: true) }
        }
    }

    private func remove(_ member: VoyageMember) async {
        removingUserId = member.id
        withAnimation { feedback = nil }
        defer { removingUserId = nil }
        do {
            try await VoyageService.shared.removeMember(voyageId: voyageId, userId: member.id)
            await load()
        } catch {
            withAnimation { feedback = Feedback(text: error.localizedDescription, isError: true) }
        }
    }

    /// Messages d'erreur lisibles pour les cas métier connus (403 / 422).
    private func inviteErrorMessage(_ error: Error) -> String {
        if let net = error as? NetworkError {
            switch net {
            case .serverError(let code, let message):
                if code == 403 {
                    return "Seul le propriétaire ou un administrateur peut inviter."
                }
                if code == 422 {
                    return message ?? "Cette personne est déjà propriétaire de ce voyage."
                }
                return message ?? net.localizedDescription
            default:
                return net.localizedDescription
            }
        }
        return error.localizedDescription
    }

    // MARK: - Helpers nom → initiales

    private func firstNameOf(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    private func lastNameOf(_ name: String) -> String {
        let parts = name.split(separator: " ")
        return parts.count > 1 ? String(parts[parts.count - 1]) : ""
    }
}
