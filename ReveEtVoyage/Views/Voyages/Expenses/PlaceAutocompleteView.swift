import SwiftUI

/// Search-as-you-type place picker backed by `GET /api/places/search` (Nominatim).
/// Returns the picked `Place` via `onSelect`. Use as a sheet.
struct PlaceAutocompleteView: View {
    let centerLatitude: Double?
    let centerLongitude: Double?
    /// Filtre de catégorie optionnel : `"airport"` (vols) ou `"railway"` (train).
    /// `nil` = recherche générale (comportement par défaut, rétro-compatible).
    let placeFilter: String?
    let onSelect: (Place) -> Void

    /// Conserve la signature existante (sans filtre) pour les écrans qui ne le passent pas.
    init(
        centerLatitude: Double?,
        centerLongitude: Double?,
        placeFilter: String? = nil,
        onSelect: @escaping (Place) -> Void
    ) {
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.placeFilter = placeFilter
        self.onSelect = onSelect
    }

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var results: [Place] = []
    @State private var isSearching: Bool = false
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar
                Divider()
                content
            }
            .background(Color.revBackground.ignoresSafeArea())
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundColor(.revOrange)
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.revTextSecondary)
            TextField(searchPlaceholder, text: $query)
                .font(.system(size: 15))
                .autocorrectionDisabled()
                .onChange(of: query) { newValue in
                    debounceSearch(newValue)
                }
            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.revTextSecondary)
                }
            }
        }
        .padding(12)
        .background(Color.revCardBackground)
    }

    @ViewBuilder
    private var content: some View {
        if isSearching && results.isEmpty {
            ProgressView().tint(.revOrange).padding(.top, 40)
            Spacer()
        } else if query.count >= 2 && results.isEmpty && !isSearching {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass.circle")
                    .font(.system(size: 36))
                    .foregroundColor(.revOrange.opacity(0.4))
                Text("Aucun lieu trouvé").foregroundColor(.revTextSecondary)
            }
            .padding(.top, 60)
            Spacer()
        } else {
            List(results) { place in
                Button { selectPlace(place) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: iconFor(place.type))
                            .foregroundColor(.revOrange)
                            .frame(width: 22)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.revText)
                            Text(place.address)
                                .font(.system(size: 12))
                                .foregroundColor(.revTextSecondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.revCardBackground)
            }
            .listStyle(.plain)
        }
    }

    private func selectPlace(_ place: Place) {
        onSelect(place)
        dismiss()
    }

    private func debounceSearch(_ value: String) {
        searchTask?.cancel()
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            results = []
            isSearching = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            await runSearch(trimmed)
        }
    }

    private func runSearch(_ q: String) async {
        isSearching = true
        do {
            let res = try await ExpenseService.shared.searchPlaces(
                query: q, lat: centerLatitude, lng: centerLongitude, filter: placeFilter
            )
            if !Task.isCancelled {
                results = res
            }
        } catch {
            results = []
        }
        isSearching = false
    }

    private func iconFor(_ type: String?) -> String {
        // Si on est en mode filtré, l'icône reflète la catégorie recherchée.
        switch placeFilter {
        case "airport": return "airplane"
        case "railway": return "tram.fill"
        default: break
        }
        switch type {
        case "aeroway":  return "airplane"
        case "railway":  return "tram.fill"
        case "amenity":  return "fork.knife.circle.fill"
        case "tourism":  return "building.columns.fill"
        case "shop":     return "bag.fill"
        case "leisure":  return "gamecontroller.fill"
        case "building": return "building.fill"
        default:         return "mappin.circle.fill"
        }
    }

    private var navTitle: String {
        switch placeFilter {
        case "airport": return "Rechercher un aéroport"
        case "railway": return "Rechercher une gare"
        default:        return "Rechercher un lieu"
        }
    }

    private var searchPlaceholder: String {
        switch placeFilter {
        case "airport": return "Aéroport (ville, code IATA…)"
        case "railway": return "Gare (ville, station…)"
        default:        return "Restaurant, hôtel, adresse…"
        }
    }
}
