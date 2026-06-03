import SwiftUI

/// Liste des notifications serveur (cloche de la Home).
/// - Charge `GET /api/notifications`, marque tout comme lu à l'ouverture
///   (`read-all`), et met à jour le badge de la cloche via `NotificationCenter`.
/// - Une notification `voyage_invite` mène vers l'écran « Mes invitations ».
/// - Conserve l'ancien raccourci « messages non lus » en tête de liste.
struct AppNotificationsView: View {
    @State private var notifications: [AppNotification] = []
    @State private var unreadMessages: Int = 0
    @State private var isLoading = false
    @State private var loadError: String? = nil
    @State private var goToInvitations = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if isLoading && notifications.isEmpty {
                    ProgressView().tint(.revOrange).padding(.top, 60)
                } else if let loadError, notifications.isEmpty && unreadMessages == 0 {
                    ErrorView(message: loadError) { Task { await load() } }
                        .padding(.top, 40)
                } else if notifications.isEmpty && unreadMessages == 0 {
                    emptyState.padding(.top, 60)
                } else {
                    if unreadMessages > 0 {
                        NavigationLink {
                            MessagesView()
                        } label: {
                            notificationCard(
                                title: "Tu as \(unreadMessages) message\(unreadMessages > 1 ? "s" : "") non lu\(unreadMessages > 1 ? "s" : "")",
                                subtitle: "L'équipe Rêve et Voyage t'a répondu",
                                icon: "envelope.badge.fill",
                                tint: .revOrange,
                                unread: true
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(notifications) { notif in
                        notificationRow(notif)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .background(
            LinearGradient(colors: [Color.revYellow.opacity(0.06), Color.revBackground],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        )
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: $goToInvitations) {
            InvitationsView()
        }
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Rows

    @ViewBuilder
    private func notificationRow(_ notif: AppNotification) -> some View {
        let card = notificationCard(
            title: notif.titre ?? "Notification",
            subtitle: notif.message ?? "",
            icon: icon(for: notif),
            tint: notif.isVoyageInvite ? .revRed : .revOrange,
            unread: !notif.lu
        )

        if notif.isVoyageInvite {
            Button {
                Task { await markRead(notif) }
                goToInvitations = true
            } label: { card }
            .buttonStyle(.plain)
        } else {
            Button {
                Task { await markRead(notif) }
            } label: { card }
            .buttonStyle(.plain)
        }
    }

    private func icon(for notif: AppNotification) -> String {
        if notif.isVoyageInvite { return "person.badge.plus" }
        switch notif.type {
        case "message": return "envelope.badge.fill"
        case "voyage", "voyage_update": return "airplane"
        case "devis": return "doc.text.fill"
        default: return "bell.fill"
        }
    }

    private func notificationCard(title: String, subtitle: String, icon: String, tint: Color, unread: Bool) -> some View {
        GlassCard(padding: 16) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        LinearGradient(colors: [tint.opacity(0.85), tint],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.revText)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.revTextSecondary)
                            .lineLimit(3)
                    }
                }
                Spacer()
                if unread {
                    Circle().fill(Color.revRed).frame(width: 8, height: 8)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.revTextSecondary.opacity(0.5))
            }
        }
        .opacity(unread ? 1 : 0.7)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bell.slash")
                .font(.system(size: 64))
                .foregroundColor(.revOrange.opacity(0.4))
            Text("Aucune notification")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.revText)
            Text("On te préviendra dès qu'il y aura du nouveau.")
                .font(.system(size: 13))
                .foregroundColor(.revTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Réseau

    private func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        // Messages non lus (raccourci conservé).
        unreadMessages = (try? await MessageService.shared.unreadCount()) ?? 0

        do {
            let result = try await NotificationService.shared.fetch()
            notifications = result.items
        } catch {
            loadError = error.localizedDescription
        }

        // Marque tout comme lu à l'ouverture et met à jour le badge cloche.
        if notifications.contains(where: { !$0.lu }) {
            try? await NotificationService.shared.markAllRead()
            for i in notifications.indices { notifications[i] = notifications[i].markedRead() }
        }
        NotificationCenter.default.post(name: .notificationsDidChange, object: nil)
    }

    private func markRead(_ notif: AppNotification) async {
        guard !notif.lu else { return }
        try? await NotificationService.shared.markRead(id: notif.id)
        if let idx = notifications.firstIndex(where: { $0.id == notif.id }) {
            notifications[idx] = notifications[idx].markedRead()
        }
        NotificationCenter.default.post(name: .notificationsDidChange, object: nil)
    }
}

private extension AppNotification {
    /// Copie marquée comme lue (les champs sont `let`, d'où une recréation).
    func markedRead() -> AppNotification {
        AppNotification(id: id, type: type, titre: titre, message: message,
                        url: url, lu: true, created_at: created_at)
    }
}

extension Notification.Name {
    /// Postée quand l'état des notifications change : le badge de la cloche
    /// (Home) doit se rafraîchir.
    static let notificationsDidChange = Notification.Name("notificationsDidChange")
}
