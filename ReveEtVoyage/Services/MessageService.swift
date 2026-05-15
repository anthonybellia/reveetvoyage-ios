import Foundation

final class MessageService {
    static let shared = MessageService()
    private let apiClient = APIClient.shared

    private init() {}

    func getMessages(since: Date? = nil) async throws -> [Message] {
        var query: [String: String] = [:]
        if let since {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            query["since"] = f.string(from: since)
        }

        let response: APIResponse<[Message]> = try await apiClient.get(
            path: APIConfig.Endpoints.messages,
            queryParams: query.isEmpty ? nil : query,
            requiresAuth: true
        )
        return response.data ?? []
    }

    func sendMessage(body: String) async throws -> Message {
        let response: APIResponse<Message> = try await apiClient.post(
            path: APIConfig.Endpoints.messages,
            body: SendMessageRequest(body: body),
            requiresAuth: true
        )
        guard let message = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Envoi du message échoué")
        }
        return message
    }

    func unreadCount() async throws -> Int {
        let response: UnreadCountResponse = try await apiClient.get(
            path: APIConfig.Endpoints.messagesUnread,
            requiresAuth: true
        )
        return response.count
    }
}

private struct SendMessageRequest: Encodable {
    let body: String
}
