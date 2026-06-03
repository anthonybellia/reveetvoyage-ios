import Foundation
import SwiftUI

@MainActor
final class PackingViewModel: ObservableObject {
    @Published var items: [VoyagePackingItem] = []
    @Published var categories: [PackingCategory] = []
    @Published var isLoading: Bool = false
    @Published var isGenerating: Bool = false
    @Published var errorMessage: String?

    private let service = PackingService.shared
    let voyageId: Int

    init(voyageId: Int) {
        self.voyageId = voyageId
    }

    // MARK: - Computed

    var checkedCount: Int {
        items.filter { $0.is_checked }.count
    }

    var totalCount: Int {
        items.count
    }

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(checkedCount) / Double(totalCount)
    }

    /// Items grouped by category_id, with uncategorized as nil.
    /// Each group is (category: PackingCategory?, items: [VoyagePackingItem])
    var groupedItems: [(category: PackingCategory?, items: [VoyagePackingItem])] {
        var groups: [Int?: [VoyagePackingItem]] = [:]
        for item in items {
            groups[item.category_id, default: []].append(item)
        }

        // Sort each group's items by sort_order
        for key in groups.keys {
            groups[key]?.sort { $0.sort_order < $1.sort_order }
        }

        // Build sorted result: known categories first (in category order), then uncategorized
        var result: [(category: PackingCategory?, items: [VoyagePackingItem])] = []

        for category in categories {
            if let categoryItems = groups[category.id], !categoryItems.isEmpty {
                result.append((category: category, items: categoryItems))
            }
        }

        if let uncategorized = groups[nil], !uncategorized.isEmpty {
            result.append((category: nil, items: uncategorized))
        }

        return result
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let catList = service.listCategories()
            async let itemList = service.listVoyagePacking(voyageId: voyageId)
            let (cats, loadedItems) = try await (catList, itemList)
            categories = cats
            items = loadedItems
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        do {
            async let catList = service.listCategories()
            async let itemList = service.listVoyagePacking(voyageId: voyageId)
            let (cats, loadedItems) = try await (catList, itemList)
            categories = cats
            items = loadedItems
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Toggle

    func toggle(item: VoyagePackingItem) async {
        // Optimistic update
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            let newChecked = !item.is_checked
            // Rebuild with updated is_checked (VoyagePackingItem is a struct)
            let updated = VoyagePackingItem(
                id: item.id,
                voyage_participant_id: item.voyage_participant_id,
                category_id: item.category_id,
                label: item.label,
                is_checked: newChecked,
                sort_order: item.sort_order,
                source_template_item_id: item.source_template_item_id,
                created_at: item.created_at,
                updated_at: item.updated_at
            )
            items[idx] = updated
        }

        do {
            let req = VoyagePackingItemUpdateRequest(
                is_checked: !item.is_checked,
                label: nil,
                category_id: nil,
                sort_order: nil
            )
            let serverItem = try await service.updateVoyageItem(
                voyageId: voyageId,
                itemId: item.id,
                req
            )
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx] = serverItem
            }
        } catch {
            // Rollback optimistic update on failure
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx] = item
            }
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Add

    func add(label: String, categoryId: Int?, keepForNext: Bool) async -> Bool {
        do {
            let req = VoyagePackingItemCreateRequest(
                category_id: categoryId,
                label: label.trimmingCharacters(in: .whitespacesAndNewlines),
                sort_order: nil,
                keep_for_next: keepForNext
            )
            let created = try await service.addVoyageItem(voyageId: voyageId, req)
            items.append(created)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Generate classic list

    /// Génère la "liste classique" via l'API (anti-doublon côté serveur) puis
    /// remplace la liste locale par la version renvoyée.
    func generateClassic() async {
        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        do {
            let generated = try await service.generateVoyagePacking(voyageId: voyageId)
            items = generated
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete

    func delete(item: VoyagePackingItem) async {
        do {
            try await service.deleteVoyageItem(voyageId: voyageId, itemId: item.id)
            items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
