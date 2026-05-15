import Foundation

@MainActor
final class VoyageDetailViewModel: ObservableObject {
    @Published var voyage: Voyage?
    @Published var etapes: [VoyageEtape] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var togglingEtapeIds: Set<Int> = []

    private let voyageService = VoyageService.shared
    private let voyageId: Int

    init(voyageId: Int) {
        self.voyageId = voyageId
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let v = try await voyageService.getVoyageDetail(id: voyageId)
            voyage = v
            etapes = v.etapes ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleEtape(_ etape: VoyageEtape) async {
        togglingEtapeIds.insert(etape.id)
        defer { togglingEtapeIds.remove(etape.id) }

        // Optimistic UI: flip locally first
        if let idx = etapes.firstIndex(where: { $0.id == etape.id }) {
            etapes[idx] = etape.toggled()
        }

        do {
            let updated = try await voyageService.toggleEtape(voyageId: voyageId, etapeId: etape.id)
            if let idx = etapes.firstIndex(where: { $0.id == etape.id }) {
                etapes[idx] = updated
            }
        } catch {
            // Revert on failure
            if let idx = etapes.firstIndex(where: { $0.id == etape.id }) {
                etapes[idx] = etape
            }
            errorMessage = error.localizedDescription
        }
    }

    var progressPercent: Double {
        guard !etapes.isEmpty else { return 0 }
        let done = etapes.filter { $0.is_completed }.count
        return Double(done) / Double(etapes.count)
    }

    var completedCount: Int { etapes.filter { $0.is_completed }.count }
    var totalCount: Int { etapes.count }
}

extension VoyageEtape {
    /// Returns a copy with `is_completed` flipped — used for optimistic UI updates
    /// before the server confirms the toggle.
    func toggled() -> VoyageEtape {
        VoyageEtape(
            id: id,
            ordre: ordre,
            type: type,
            titre: titre,
            description: description,
            numero_ref: numero_ref,
            compagnie: compagnie,
            date: date,
            heure: heure,
            heure_retour: heure_retour,
            lieu: lieu,
            lieu_retour: lieu_retour,
            adresse: adresse,
            cout: cout,
            cout_note: cout_note,
            connector_mode: connector_mode,
            connector_duration: connector_duration,
            connector_distance: connector_distance,
            details: details,
            contenu_html: contenu_html,
            image: image,
            icon: icon,
            color: color,
            is_completed: !is_completed,
            completed_at: is_completed ? nil : ISO8601DateFormatter().string(from: Date())
        )
    }
}
