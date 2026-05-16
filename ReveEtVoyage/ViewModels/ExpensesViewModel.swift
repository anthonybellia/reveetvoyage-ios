import Foundation
import SwiftUI

@MainActor
final class ExpensesViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var participants: [ExpenseParticipant] = []
    @Published var settlement: Settlement?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let service = ExpenseService.shared
    let voyageId: Int

    private var pollingTask: Task<Void, Never>?
    private var lastSync: Date?

    init(voyageId: Int) {
        self.voyageId = voyageId
    }

    // MARK: - Computed

    var totalSpent: Double {
        settlement?.total ?? expenses.reduce(0) { $0 + $1.amount }
    }

    var amountByCategory: [(category: ExpenseCategory, amount: Double)] {
        if let byCat = settlement?.by_category {
            return ExpenseCategory.allCases.compactMap { cat in
                guard let cents = byCat[cat.rawValue], cents > 0 else { return nil }
                return (cat, Double(cents) / 100.0)
            }
        }
        // Fallback: aggregate from expenses
        var totals: [String: Double] = [:]
        for e in expenses {
            totals[e.category, default: 0] += e.amount
        }
        return ExpenseCategory.allCases.compactMap { cat in
            guard let amt = totals[cat.rawValue], amt > 0 else { return nil }
            return (cat, amt)
        }
    }

    func participantName(id: Int) -> String {
        participants.first(where: { $0.id == id })?.display_name ?? "?"
    }

    // MARK: - Loading

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let pList = service.listParticipants(voyageId: voyageId)
            async let eList = service.listExpenses(voyageId: voyageId, since: nil)
            async let sett  = service.getSettlement(voyageId: voyageId)

            let (p, e, s) = try await (pList, eList, sett)
            participants = p
            expenses = e.sorted(by: Self.sortNewestFirst)
            settlement = s
            lastSync = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        do {
            async let pList = service.listParticipants(voyageId: voyageId)
            async let eList = service.listExpenses(voyageId: voyageId, since: nil)
            async let sett  = service.getSettlement(voyageId: voyageId)
            let (p, e, s) = try await (pList, eList, sett)
            participants = p
            expenses = e.sorted(by: Self.sortNewestFirst)
            settlement = s
            lastSync = Date()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Incremental: fetches only new expenses since lastSync. Used by polling.
    func pollIncremental() async {
        guard let since = lastSync else {
            await refresh()
            return
        }
        do {
            let newOnes = try await service.listExpenses(voyageId: voyageId, since: since)
            lastSync = Date()
            guard !newOnes.isEmpty else { return }

            // Merge: keep existing, replace ids that came back, prepend the rest
            var existingById = Dictionary(uniqueKeysWithValues: expenses.map { ($0.id, $0) })
            for e in newOnes {
                existingById[e.id] = e
            }
            expenses = existingById.values.sorted(by: Self.sortNewestFirst)

            // Refresh settlement too (lightweight, single endpoint)
            settlement = try? await service.getSettlement(voyageId: voyageId)
        } catch {
            // Silent on polling failures — leave UI untouched
        }
    }

    // MARK: - CRUD passthrough

    func addExpense(request: ExpenseRequest) async -> Bool {
        do {
            let created = try await service.createExpense(voyageId: voyageId, request: request)
            expenses.insert(created, at: 0)
            expenses.sort(by: Self.sortNewestFirst)
            settlement = try? await service.getSettlement(voyageId: voyageId)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateExpense(expenseId: Int, request: ExpenseRequest) async -> Bool {
        do {
            let updated = try await service.updateExpense(voyageId: voyageId, expenseId: expenseId, request: request)
            if let idx = expenses.firstIndex(where: { $0.id == expenseId }) {
                expenses[idx] = updated
            } else {
                expenses.append(updated)
            }
            expenses.sort(by: Self.sortNewestFirst)
            settlement = try? await service.getSettlement(voyageId: voyageId)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteExpense(_ expense: Expense) async {
        do {
            try await service.deleteExpense(voyageId: voyageId, expenseId: expense.id)
            expenses.removeAll { $0.id == expense.id }
            settlement = try? await service.getSettlement(voyageId: voyageId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addParticipant(displayName: String? = nil, email: String? = nil) async -> Bool {
        do {
            let p = try await service.addParticipant(voyageId: voyageId, displayName: displayName, email: email)
            participants.append(p)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func removeParticipant(_ participant: ExpenseParticipant) async {
        do {
            try await service.removeParticipant(voyageId: voyageId, participantId: participant.id)
            participants.removeAll { $0.id == participant.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Polling

    func startPolling(interval: TimeInterval = 5) {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if Task.isCancelled { break }
                await self?.pollIncremental()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Helpers

    private static func sortNewestFirst(_ a: Expense, _ b: Expense) -> Bool {
        switch (a.spentAtDate, b.spentAtDate) {
        case let (da?, db?): return da > db
        case (_?, nil):      return true
        case (nil, _?):      return false
        case (nil, nil):     return a.id > b.id
        }
    }
}
