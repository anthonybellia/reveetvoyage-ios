import Foundation

final class UserAdminService {
    static let shared = UserAdminService()
    private let apiClient = APIClient.shared

    private init() {}

    func list(page: Int = 1, query: String? = nil, role: String? = nil) async throws -> (items: [AdminUser], hasMore: Bool) {
        var params: [String: String] = ["page": String(page)]
        if let q = query?.trimmingCharacters(in: .whitespaces), !q.isEmpty { params["q"] = q }
        if let r = role, !r.isEmpty { params["role"] = r }
        let response: APIResponse<[AdminUser]> = try await apiClient.get(
            path: "/admin/users",
            queryParams: params,
            requiresAuth: true
        )
        let items = response.data ?? []
        let hasMore: Bool
        if let meta = response.meta, let current = meta.current_page, let last = meta.last_page {
            hasMore = current < last
        } else {
            hasMore = false
        }
        return (items, hasMore)
    }

    func get(id: Int) async throws -> AdminUser {
        let response: APIResponse<AdminUser> = try await apiClient.get(
            path: "/admin/users/\(id)",
            requiresAuth: true
        )
        guard let u = response.data else {
            throw NetworkError.serverError(statusCode: 404, message: "Utilisateur introuvable")
        }
        return u
    }

    func create(payload: AdminUserPayload) async throws -> AdminUser {
        let response: APIResponse<AdminUser> = try await apiClient.post(
            path: "/admin/users",
            body: payload,
            requiresAuth: true
        )
        guard let u = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Création utilisateur échouée")
        }
        return u
    }

    func update(id: Int, payload: AdminUserPayload) async throws -> AdminUser {
        let response: APIResponse<AdminUser> = try await apiClient.put(
            path: "/admin/users/\(id)",
            body: payload,
            requiresAuth: true
        )
        guard let u = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Mise à jour utilisateur échouée")
        }
        return u
    }

    func delete(id: Int) async throws {
        try await apiClient.deleteVoid(path: "/admin/users/\(id)", requiresAuth: true)
    }
}

struct AdminUserPayload: Encodable {
    let name: String
    let prenom: String?
    let email: String
    let role: String
    let password: String?
    let phone: String?
    let adresse: String?
    let code_postal: String?
    let ville: String?
    let pays: String?
    let language: String?
}
