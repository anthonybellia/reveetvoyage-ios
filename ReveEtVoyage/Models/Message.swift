import Foundation

struct Message: Codable, Identifiable, Hashable {
    let id: Int
    let sender: String   // "user" | "admin"
    let body: String
    let attachment_url: String?
    let attachment_type: String?  // "image" | "pdf" | "other"
    let attachment_name: String?
    let attachment_size: Int?
    let attachment_mime: String?
    let read_at: String?
    let is_read: Bool
    let created_at: String

    var isFromUser: Bool { sender == "user" }
    var isFromAdmin: Bool { sender == "admin" }
    var hasAttachment: Bool { attachment_url != nil }
    var sentAt: Date? { created_at.toDate() }

    enum CodingKeys: String, CodingKey {
        case id, sender, body
        case attachment_url, attachment_type, attachment_name, attachment_size, attachment_mime
        case read_at, is_read, created_at
    }
}

struct UnreadCountResponse: Decodable {
    let count: Int
}
