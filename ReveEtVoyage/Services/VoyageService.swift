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

    /// Fixe explicitement l'état terminé d'une étape (idempotent).
    /// Préféré au toggle pour l'optimiste + la file hors-ligne : rejouable
    /// sans risque même si l'état serveur a changé entre-temps.
    @discardableResult
    func setEtapeCompletion(voyageId: Int, etapeId: Int, isCompleted: Bool) async throws -> VoyageEtape {
        let response: APIResponse<VoyageEtape> = try await apiClient.put(
            path: APIConfig.Endpoints.setEtapeCompletion(voyageId: voyageId, etapeId: etapeId),
            body: ["is_completed": isCompleted],
            requiresAuth: true
        )
        guard let etape = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Mise à jour étape échouée")
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

    // MARK: - Invitation : autocomplete & réponses

    /// Recherche un utilisateur par email **exact** (autocomplete invitation).
    /// Renvoie `nil` si aucun compte ne correspond (`{ data: null }`), auquel cas
    /// l'invitation se fera par email simple via `inviteMember`.
    func searchUser(email: String) async throws -> UserSearchResult? {
        let response: APIResponse<UserSearchResult> = try await apiClient.get(
            path: APIConfig.Endpoints.usersSearch,
            queryParams: ["email": email],
            requiresAuth: true
        )
        return response.data
    }

    /// Liste les invitations en attente reçues par l'utilisateur courant.
    func fetchInvitations() async throws -> [VoyageInvitation] {
        let response: InvitationsResponse = try await apiClient.get(
            path: APIConfig.Endpoints.invitations,
            requiresAuth: true
        )
        return response.data
    }

    /// Accepte l'invitation au voyage donné. Renvoie `true` si le compte a bien
    /// été lié au voyage (`linked`).
    @discardableResult
    func acceptInvitation(voyageId: Int) async throws -> Bool {
        let response: InvitationActionResponse = try await apiClient.post(
            path: APIConfig.Endpoints.acceptInvitation(voyageId: voyageId),
            requiresAuth: true
        )
        return response.linked ?? (response.ok ?? false)
    }

    /// Refuse l'invitation au voyage donné.
    func declineInvitation(voyageId: Int) async throws {
        let _: InvitationActionResponse = try await apiClient.post(
            path: APIConfig.Endpoints.declineInvitation(voyageId: voyageId),
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

    // MARK: - Étape : couverture & billets (multipart)

    /// Upload / remplace l'image de couverture de l'étape. Renvoie l'étape mise à jour.
    func uploadEtapeCover(
        voyageId: Int,
        etapeId: Int,
        imageData: Data,
        fileName: String = "cover.jpg",
        mimeType: String = "image/jpeg"
    ) async throws -> VoyageEtape {
        let response: APIResponse<VoyageEtape> = try await apiClient.uploadMultipart(
            method: "POST",
            path: APIConfig.Endpoints.etapeCover(voyageId: voyageId, etapeId: etapeId),
            fieldName: "cover",
            fileData: imageData,
            fileName: fileName,
            mimeType: mimeType,
            requiresAuth: true
        )
        guard let etape = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Upload couverture échoué")
        }
        return etape
    }

    /// Ajoute un billet (PDF ou image) à l'étape. Renvoie l'étape mise à jour.
    func uploadEtapeTicket(
        voyageId: Int,
        etapeId: Int,
        fileData: Data,
        fileName: String,
        mimeType: String
    ) async throws -> VoyageEtape {
        let response: APIResponse<VoyageEtape> = try await apiClient.uploadMultipart(
            method: "POST",
            path: APIConfig.Endpoints.etapeTickets(voyageId: voyageId, etapeId: etapeId),
            fieldName: "ticket",
            fileData: fileData,
            fileName: fileName,
            mimeType: mimeType,
            requiresAuth: true
        )
        guard let etape = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Upload billet échoué")
        }
        return etape
    }

    /// Supprime un billet de l'étape, identifié par son `url` (telle que renvoyée
    /// par l'API). Renvoie l'étape mise à jour.
    func deleteEtapeTicket(voyageId: Int, etapeId: Int, ticketUrl: String) async throws -> VoyageEtape {
        let response: APIResponse<VoyageEtape> = try await apiClient.delete(
            path: APIConfig.Endpoints.etapeTickets(voyageId: voyageId, etapeId: etapeId),
            body: DeleteTicketPayload(url: ticketUrl),
            requiresAuth: true
        )
        guard let etape = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Suppression billet échouée")
        }
        return etape
    }
}

/// Corps de requête pour la suppression d'un billet d'étape.
struct DeleteTicketPayload: Encodable {
    let url: String
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
