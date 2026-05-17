import Foundation
import Combine

@MainActor
final class DevisDraft: ObservableObject {
    @Published var telephone: String = ""

    @Published var selectedPassengers: [Passenger] = []
    @Published var participants: String = ""

    @Published var datesText: String = ""
    @Published var flexibleDates: Bool = false
    @Published var duree: String = ""

    @Published var lieuxDepart: [Airport] = []
    @Published var lieuxRetour: [Airport] = []
    @Published var destination: String = ""
    @Published var ouvertSuggestions: Bool = false

    @Published var cadre: Set<String> = []
    @Published var hebergement: Set<String> = []
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

    func togglePassenger(_ p: Passenger) {
        if let idx = selectedPassengers.firstIndex(where: { $0.id == p.id }) {
            selectedPassengers.remove(at: idx)
        } else {
            selectedPassengers.append(p)
        }
    }

    func addPassenger(_ p: Passenger) {
        if !selectedPassengers.contains(where: { $0.id == p.id }) {
            selectedPassengers.append(p)
        }
    }

    func removePassenger(_ p: Passenger) {
        selectedPassengers.removeAll { $0.id == p.id }
    }

    var derivedNbPersonnes: Int? {
        selectedPassengers.isEmpty ? nil : selectedPassengers.count
    }

    private func nilIfEmpty(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private func nilIfEmpty(_ set: Set<String>) -> String? {
        guard !set.isEmpty else { return nil }
        return set.sorted().joined(separator: ", ")
    }

    private func airportCodes(_ airports: [Airport]) -> [String]? {
        guard !airports.isEmpty else { return nil }
        return airports.map { "\($0.code) — \($0.name) (\($0.city))" }
    }

    func buildRequest() -> DevisCreateRequest {
        DevisCreateRequest(
            destination: nilIfEmpty(destination),
            destination_souhaitee: nilIfEmpty(destination),
            dates_souhaitees: nilIfEmpty(datesText),
            flexible_dates: flexibleDates ? "1" : nil,
            duree: nilIfEmpty(duree),
            nb_personnes: derivedNbPersonnes,
            participants: nilIfEmpty(participants),
            lieu_depart: lieuxDepart.first.map { "\($0.code) — \($0.name) (\($0.city))" },
            lieux_depart: airportCodes(lieuxDepart),
            lieux_retour: airportCodes(lieuxRetour),
            preferences_horaires: nil,
            ouvert_suggestions: ouvertSuggestions ? "1" : nil,
            cadre: nilIfEmpty(cadre),
            hebergement: nilIfEmpty(hebergement),
            besoins_specifiques: nilIfEmpty(besoinsSpecifiques),
            // hebergement nilIfEmpty(Set) joins with ", " same as cadre/activites
            activites: nilIfEmpty(activites),
            activites_eviter: nilIfEmpty(activitesEviter),
            imperatifs: nilIfEmpty(imperatifs),
            evenement: nilIfEmpty(evenement),
            budget: nilIfEmpty(budget),
            type_voyage: typeVoyage.rawValue,
            message: nil,
            passenger_ids: selectedPassengers.isEmpty ? nil : selectedPassengers.map { $0.id }
        )
    }
}
