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

            preloadImages(etapes: v.etapes ?? [])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleEtape(_ etape: VoyageEtape) async {
        togglingEtapeIds.insert(etape.id)
        defer { togglingEtapeIds.remove(etape.id) }

        let desired = !etape.is_completed

        // Optimistic UI: flip locally first
        if let idx = etapes.firstIndex(where: { $0.id == etape.id }) {
            etapes[idx] = etape.toggled()
        }

        do {
            // Endpoint idempotent « set » : rejouable sans risque par l'outbox.
            let updated = try await voyageService.setEtapeCompletion(
                voyageId: voyageId, etapeId: etape.id, isCompleted: desired)
            if let idx = etapes.firstIndex(where: { $0.id == etape.id }) {
                etapes[idx] = updated
            }
        } catch NetworkError.unauthorized {
            // Session réellement invalide : on annule l'optimiste.
            if let idx = etapes.firstIndex(where: { $0.id == etape.id }) {
                etapes[idx] = etape
            }
            errorMessage = NetworkError.unauthorized.errorDescription
        } catch {
            // Hors-ligne / serveur injoignable : on GARDE l'état optimiste et on
            // met l'écriture en file pour re-synchroniser au retour du réseau.
            OfflineOutbox.shared.enqueue(
                OfflineWrite(kind: .etapeCompletion, voyageId: voyageId,
                             entityId: etape.id, value: desired, updatedAt: Date())
            )
        }
    }

    var progressPercent: Double {
        guard !etapes.isEmpty else { return 0 }
        let done = etapes.filter { $0.is_completed }.count
        return Double(done) / Double(etapes.count)
    }

    var completedCount: Int { etapes.filter { $0.is_completed }.count }
    var totalCount: Int { etapes.count }

    // MARK: - Image Preloading

    private func preloadImages(etapes: [VoyageEtape]) {
        Task.detached(priority: .utility) {
            var urls: [URL] = []
            let base = APIConfig.baseURL.absoluteString.replacingOccurrences(of: "/api", with: "")

            for etape in etapes {
                if let cover = etape.coverImage {
                    if let url = Self.absoluteURL(cover, base: base) { urls.append(url) }
                }
                for img in etape.allImages {
                    if let url = Self.absoluteURL(img, base: base) { urls.append(url) }
                }
                if let tickets = etape.tickets {
                    for ticket in tickets where ticket.is_image {
                        if let url = Self.absoluteURL(ticket.url, base: base) { urls.append(url) }
                    }
                }
            }

            await ImageCacheService.shared.preload(urls: urls)
        }
    }

    private static func absoluteURL(_ path: String, base: String) -> URL? {
        if path.hasPrefix("http") { return URL(string: path) }
        return URL(string: base + (path.hasPrefix("/") ? path : "/" + path))
    }

    // MARK: - Admin CRUD

    func upsertEtape(_ etape: VoyageEtape) {
        if let idx = etapes.firstIndex(where: { $0.id == etape.id }) {
            etapes[idx] = etape
        } else {
            etapes.append(etape)
            etapes.sort { $0.ordre < $1.ordre }
        }
    }

    func deleteEtape(_ etape: VoyageEtape) async {
        do {
            try await voyageService.deleteEtape(voyageId: voyageId, etapeId: etape.id)
            etapes.removeAll { $0.id == etape.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
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
            cover: cover,
            fichier: fichier,
            images: images,
            tickets: tickets,
            icon: icon,
            color: color,
            is_completed: !is_completed,
            completed_at: is_completed ? nil : ISO8601DateFormatter().string(from: Date())
        )
    }
}
