import Foundation

struct Airport: Codable, Identifiable {
    let c: String
    let n: String
    let v: String
    let p: String
    let a: Double?
    let o: Double?

    var id: String { c }
    var code: String { c }
    var name: String { n }
    var city: String { v }
    var country: String { p }

    var displayLabel: String {
        "\(code) — \(name)"
    }

    var displaySublabel: String {
        "\(city), \(country)"
    }
}
