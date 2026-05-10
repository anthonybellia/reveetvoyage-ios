import Foundation

struct Passenger: Codable, Identifiable {
    let id: Int
    let nom: String
    let prenom: String
    let date_naissance: String?
    let type_doc: String?
    let num_doc: String?
    let nationalite: String?
    let langues: [String]
    let notes: String?
    let expiration_doc: String?
    let is_default: Bool
    let created_at: String
    let updated_at: String

    var fullName: String {
        "\(prenom) \(nom)"
    }

    enum CodingKeys: String, CodingKey {
        case id, nom, prenom, date_naissance, type_doc, num_doc
        case nationalite, langues, notes, expiration_doc, is_default
        case created_at, updated_at
    }
}

struct PassengerCreateRequest: Encodable {
    let nom: String
    let prenom: String
    let date_naissance: String?
    let type_doc: String?
    let num_doc: String?
    let nationalite: String?
    let langues: [String]
    let notes: String?
    let expiration_doc: String?
    let is_default: Bool

    enum CodingKeys: String, CodingKey {
        case nom, prenom, date_naissance, type_doc, num_doc
        case nationalite, langues, notes, expiration_doc, is_default
    }
}

typealias PassengerUpdateRequest = PassengerCreateRequest
