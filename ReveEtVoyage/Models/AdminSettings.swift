import Foundation

struct AdminSetting: Codable, Identifiable, Hashable {
    var id: String { key }
    let key: String
    let value: String?
}

struct AdminEmailTemplate: Codable, Identifiable, Hashable {
    let id: Int
    let key: String
    let nom: String
    let sujet: String?
    let contenu: String?
    let variables: String?
}
