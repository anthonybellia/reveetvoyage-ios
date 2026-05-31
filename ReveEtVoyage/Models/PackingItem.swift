import Foundation
import SwiftUI

// MARK: - PackingCategory

struct PackingCategory: Codable, Identifiable, Hashable {
    let id: Int
    let key: String
    let name: String
    let icon_key: String
    let color: String?

    enum CodingKeys: String, CodingKey {
        case id, key, name, icon_key, color
    }

    /// SF Symbol mapping from icon_key
    var systemImage: String {
        switch icon_key {
        case "documents":   return "doc.text"
        case "clothes":     return "tshirt"
        case "toiletries":  return "shower"
        case "electronics": return "bolt"
        case "health":      return "cross.case"
        case "misc":        return "shippingbox"
        default:            return "checklist"
        }
    }

    /// SwiftUI Color from hex string stored in `color`, falls back to .revOrange
    var swiftUIColor: Color {
        guard let hex = color else { return .revOrange }
        return Color(hex: hex) ?? .revOrange
    }
}

// MARK: - Color hex initializer (private to this file)

private extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        if length == 6 {
            self.init(
                red:   Double((rgb & 0xFF0000) >> 16) / 255.0,
                green: Double((rgb & 0x00FF00) >>  8) / 255.0,
                blue:  Double( rgb & 0x0000FF       ) / 255.0
            )
        } else if length == 8 {
            self.init(
                red:   Double((rgb & 0xFF000000) >> 24) / 255.0,
                green: Double((rgb & 0x00FF0000) >> 16) / 255.0,
                blue:  Double((rgb & 0x0000FF00) >>  8) / 255.0,
                opacity: Double( rgb & 0x000000FF      ) / 255.0
            )
        } else {
            return nil
        }
    }
}

// MARK: - PackingTemplateItem

struct PackingTemplateItem: Codable, Identifiable, Hashable {
    let id: Int
    let category_id: Int?
    let label: String
    let sort_order: Int

    enum CodingKeys: String, CodingKey {
        case id, category_id, label, sort_order
    }
}

// MARK: - VoyagePackingItem

struct VoyagePackingItem: Codable, Identifiable, Hashable {
    let id: Int
    let voyage_participant_id: Int
    let category_id: Int?
    let label: String
    let is_checked: Bool
    let sort_order: Int
    let source_template_item_id: Int?
    let created_at: String?
    let updated_at: String?

    enum CodingKeys: String, CodingKey {
        case id, voyage_participant_id, category_id, label
        case is_checked, sort_order, source_template_item_id
        case created_at, updated_at
    }
}

// MARK: - Request bodies

struct PackingTemplateItemRequest: Encodable {
    let category_id: Int?
    let label: String
    let sort_order: Int?
}

struct VoyagePackingItemCreateRequest: Encodable {
    let category_id: Int?
    let label: String
    let sort_order: Int?
    let keep_for_next: Bool
}

struct VoyagePackingItemUpdateRequest: Encodable {
    let is_checked: Bool?
    let label: String?
    let category_id: Int?
    let sort_order: Int?

    // Allows encoding only non-nil fields
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(is_checked, forKey: .is_checked)
        try container.encodeIfPresent(label,      forKey: .label)
        try container.encodeIfPresent(category_id, forKey: .category_id)
        try container.encodeIfPresent(sort_order,  forKey: .sort_order)
    }

    enum CodingKeys: String, CodingKey {
        case is_checked, label, category_id, sort_order
    }
}
