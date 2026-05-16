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

            // Schedule local reminders (J-15, J-7, J-2, J-1) only if user opted in
            if AuthService.shared.currentUser?.notif_voyages ?? true {
                if await NotificationManager.shared.requestAuthorizationIfNeeded() {
                    await NotificationManager.shared.scheduleVoyage(v)
                }
            } else {
                await NotificationManager.shared.cancelVoyage(v.id)
            }
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
            latitude: latitude,
            longitude: longitude,
            cout: cout,
            cout_note: cout_note,
            connector_mode: connector_mode,
            connector_duration: connector_duration,
            connector_distance: connector_distance,
            details: details,
            contenu_html: contenu_html,
            image: image,
            fichier: fichier,
            images: images,
            icon: icon,
            color: color,
            is_completed: !is_completed,
            completed_at: is_completed ? nil : ISO8601DateFormatter().string(from: Date())
        )
    }
}
