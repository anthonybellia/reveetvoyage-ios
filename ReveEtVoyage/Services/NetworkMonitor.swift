import Foundation
import Network

/// Observe l'état de la connexion réseau et déclenche la re-synchronisation de
/// l'outbox dès que la connectivité revient. Exposé en `ObservableObject` pour
/// piloter le badge « mode hors-ligne ».
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    /// `true` tant qu'aucune interface satisfaisante n'est détectée → mode avion / pas de réseau.
    @Published private(set) var isOnline: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "be.reveetvoyage.networkmonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = (path.status == .satisfied)
            Task { @MainActor in
                guard let self else { return }
                let cameBackOnline = (online && !self.isOnline)
                self.isOnline = online
                if cameBackOnline {
                    // Réseau retrouvé : on rejoue les écritures mises en file hors-ligne.
                    await OfflineOutbox.shared.flush()
                }
            }
        }
        monitor.start(queue: queue)
    }
}
