import Foundation

/// Admin-only: list of customers used by voyage/devis form pickers.
final class CustomerService {
    static let shared = CustomerService()
    private let apiClient = APIClient.shared

    private init() {}

    func listCustomers(query: String? = nil) async throws -> [ApiCustomer] {
        var params: [String: String] = [:]
        if let q = query?.trimmingCharacters(in: .whitespaces), !q.isEmpty {
            params["q"] = q
        }
        let response: APIResponse<[ApiCustomer]> = try await apiClient.get(
            path: "/admin/customers",
            queryParams: params.isEmpty ? nil : params,
            requiresAuth: true
        )
        return response.data ?? []
    }
}

struct ApiCustomer: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let email: String
}
