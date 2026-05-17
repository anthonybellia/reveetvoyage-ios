import Foundation

final class DevisService {
    static let shared = DevisService()
    private let apiClient = APIClient.shared

    private init() {}

    func getDevis(page: Int = 1, perPage: Int = 20) async throws -> ([Devis], Bool) {
        let queryParams = ["page": String(page), "per_page": String(perPage)]
        let response: APIResponse<[Devis]> = try await apiClient.get(
            path: APIConfig.Endpoints.devis,
            queryParams: queryParams,
            requiresAuth: true
        )
        let items = response.data ?? []
        let hasMore = items.count == perPage
        return (items, hasMore)
    }

    func getDevisDetail(id: Int) async throws -> Devis {
        let response: APIResponse<Devis> = try await apiClient.get(
            path: "\(APIConfig.Endpoints.devis)/\(id)",
            requiresAuth: true
        )
        guard let devis = response.data else {
            throw NetworkError.serverError(statusCode: 404, message: "Devis not found")
        }
        return devis
    }

    func createDevis(request: DevisCreateRequest) async throws -> Devis {
        let response: APIResponse<Devis> = try await apiClient.post(
            path: APIConfig.Endpoints.devis,
            body: request,
            requiresAuth: true
        )
        guard let devis = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Failed to create devis")
        }
        return devis
    }

    // MARK: - Admin

    func updateDevis(id: Int, payload: DevisAdminPayload) async throws -> Devis {
        let response: APIResponse<Devis> = try await apiClient.put(
            path: "\(APIConfig.Endpoints.devis)/\(id)",
            body: payload,
            requiresAuth: true
        )
        guard let devis = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Failed to update devis")
        }
        return devis
    }

    func deleteDevis(id: Int) async throws {
        try await apiClient.deleteVoid(
            path: "\(APIConfig.Endpoints.devis)/\(id)",
            requiresAuth: true
        )
    }

    func convertToVoyage(id: Int) async throws -> Int {
        struct ConvertResp: Decodable { let devis_id: Int; let voyage_id: Int }
        let response: APIResponse<ConvertResp> = try await apiClient.post(
            path: "\(APIConfig.Endpoints.devis)/\(id)/convert-to-voyage",
            requiresAuth: true
        )
        guard let r = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Conversion devis échouée")
        }
        return r.voyage_id
    }
}

struct DevisAdminPayload: Encodable {
    let destination: String?
    let destination_souhaitee: String?
    let dates_souhaitees: String?
    let duree: String?
    let nb_personnes: Int?
    let participants: String?
    let budget: String?
    let type_voyage: String?
    let message: String?
    let statut: String?
    let notes_admin: String?
    let titre_voyage: String?
    let montant_estime: Double?
    let date_depart_prevue: String?
    let date_retour_prevue: String?
}
