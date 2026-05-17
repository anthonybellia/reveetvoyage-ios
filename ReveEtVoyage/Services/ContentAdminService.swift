import Foundation

final class ContentAdminService {
    static let shared = ContentAdminService()
    private let apiClient = APIClient.shared
    private init() {}

    // MARK: - Destinations

    func listDestinations() async throws -> [AdminDestination] {
        let r: APIResponse<[AdminDestination]> = try await apiClient.get(
            path: "/admin/destinations", requiresAuth: true)
        return r.data ?? []
    }

    func createDestination(_ payload: AdminDestinationPayload) async throws -> AdminDestination {
        let r: APIResponse<AdminDestination> = try await apiClient.post(
            path: "/admin/destinations", body: payload, requiresAuth: true)
        guard let d = r.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Création destination échouée")
        }
        return d
    }

    func updateDestination(id: Int, _ payload: AdminDestinationPayload) async throws -> AdminDestination {
        let r: APIResponse<AdminDestination> = try await apiClient.put(
            path: "/admin/destinations/\(id)", body: payload, requiresAuth: true)
        guard let d = r.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Mise à jour destination échouée")
        }
        return d
    }

    func deleteDestination(id: Int) async throws {
        try await apiClient.deleteVoid(path: "/admin/destinations/\(id)", requiresAuth: true)
    }

    // MARK: - Articles

    func listArticles() async throws -> [AdminArticle] {
        let r: APIResponse<[AdminArticle]> = try await apiClient.get(
            path: "/admin/articles", requiresAuth: true)
        return r.data ?? []
    }

    func createArticle(_ payload: AdminArticlePayload) async throws -> AdminArticle {
        let r: APIResponse<AdminArticle> = try await apiClient.post(
            path: "/admin/articles", body: payload, requiresAuth: true)
        guard let a = r.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Création article échouée")
        }
        return a
    }

    func updateArticle(id: Int, _ payload: AdminArticlePayload) async throws -> AdminArticle {
        let r: APIResponse<AdminArticle> = try await apiClient.put(
            path: "/admin/articles/\(id)", body: payload, requiresAuth: true)
        guard let a = r.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Mise à jour article échouée")
        }
        return a
    }

    func deleteArticle(id: Int) async throws {
        try await apiClient.deleteVoid(path: "/admin/articles/\(id)", requiresAuth: true)
    }
}

struct AdminDestinationPayload: Encodable {
    let nom: String
    let continent: String
    let pays: String
    let description_courte: String?
    let description: String?
    let prix_depuis: Double?
    let duree_jours: Int?
    let meta_title: String?
    let meta_description: String?
    let featured: Bool
    let actif: Bool
}

struct AdminArticlePayload: Encodable {
    let titre: String
    let slug: String?
    let extrait: String?
    let contenu: String?
    let meta_title: String?
    let meta_description: String?
    let publie: Bool
    let publie_le: String?
}
