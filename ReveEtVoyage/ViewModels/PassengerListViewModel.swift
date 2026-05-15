import Foundation

@MainActor
final class PassengerListViewModel: ObservableObject {
    @Published var passengers: [Passenger] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = PassengerService.shared

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            passengers = try await service.getPassengers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create(_ request: PassengerCreateRequest) async -> Bool {
        do {
            let p = try await service.createPassenger(request: request)
            passengers.append(p)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func update(id: Int, request: PassengerUpdateRequest) async -> Bool {
        do {
            let p = try await service.updatePassenger(id: id, request: request)
            if let idx = passengers.firstIndex(where: { $0.id == id }) {
                passengers[idx] = p
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete(id: Int) async {
        do {
            try await service.deletePassenger(id: id)
            passengers.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
