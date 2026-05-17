import Foundation

final class FactureService {
    static let shared = FactureService()
    private let apiClient = APIClient.shared

    private init() {}

    func listFactures(page: Int = 1, perPage: Int = 20) async throws -> (items: [Facture], hasMore: Bool) {
        let queryParams = ["page": String(page), "per_page": String(perPage)]
        let response: APIResponse<[Facture]> = try await apiClient.get(
            path: "/factures",
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

    func getFacture(id: Int) async throws -> Facture {
        let response: APIResponse<Facture> = try await apiClient.get(
            path: "/factures/\(id)",
            requiresAuth: true
        )
        guard let f = response.data else {
            throw NetworkError.serverError(statusCode: 404, message: "Facture introuvable")
        }
        return f
    }

    func createFacture(payload: FacturePayload) async throws -> Facture {
        let response: APIResponse<Facture> = try await apiClient.post(
            path: "/factures",
            body: payload,
            requiresAuth: true
        )
        guard let f = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Création facture échouée")
        }
        return f
    }

    func updateFacture(id: Int, payload: FacturePayload) async throws -> Facture {
        let response: APIResponse<Facture> = try await apiClient.put(
            path: "/factures/\(id)",
            body: payload,
            requiresAuth: true
        )
        guard let f = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Mise à jour facture échouée")
        }
        return f
    }

    func deleteFacture(id: Int) async throws {
        try await apiClient.deleteVoid(path: "/factures/\(id)", requiresAuth: true)
    }

    func updateStatut(id: Int, statut: String) async throws -> Facture {
        struct Body: Encodable { let statut: String }
        let response: APIResponse<Facture> = try await apiClient.request(
            method: "PATCH",
            path: "/factures/\(id)/statut",
            body: Body(statut: statut),
            requiresAuth: true
        )
        guard let f = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Statut non mis à jour")
        }
        return f
    }

    func fromDevis(devisId: Int) async throws -> Facture {
        let response: APIResponse<Facture> = try await apiClient.post(
            path: "/factures/from-devis/\(devisId)",
            requiresAuth: true
        )
        guard let f = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Conversion en facture échouée")
        }
        return f
    }
}

struct FacturePayload: Encodable {
    let devis_id: Int?
    let voyage_id: Int?
    let user_id: Int?
    let client_nom: String
    let client_email: String?
    let client_adresse: String?
    let client_ville: String?
    let client_code_postal: String?
    let client_pays: String?
    let communication: String?
    let lignes: [FactureLignePayload]
    let tva_pct: Double?
    let statut: String?
    let notes: String?
    let date_emission: String
    let date_echeance: String?
}

struct FactureLignePayload: Encodable {
    let description: String
    let reference: String?
    let quantite: Double
    let prix_unitaire: Double
}
