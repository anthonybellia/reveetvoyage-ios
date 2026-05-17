import Foundation
import Combine

@MainActor
final class DevisDraft: ObservableObject {
    @Published var telephone: String = ""

    @Published var nbPersonnes: Int? = nil
    @Published var participants: String = ""

    @Published var datesText: String = ""
    @Published var flexibleDates: Bool = false
    @Published var duree: String = ""

    @Published var lieuDepart: String = ""
    @Published var destination: String = ""
    @Published var ouvertSuggestions: Bool = false

    @Published var cadre: Set<String> = []
    @Published var hebergement: String = ""
    @Published var besoinsSpecifiques: String = ""

    @Published var activites: Set<String> = []
    @Published var activitesEviter: String = ""

    @Published var budget: String = ""
    @Published var imperatifs: String = ""
    @Published var evenement: String = ""

    @Published var typeVoyage: DevisTypeVoyage = .couple

    func preFill(from user: User?) {
        if let phone = user?.phone, telephone.isEmpty {
            telephone = phone
        }
    }

    func isStepValid(_ step: Int) -> Bool {
        switch step {
        case 1: return true
        case 7: return !budget.isEmpty
        default: return true
        }
    }

    private func nilIfEmpty(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private func nilIfEmpty(_ set: Set<String>) -> String? {
        guard !set.isEmpty else { return nil }
        return set.sorted().joined(separator: ", ")
    }

    func buildRequest() -> DevisCreateRequest {
        DevisCreateRequest(
            destination: nilIfEmpty(destination),
            destination_souhaitee: nilIfEmpty(destination),
            dates_souhaitees: nilIfEmpty(datesText),
            flexible_dates: flexibleDates ? "1" : nil,
            duree: nilIfEmpty(duree),
            nb_personnes: nbPersonnes,
            participants: nilIfEmpty(participants),
            lieu_depart: nilIfEmpty(lieuDepart),
            preferences_horaires: nil,
            ouvert_suggestions: ouvertSuggestions ? "1" : nil,
            cadre: nilIfEmpty(cadre),
            hebergement: nilIfEmpty(hebergement),
            besoins_specifiques: nilIfEmpty(besoinsSpecifiques),
            activites: nilIfEmpty(activites),
            activites_eviter: nilIfEmpty(activitesEviter),
            imperatifs: nilIfEmpty(imperatifs),
            evenement: nilIfEmpty(evenement),
            budget: nilIfEmpty(budget),
            type_voyage: typeVoyage.rawValue,
            message: nil
        )
    }
}
