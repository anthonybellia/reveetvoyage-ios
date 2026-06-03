import SwiftUI

/// Écran « Mes invitations » : liste les invitations en attente reçues par
/// l'utilisateur courant (`GET /api/invitations`). Chaque carte propose
/// **Accepter** / **Refuser**. À l'acceptation, la carte disparaît et la liste
/// des voyages est rafraîchie (via `NotificationCenter`).
struct InvitationsView: View {
    @State private var invitations: [VoyageInvitation] = []
    @State private var isLoading = false
    @State private var loadError: String? = nil
    /// id de voyage en cours de traitement (accept/decline) → spinner inline.
    @State private var processingId: Int? = nil
    @State private var actionError: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if isLoading && invitations.isEmpty {
                    ProgressView().tint(.revOrange).padding(.top, 60)
                } else if let loadError, invitations.isEmpty {
                    ErrorView(message: loadError) { Task { await load() } }
                        .padding(.top, 40)
                } else if invitations.isEmpty {
                    emptyState.padding(.top, 60)
                } else {
                    if let actionError {
                        Text(actionError)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.revRed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(invitations) { invite in
                        invitationCard(invite)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .background(
            LinearGradient(colors: [Color.revYellow.opacity(0.08), Color.revBackground],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        )
        .navigationTitle("Mes invitations")
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "envelope.open")
                .font(.system(size: 64))
                .foregroundColor(.revOrange.opacity(0.4))
            Text("Aucune invitation")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.revText)
            Text("Quand quelqu'un t'invite à collaborer sur un voyage, tu le verras ici.")
                .font(.system(size: 13))
                .foregroundColor(.revTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Invitation card

    private func invitationCard(_ invite: VoyageInvitation) -> some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.revYellow.opacity(0.6), .revOrange.opacity(0.6)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 48, height: 48)
                        Image(systemName: "airplane")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(-30))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(invite.voyage.titre ?? "Voyage")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.revText)
                            .lineLimit(2)

                        if let dest = invite.voyage.destination, !dest.isEmpty {
                            HStack(spacing: 5) {
                                Image(systemName: "mappin.circle.fill").font(.system(size: 11))
                                Text(dest).font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.revTextSecondary)
                        }

                        if let range = dateRange(invite) {
                            Text(range)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.revOrange)
                        }
                    }
                    Spacer()
                }

                HStack(spacing: 8) {
                    if let inviter = invite.inviter_name, !inviter.isEmpty {
                        Label("Invité par \(inviter)", systemImage: "person.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.revTextSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    roleBadge(invite.role)
                }

                if processingId == invite.voyage.id {
                    HStack {
                        Spacer()
                        ProgressView().tint(.revOrange)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack(spacing: 10) {
                        BrandButton(title: "Refuser", systemImage: "xmark", style: .ghost) {
                            Task { await decline(invite) }
                        }
                        BrandButton(title: "Accepter", systemImage: "checkmark", style: .primary) {
                            Task { await accept(invite) }
                        }
                    }
                }
            }
        }
    }

    private func roleBadge(_ role: String) -> some View {
        let label: String
        switch role {
        case "admin": label = "Admin"
        case "collaborator": label = "Collaborateur"
        default: label = role.capitalized
        }
        return Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.revBrown)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.revYellow.opacity(0.25)))
    }

    private func dateRange(_ invite: VoyageInvitation) -> String? {
        guard let depart = invite.voyage.date_depart?.toDate() else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_BE")
        f.dateFormat = "d MMM"
        let start = f.string(from: depart)
        if let retour = invite.voyage.date_retour?.toDate() {
            return "\(start) → \(f.string(from: retour))"
        }
        return start
    }

    // MARK: - Réseau

    private func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            invitations = try await VoyageService.shared.fetchInvitations()
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func accept(_ invite: VoyageInvitation) async {
        processingId = invite.voyage.id
        withAnimation { actionError = nil }
        defer { processingId = nil }
        do {
            try await VoyageService.shared.acceptInvitation(voyageId: invite.voyage.id)
            withAnimation {
                invitations.removeAll { $0.voyage.id == invite.voyage.id }
            }
            // Rafraîchit la liste des voyages (le voyage accepté y apparaît).
            NotificationCenter.default.post(name: .voyagesShouldRefresh, object: nil)
            NotificationCenter.default.post(name: .invitationsDidChange, object: nil)
        } catch {
            withAnimation { actionError = error.localizedDescription }
        }
    }

    private func decline(_ invite: VoyageInvitation) async {
        processingId = invite.voyage.id
        withAnimation { actionError = nil }
        defer { processingId = nil }
        do {
            try await VoyageService.shared.declineInvitation(voyageId: invite.voyage.id)
            withAnimation {
                invitations.removeAll { $0.voyage.id == invite.voyage.id }
            }
            NotificationCenter.default.post(name: .invitationsDidChange, object: nil)
        } catch {
            withAnimation { actionError = error.localizedDescription }
        }
    }
}

// MARK: - Notifications internes (refresh croisé)

extension Notification.Name {
    /// Postée après acceptation d'une invitation : la liste des voyages doit
    /// se recharger pour faire apparaître le voyage nouvellement partagé.
    static let voyagesShouldRefresh = Notification.Name("voyagesShouldRefresh")
    /// Postée après accept/decline : les badges « invitations en attente »
    /// doivent se rafraîchir.
    static let invitationsDidChange = Notification.Name("invitationsDidChange")
}
