import Foundation
import SwiftUI

// MARK: - Participant

struct ExpenseParticipant: Codable, Identifiable, Hashable {
    let id: Int
    let voyage_id: Int
    let user_id: Int?
    let display_name: String
    let is_guest: Bool

    enum CodingKeys: String, CodingKey {
        case id, voyage_id, user_id, display_name, is_guest
    }
}

// MARK: - Expense

struct ExpenseSplit: Codable, Hashable {
    let participant_id: Int
    let share_weight: Double

    enum CodingKeys: String, CodingKey {
        case participant_id, share_weight
    }
}

struct ExpensePaidBy: Codable, Hashable {
    let id: Int
    let display_name: String
}

struct Expense: Codable, Identifiable, Hashable {
    let id: Int
    let voyage_id: Int
    let paid_by_participant_id: Int
    let created_by_user_id: Int?
    let title: String
    let amount_cents: Int
    let currency: String
    let category: String
    let spent_at: String?
    let description: String?
    let location_name: String?
    let location_latitude: Double?
    let location_longitude: Double?
    let splits: [ExpenseSplit]
    let paid_by: ExpensePaidBy?

    enum CodingKeys: String, CodingKey {
        case id, voyage_id, paid_by_participant_id, created_by_user_id
        case title, amount_cents
        case currency, category, spent_at, description
        case location_name, location_latitude, location_longitude
        case splits, paid_by
    }

    var amount: Double { Double(amount_cents) / 100.0 }
    var spentAtDate: Date? { spent_at?.toDate() }
}

// MARK: - Settlement

struct SettlementBalance: Codable, Hashable, Identifiable {
    var id: Int { participant_id }
    let participant_id: Int
    let name: String
    let balance_cents: Int

    var balance: Double { Double(balance_cents) / 100.0 }
}

struct SettlementTransaction: Codable, Hashable, Identifiable {
    var id: String { "\(from_participant_id)->\(to_participant_id)-\(amount_cents)" }
    let from_participant_id: Int
    let from_name: String
    let to_participant_id: Int
    let to_name: String
    let amount_cents: Int

    var amount: Double { Double(amount_cents) / 100.0 }
}

struct Settlement: Codable {
    let balances: [SettlementBalance]
    let transactions: [SettlementTransaction]
    let total_cents: Int
    let by_category: [String: Int]

    var total: Double { Double(total_cents) / 100.0 }
}

// MARK: - Category

enum ExpenseCategory: String, CaseIterable, Identifiable {
    case restaurant
    case activite
    case transport
    case hotel
    case shopping
    case essence
    case cadeau
    case autre

    var id: String { rawValue }

    var label: String {
        switch self {
        case .restaurant: return "Restaurant"
        case .activite:   return "Activité"
        case .transport:  return "Transport"
        case .hotel:      return "Hôtel"
        case .shopping:   return "Shopping"
        case .essence:    return "Essence"
        case .cadeau:     return "Cadeau"
        case .autre:      return "Autre"
        }
    }

    var systemImage: String {
        switch self {
        case .restaurant: return "fork.knife"
        case .activite:   return "figure.walk"
        case .transport:  return "car.fill"
        case .hotel:      return "bed.double.fill"
        case .shopping:   return "bag.fill"
        case .essence:    return "fuelpump.fill"
        case .cadeau:     return "gift.fill"
        case .autre:      return "square.fill"
        }
    }

    var color: Color {
        switch self {
        case .restaurant: return .orange
        case .activite:   return .green
        case .transport:  return .blue
        case .hotel:      return .purple
        case .shopping:   return .pink
        case .essence:    return .red
        case .cadeau:     return .yellow
        case .autre:      return .gray
        }
    }

    static func from(_ raw: String) -> ExpenseCategory {
        ExpenseCategory(rawValue: raw) ?? .autre
    }
}

// MARK: - Request bodies

struct ParticipantCreateRequest: Encodable {
    let display_name: String?
    let email: String?
}

struct ExpenseRequestSplit: Encodable {
    let participant_id: Int
    let share_weight: Double
}

struct ExpenseRequest: Encodable {
    let title: String
    let amount: Double
    let currency: String?
    let paid_by_participant_id: Int
    let spent_at: String?
    let description: String?
    let category: String?
    let location_name: String?
    let location_latitude: Double?
    let location_longitude: Double?
    let splits: [ExpenseRequestSplit]?
}
