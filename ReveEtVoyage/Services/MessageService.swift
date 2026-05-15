import Foundation

final class MessageService {
    static let shared = MessageService()
    private let apiClient = APIClient.shared
    private let keychain = KeychainHelper.shared

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

    /// Send a text-only message.
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

    /// Send a message with an attachment (multipart). `body` is optional.
    /// `mime` should be one of: image/jpeg, image/png, image/webp, application/pdf.
    func sendAttachment(body: String, fileData: Data, fileName: String, mime: String) async throws -> Message {
        guard let token = keychain.getToken() else { throw NetworkError.unauthorized }
        guard let url = URL(string: APIConfig.baseURL.absoluteString + APIConfig.Endpoints.messages) else {
            throw NetworkError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var multipart = Data()
        let crlf = "\r\n"
        if !body.isEmpty {
            multipart.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            multipart.append("Content-Disposition: form-data; name=\"body\"\(crlf)\(crlf)".data(using: .utf8)!)
            multipart.append(body.data(using: .utf8)!)
            multipart.append(crlf.data(using: .utf8)!)
        }
        multipart.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        multipart.append("Content-Disposition: form-data; name=\"attachment\"; filename=\"\(fileName)\"\(crlf)".data(using: .utf8)!)
        multipart.append("Content-Type: \(mime)\(crlf)\(crlf)".data(using: .utf8)!)
        multipart.append(fileData)
        multipart.append("\(crlf)--\(boundary)--\(crlf)".data(using: .utf8)!)

        request.httpBody = multipart

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NetworkError.serverError(statusCode: code,
                                            message: String(data: data, encoding: .utf8))
        }

        struct Wrap: Decodable { let data: Message }
        return try JSONDecoder().decode(Wrap.self, from: data).data
    }

    func unreadCount() async throws -> Int {
        let response: UnreadCountResponse = try await apiClient.get(
            path: APIConfig.Endpoints.messagesUnread,
            requiresAuth: true
        )
        return response.count
    }

    func filesHistory() async throws -> [Message] {
        let response: APIResponse<[Message]> = try await apiClient.get(
            path: APIConfig.Endpoints.files,
            requiresAuth: true
        )
        return response.data ?? []
    }
}

private struct SendMessageRequest: Encodable {
    let body: String
}
