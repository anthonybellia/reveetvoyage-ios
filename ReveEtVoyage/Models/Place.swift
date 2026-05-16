import Foundation

/// A place result from `/api/places/search` (Nominatim/OSM backend proxy).
struct Place: Codable, Identifiable, Hashable {
    var id: String { "\(latitude ?? 0)-\(longitude ?? 0)-\(name)" }
    let name: String
    let address: String
    let latitude: Double?
    let longitude: Double?
    let type: String?
}
