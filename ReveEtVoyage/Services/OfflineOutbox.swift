import Foundation

/// Type d'écriture différée supportée hors-ligne. Volontairement limité aux
/// actions booléennes idempotentes et sans conflit (last-write-wins) : cocher
/// une étape comme faite, cocher un article de la liste de bagages.
enum OfflineWriteKind: String, Codable {
    case etapeCompletion
    case packingCheck
}

/// Une écriture en attente de synchronisation. On mémorise l'ÉTAT CIBLE désiré
/// (pas une action relative), ce qui rend le rejeu idempotent et sûr.
struct OfflineWrite: Codable, Identifiable {
    let kind: OfflineWriteKind
    let voyageId: Int
    let entityId: Int        // etapeId ou packing itemId
    var value: Bool          // état désiré (true = fait / coché)
    var updatedAt: Date

    /// Clé stable par entité : plusieurs basculements hors-ligne se réduisent
    /// au dernier état voulu (last-write-wins).
    var id: String { "\(kind.rawValue):\(voyageId):\(entityId)" }
}

/// File d'attente persistante des écritures faites hors-ligne.
/// Stockée dans Documents (pas Caches) pour survivre à l'éviction système :
/// une écriture en attente ne doit jamais être perdue silencieusement.
@MainActor
final class OfflineOutbox: ObservableObject {
    static let shared = OfflineOutbox()

    @Published private(set) var pending: [String: OfflineWrite] = [:]
    var pendingCount: Int { pending.count }

    private let api = APIClient.shared
    private let fileURL: URL
    private var isFlushing = false

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("offline-outbox.json")
        load()
    }

    /// Enfile (ou écrase) l'écriture pour cette entité, puis tente un envoi immédiat.
    func enqueue(_ write: OfflineWrite) {
        pending[write.id] = write
        persist()
        Task { await flush() }
    }

    /// Tente d'envoyer toutes les écritures en attente, des plus anciennes aux
    /// plus récentes. Sûr à rappeler (retour réseau, passage au premier plan,
    /// démarrage). S'arrête au premier échec réseau (retry plus tard) ou sur 401.
    func flush() async {
        guard !isFlushing, !pending.isEmpty else { return }
        isFlushing = true
        defer { isFlushing = false }

        for write in pending.values.sorted(by: { $0.updatedAt < $1.updatedAt }) {
            do {
                try await send(write)
                pending.removeValue(forKey: write.id)
                persist()
            } catch NetworkError.unauthorized {
                break   // session invalide : on conserve la file, on stoppe
            } catch {
                break   // réseau indisponible : on réessaiera
            }
        }
    }

    /// Vide la file (déconnexion : ne pas rejouer les écritures sur un autre compte).
    func clearAll() {
        pending = [:]
        persist()
    }

    // MARK: - Envoi réseau (endpoints idempotents « set »)

    private func send(_ w: OfflineWrite) async throws {
        switch w.kind {
        case .etapeCompletion:
            let _: VoidResponse = try await api.put(
                path: APIConfig.Endpoints.setEtapeCompletion(voyageId: w.voyageId, etapeId: w.entityId),
                body: ["is_completed": w.value],
                requiresAuth: true
            )
        case .packingCheck:
            let _: VoidResponse = try await api.put(
                path: "/voyages/\(w.voyageId)/packing/\(w.entityId)",
                body: ["is_checked": w.value],
                requiresAuth: true
            )
        }
    }

    // MARK: - Persistance

    private func persist() {
        let writes = Array(pending.values)
        if let data = try? JSONEncoder().encode(writes) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let writes = try? JSONDecoder().decode([OfflineWrite].self, from: data) else { return }
        pending = Dictionary(uniqueKeysWithValues: writes.map { ($0.id, $0) })
    }
}
