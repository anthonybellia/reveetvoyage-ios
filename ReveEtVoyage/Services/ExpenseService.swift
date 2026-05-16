import Foundation

@MainActor
final class ExpenseService {
    static let shared = ExpenseService()
    private let apiClient = APIClient.shared

    private init() {}

    // MARK: - Participants

    func listParticipants(voyageId: Int) async throws -> [ExpenseParticipant] {
        let response: APIResponse<[ExpenseParticipant]> = try await apiClient.get(
            path: "/voyages/\(voyageId)/participants",
            requiresAuth: true
        )
        return response.data ?? []
    }

    func addParticipant(voyageId: Int, displayName: String? = nil, email: String? = nil) async throws -> ExpenseParticipant {
        let body = ParticipantCreateRequest(display_name: displayName, email: email)
        let response: APIResponse<ExpenseParticipant> = try await apiClient.post(
            path: "/voyages/\(voyageId)/participants",
            body: body,
            requiresAuth: true
        )
        guard let participant = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Ajout du participant échoué")
        }
        return participant
    }

    func removeParticipant(voyageId: Int, participantId: Int) async throws {
        try await apiClient.deleteVoid(
            path: "/voyages/\(voyageId)/participants/\(participantId)",
            requiresAuth: true
        )
    }

    // MARK: - Expenses

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    func listExpenses(voyageId: Int, since: Date? = nil) async throws -> [Expense] {
        var queryParams: [String: String]? = nil
        if let since = since {
            queryParams = ["since": Self.iso8601.string(from: since)]
        }
        let response: APIResponse<[Expense]> = try await apiClient.get(
            path: "/voyages/\(voyageId)/expenses",
            queryParams: queryParams,
            requiresAuth: true
        )
        return response.data ?? []
    }

    func createExpense(voyageId: Int, request: ExpenseRequest) async throws -> Expense {
        let response: APIResponse<Expense> = try await apiClient.post(
            path: "/voyages/\(voyageId)/expenses",
            body: request,
            requiresAuth: true
        )
        guard let expense = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Création de la dépense échouée")
        }
        return expense
    }

    func updateExpense(voyageId: Int, expenseId: Int, request: ExpenseRequest) async throws -> Expense {
        let response: APIResponse<Expense> = try await apiClient.put(
            path: "/voyages/\(voyageId)/expenses/\(expenseId)",
            body: request,
            requiresAuth: true
        )
        guard let expense = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Mise à jour de la dépense échouée")
        }
        return expense
    }

    func deleteExpense(voyageId: Int, expenseId: Int) async throws {
        try await apiClient.deleteVoid(
            path: "/voyages/\(voyageId)/expenses/\(expenseId)",
            requiresAuth: true
        )
    }

    // MARK: - Settlement

    // MARK: - Place autocomplete

    func searchPlaces(query: String, lat: Double? = nil, lng: Double? = nil) async throws -> [Place] {
        var params: [String: String] = ["q": query]
        if let lat = lat, let lng = lng {
            params["lat"] = String(lat)
            params["lng"] = String(lng)
        }
        let response: APIResponse<[Place]> = try await apiClient.get(
            path: "/places/search",
            queryParams: params,
            requiresAuth: true
        )
        return response.data ?? []
    }

    func getSettlement(voyageId: Int) async throws -> Settlement {
        // Backend returns the Settlement object directly (not wrapped in {data: …}).
        let settlement: Settlement = try await apiClient.get(
            path: "/voyages/\(voyageId)/settlement",
            requiresAuth: true
        )
        return settlement
    }
}
