import SwiftUI

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var network = NetworkMonitor.shared
    @StateObject private var outbox = OfflineOutbox.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = true

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                } else if authService.isAuthenticated {
                    MainTabView()
                        .transition(.opacity)
                } else {
                    AuthFlowView()
                        .transition(.opacity)
                }
            }

            // Badge « mode hors-ligne » : visible dès que la connexion tombe,
            // une fois le splash passé. Affiche aussi les écritures à synchroniser.
            if !network.isOnline && !showSplash {
                OfflineBanner(pendingCount: outbox.pendingCount)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showSplash)
        .animation(.easeInOut(duration: 0.4), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: network.isOnline)
        .task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            showSplash = false
            // Au démarrage : rejoue d'éventuelles écritures laissées en file.
            await OfflineOutbox.shared.flush()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task { await OfflineOutbox.shared.flush() }
            }
        }
    }
}

/// Bandeau d'avertissement affiché en haut quand l'app est hors-ligne.
struct OfflineBanner: View {
    let pendingCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text(pendingCount > 0
                 ? "Mode hors-ligne — \(pendingCount) à synchroniser"
                 : "Mode hors-ligne")
                .font(.footnote.weight(.semibold))
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.95))
        .ignoresSafeArea(edges: .horizontal)
    }
}
