import Foundation

@MainActor
final class PackingService {
    static let shared = PackingService()
    private let apiClient = APIClient.shared

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private init() {}

    // MARK: - Categories

    func listCategories() async throws -> [PackingCategory] {
        let response: APIResponse<[PackingCategory]> = try await apiClient.get(
            path: "/packing-categories",
            requiresAuth: true
        )
        return response.data ?? []
    }

    // MARK: - Template (base list)

    func listTemplate() async throws -> [PackingTemplateItem] {
        let response: APIResponse<[PackingTemplateItem]> = try await apiClient.get(
            path: "/packing-template",
            requiresAuth: true
        )
        return response.data ?? []
    }

    func addTemplateItem(_ request: PackingTemplateItemRequest) async throws -> PackingTemplateItem {
        let response: APIResponse<PackingTemplateItem> = try await apiClient.post(
            path: "/packing-template",
            body: request,
            requiresAuth: true
        )
        guard let item = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Ajout de l'élément échoué")
        }
        return item
    }

    func updateTemplateItem(id: Int, _ request: PackingTemplateItemRequest) async throws -> PackingTemplateItem {
        let response: APIResponse<PackingTemplateItem> = try await apiClient.put(
            path: "/packing-template/\(id)",
            body: request,
            requiresAuth: true
        )
        guard let item = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Mise à jour de l'élément échouée")
        }
        return item
    }

    func deleteTemplateItem(id: Int) async throws {
        try await apiClient.deleteVoid(
            path: "/packing-template/\(id)",
            requiresAuth: true
        )
    }

    // MARK: - Voyage checklist

    func listVoyagePacking(voyageId: Int, since: Date? = nil) async throws -> [VoyagePackingItem] {
        var queryParams: [String: String]? = nil
        if let since = since {
            queryParams = ["since": Self.iso8601.string(from: since)]
        }
        let response: APIResponse<[VoyagePackingItem]> = try await apiClient.get(
            path: "/voyages/\(voyageId)/packing",
            queryParams: queryParams,
            requiresAuth: true
        )
        return response.data ?? []
    }

    func addVoyageItem(voyageId: Int, _ request: VoyagePackingItemCreateRequest) async throws -> VoyagePackingItem {
        let response: APIResponse<VoyagePackingItem> = try await apiClient.post(
            path: "/voyages/\(voyageId)/packing",
            body: request,
            requiresAuth: true
        )
        guard let item = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Ajout de l'élément échoué")
        }
        return item
    }

    func updateVoyageItem(voyageId: Int, itemId: Int, _ request: VoyagePackingItemUpdateRequest) async throws -> VoyagePackingItem {
        let response: APIResponse<VoyagePackingItem> = try await apiClient.put(
            path: "/voyages/\(voyageId)/packing/\(itemId)",
            body: request,
            requiresAuth: true
        )
        guard let item = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Mise à jour de l'élément échouée")
        }
        return item
    }

    func deleteVoyageItem(voyageId: Int, itemId: Int) async throws {
        try await apiClient.deleteVoid(
            path: "/voyages/\(voyageId)/packing/\(itemId)",
            requiresAuth: true
        )
    }
}
