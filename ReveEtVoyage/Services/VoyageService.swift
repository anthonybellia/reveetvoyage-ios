import Foundation

final class VoyageService {
    static let shared = VoyageService()
    private let apiClient = APIClient.shared

    private init() {}

    func getVoyages(page: Int = 1, perPage: Int = 20) async throws -> (items: [Voyage], hasMore: Bool) {
        let queryParams = ["page": String(page), "per_page": String(perPage)]
        let response: APIResponse<[Voyage]> = try await apiClient.get(
            path: APIConfig.Endpoints.voyages,
            queryParams: queryParams,
            requiresAuth: true
        )
        let items = response.data ?? []
        let hasMore: Bool
        if let meta = response.meta, let current = meta.current_page, let last = meta.last_page {
            hasMore = current < last
        } else {
            hasMore = items.count == perPage
        }
        return (items, hasMore)
    }

    func getVoyageDetail(id: Int) async throws -> Voyage {
        let response: APIResponse<Voyage> = try await apiClient.get(
            path: "\(APIConfig.Endpoints.voyages)/\(id)",
            requiresAuth: true
        )
        guard let voyage = response.data else {
            throw NetworkError.serverError(statusCode: 404, message: "Voyage introuvable")
        }
        return voyage
    }

    func toggleEtape(voyageId: Int, etapeId: Int) async throws -> VoyageEtape {
        let response: APIResponse<VoyageEtape> = try await apiClient.post(
            path: APIConfig.Endpoints.toggleEtape(voyageId: voyageId, etapeId: etapeId),
            requiresAuth: true
        )
        guard let etape = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Toggle étape échoué")
        }
        return etape
    }

    // MARK: - Admin CRUD étapes

    func createEtape(voyageId: Int, payload: EtapePayload) async throws -> VoyageEtape {
        let response: APIResponse<VoyageEtape> = try await apiClient.post(
            path: APIConfig.Endpoints.etapes(voyageId: voyageId),
            body: payload,
            requiresAuth: true
        )
        guard let etape = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Création étape échouée")
        }
        return etape
    }

    func updateEtape(voyageId: Int, etapeId: Int, payload: EtapePayload) async throws -> VoyageEtape {
        let response: APIResponse<VoyageEtape> = try await apiClient.put(
            path: APIConfig.Endpoints.etape(voyageId: voyageId, etapeId: etapeId),
            body: payload,
            requiresAuth: true
        )
        guard let etape = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Mise à jour étape échouée")
        }
        return etape
    }

    func deleteEtape(voyageId: Int, etapeId: Int) async throws {
        try await apiClient.deleteVoid(
            path: APIConfig.Endpoints.etape(voyageId: voyageId, etapeId: etapeId),
            requiresAuth: true
        )
    }
}

struct EtapePayload: Encodable {
    let type: String
    let titre: String
    let date: String?
    let heure: String?
    let lieu: String?
    let adresse: String?
    let latitude: Double?
    let longitude: Double?
    let contenu_html: String?
    let description: String?
}
