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

    // MARK: - Membres / collaboration voyage

    /// Récupère les membres (propriétaire + collaborateurs) et les invitations
    /// en attente d'un voyage. La réponse est brute (`{members, pending}`),
    /// pas encapsulée dans `{data}`, donc on décode `VoyageMembersResponse`.
    func fetchMembers(voyageId: Int) async throws -> (members: [VoyageMember], pending: [PendingInvite]) {
        let response: VoyageMembersResponse = try await apiClient.get(
            path: "\(APIConfig.Endpoints.voyages)/\(voyageId)/members",
            requiresAuth: true
        )
        return (response.members, response.pending)
    }

    /// Invite quelqu'un par email à collaborer sur le voyage.
    /// Le backend renvoie `{ok:true, linked:true}` (utilisateur existant lié)
    /// ou `{ok:true, pending:true}` (invitation en attente). On ignore le corps
    /// utile ici : seul le succès HTTP nous intéresse. Les cas 403 (pas
    /// propriétaire/admin) et 422 (déjà propriétaire) remontent en `NetworkError`.
    func inviteMember(voyageId: Int, email: String, role: String? = "collaborator") async throws {
        let body = InviteMemberPayload(email: email, role: role)
        let _: MemberActionResponse = try await apiClient.post(
            path: "\(APIConfig.Endpoints.voyages)/\(voyageId)/members",
            body: body,
            requiresAuth: true
        )
    }

    /// Retire un membre (utilisateur lié) du voyage.
    func removeMember(voyageId: Int, userId: Int) async throws {
        let _: MemberActionResponse = try await apiClient.delete(
            path: "\(APIConfig.Endpoints.voyages)/\(voyageId)/members/\(userId)",
            requiresAuth: true
        )
    }

    // MARK: - Admin CRUD voyage

    func createVoyage(payload: VoyagePayload) async throws -> Voyage {
        let response: APIResponse<Voyage> = try await apiClient.post(
            path: APIConfig.Endpoints.voyages,
            body: payload,
            requiresAuth: true
        )
        guard let voyage = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Création voyage échouée")
        }
        return voyage
    }

    func updateVoyage(id: Int, payload: VoyagePayload) async throws -> Voyage {
        let response: APIResponse<Voyage> = try await apiClient.put(
            path: "\(APIConfig.Endpoints.voyages)/\(id)",
            body: payload,
            requiresAuth: true
        )
        guard let voyage = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Mise à jour voyage échouée")
        }
        return voyage
    }

    func deleteVoyage(id: Int) async throws {
        try await apiClient.deleteVoid(
            path: "\(APIConfig.Endpoints.voyages)/\(id)",
            requiresAuth: true
        )
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

struct InviteMemberPayload: Encodable {
    let email: String
    let role: String?
}

/// Réponse brute des endpoints membres en écriture (`POST`/`DELETE`),
/// du type `{ "ok": true, "linked"/"pending": true }`. On ne lit que `ok`.
struct MemberActionResponse: Decodable {
    let ok: Bool?
    let linked: Bool?
    let pending: Bool?
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

struct VoyagePayload: Encodable {
    let user_id: Int
    let titre: String
    let destination: String?
    let date_depart: String?
    let date_retour: String?
    let montant_total: Double
    let acompte_type: String?
    let acompte_valeur: Double?
    let statut: String?
    let description: String?
    let notes_admin: String?
}
