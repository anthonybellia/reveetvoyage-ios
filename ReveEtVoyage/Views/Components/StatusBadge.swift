import SwiftUI

struct StatusBadge: View {
    let label: String
    let kind: Kind

    enum Kind {
        case neutral, info, success, warning, danger, brand

        var background: Color {
            switch self {
            case .neutral: return Color.gray.opacity(0.15)
            case .info: return Color.blue.opacity(0.15)
            case .success: return Color.green.opacity(0.18)
            case .warning: return Color.revYellow.opacity(0.30)
            case .danger: return Color.revRed.opacity(0.18)
            case .brand: return Color.revOrange.opacity(0.20)
            }
        }

        var foreground: Color {
            switch self {
            case .neutral: return .secondary
            case .info: return .blue
            case .success: return Color(red: 0.10, green: 0.55, blue: 0.30)
            case .warning: return Color(red: 0.65, green: 0.45, blue: 0)
            case .danger: return .revRed
            case .brand: return Color(red: 0.78, green: 0.40, blue: 0.15)
            }
        }
    }

    init(label: String, kind: Kind = .neutral) {
        self.label = label
        self.kind = kind
    }

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(kind.foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(kind.background)
            )
    }

    static func voyageStatut(_ statut: String, label: String) -> StatusBadge {
        let kind: Kind
        switch statut {
        case "en_preparation": kind = .warning
        case "confirme":       kind = .info
        case "en_cours":       kind = .brand
        case "termine":        kind = .success
        case "annule":         kind = .danger
        default:               kind = .neutral
        }
        return StatusBadge(label: label, kind: kind)
    }

    static func devisStatut(_ statut: String) -> StatusBadge {
        let label: String
        let kind: Kind
        switch statut {
        case "nouveau":  label = "Nouveau";       kind = .info
        case "en_cours": label = "En traitement"; kind = .brand
        case "valide":   label = "Validé";        kind = .success
        case "refuse":   label = "Refusé";        kind = .danger
        case "archive":  label = "Archivé";       kind = .neutral
        default:         label = statut.capitalized; kind = .neutral
        }
        return StatusBadge(label: label, kind: kind)
    }
}
