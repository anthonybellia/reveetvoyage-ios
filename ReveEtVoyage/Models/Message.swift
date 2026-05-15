import Foundation

struct Message: Codable, Identifiable, Hashable {
    let id: Int
    let sender: String   // "user" | "admin"
    let body: String
    let read_at: String?
    let is_read: Bool
    let created_at: String

    var isFromUser: Bool { sender == "user" }
    var isFromAdmin: Bool { sender == "admin" }

    var sentAt: Date? { created_at.toDate() }

    enum CodingKeys: String, CodingKey {
        case id, sender, body, read_at, is_read, created_at
    }
}

struct UnreadCountResponse: Decodable {
    let count: Int
}
