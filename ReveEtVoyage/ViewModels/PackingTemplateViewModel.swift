import Foundation
import SwiftUI

@MainActor
final class PackingTemplateViewModel: ObservableObject {
    @Published var items: [PackingTemplateItem] = []
    @Published var categories: [PackingCategory] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let service = PackingService.shared

    // MARK: - Computed

    /// Items grouped by category_id.
    var groupedItems: [(category: PackingCategory?, items: [PackingTemplateItem])] {
        var groups: [Int?: [PackingTemplateItem]] = [:]
        for item in items {
            groups[item.category_id, default: []].append(item)
        }

        for key in groups.keys {
            groups[key]?.sort { $0.sort_order < $1.sort_order }
        }

        var result: [(category: PackingCategory?, items: [PackingTemplateItem])] = []
        for category in categories {
            if let catItems = groups[category.id], !catItems.isEmpty {
                result.append((category: category, items: catItems))
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
            async let itemList = service.listTemplate()
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
            async let itemList = service.listTemplate()
            let (cats, loadedItems) = try await (catList, itemList)
            categories = cats
            items = loadedItems
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - CRUD

    func add(label: String, categoryId: Int?) async -> Bool {
        do {
            let req = PackingTemplateItemRequest(
                category_id: categoryId,
                label: label.trimmingCharacters(in: .whitespacesAndNewlines),
                sort_order: nil
            )
            let created = try await service.addTemplateItem(req)
            items.append(created)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func update(item: PackingTemplateItem, label: String, categoryId: Int?) async -> Bool {
        do {
            let req = PackingTemplateItemRequest(
                category_id: categoryId,
                label: label.trimmingCharacters(in: .whitespacesAndNewlines),
                sort_order: item.sort_order
            )
            let updated = try await service.updateTemplateItem(id: item.id, req)
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx] = updated
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete(item: PackingTemplateItem) async {
        do {
            try await service.deleteTemplateItem(id: item.id)
            items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
