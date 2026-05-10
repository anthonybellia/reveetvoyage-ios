import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var voyages: [Voyage] = []
    @Published var recentDevis: [Devis] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let voyageService = VoyageService.shared
    private let devisService = DevisService.shared

    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        async let voyagesTask = loadVoyages()
        async let devisTask = loadDevis()
        _ = await (voyagesTask, devisTask)
    }

    private func loadVoyages() async {
        do {
            let (voyages, _) = try await voyageService.getVoyages(page: 1, perPage: 5)
            self.voyages = voyages
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadDevis() async {
        do {
            let (devis, _) = try await devisService.getDevis(page: 1, perPage: 5)
            self.recentDevis = devis
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
