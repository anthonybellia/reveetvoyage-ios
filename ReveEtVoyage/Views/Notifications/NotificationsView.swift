import SwiftUI

struct NotificationsView: View {
    @State private var unreadMessages: Int = 0
    @State private var loaded: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if !loaded {
                    ProgressView().padding(.top, 60)
                } else if unreadMessages == 0 {
                    emptyState
                        .padding(.top, 60)
                } else {
                    NavigationLink {
                        MessagesView()
                    } label: {
                        notificationCard(
                            title: "Tu as \(unreadMessages) message\(unreadMessages > 1 ? "s" : "") non lu\(unreadMessages > 1 ? "s" : "")",
                            subtitle: "L'équipe Rêve et Voyage t'a répondu",
                            icon: "envelope.badge.fill",
                            tint: .revOrange
                        )
                    }
                    .buttonStyle(.plain)
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
        .task { await loadCounts() }
        .refreshable { await loadCounts() }
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

    private func notificationCard(title: String, subtitle: String, icon: String, tint: Color) -> some View {
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
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.revTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.revTextSecondary)
            }
        }
    }

    private func loadCounts() async {
        do {
            unreadMessages = try await MessageService.shared.unreadCount()
        } catch {
            unreadMessages = 0
        }
        loaded = true
    }
}
