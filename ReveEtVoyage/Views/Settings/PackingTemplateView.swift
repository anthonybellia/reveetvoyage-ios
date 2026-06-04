import SwiftUI

struct PackingTemplateView: View {
    @StateObject private var viewModel = PackingTemplateViewModel()
    @State private var showAddItem = false
    @State private var editingItem: PackingTemplateItem? = nil

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.revYellow.opacity(0.10), Color.revBackground],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            Group {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    LoadingView()
                } else if let error = viewModel.errorMessage, viewModel.items.isEmpty {
                    ErrorView(message: error) { Task { await viewModel.load() } }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            explanationCard
                            itemsList
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                    .refreshable { await viewModel.refresh() }
                }
            }
        }
        .navigationTitle("Ma liste de base")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddItem = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.revOrange)
                }
            }
        }
        .task { await viewModel.load() }
        .sheet(isPresented: $showAddItem) {
            AddTemplateItemSheet(viewModel: viewModel)
        }
        .sheet(item: $editingItem) { item in
            EditTemplateItemSheet(viewModel: viewModel, item: item)
        }
    }

    // MARK: - Explanation card

    private var explanationCard: some View {
        GlassCard(padding: 14) {
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.revYellow)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ta liste réutilisable")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.revText)
                    Text("Ces articles sont proposés automatiquement pour chaque nouveau voyage.")
                        .font(.system(size: 12))
                        .foregroundColor(.revTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Items list

    private var itemsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.groupedItems.isEmpty {
                GlassCard {
                    VStack(spacing: 8) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 32))
                            .foregroundColor(.revTextSecondary)
                        Text("Ta liste de base est vide.")
                            .font(.system(size: 14))
                            .foregroundColor(.revTextSecondary)
                        Text("Appuie sur + pour ajouter un article.")
                            .font(.system(size: 12))
                            .foregroundColor(.revTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            } else {
                ForEach(viewModel.groupedItems, id: \.category?.id) { group in
                    templateCategorySection(group: group)
                }
            }
        }
    }

    private func templateCategorySection(
        group: (category: PackingCategory?, items: [PackingTemplateItem])
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack(spacing: 6) {
                if let cat = group.category {
                    Image(systemName: cat.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(cat.swiftUIColor)
                    Text(cat.name.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(cat.swiftUIColor)
                } else {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.revTextSecondary)
                    Text("DIVERS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.revTextSecondary)
                }
                Spacer()
                Text("\(group.items.count) article\(group.items.count > 1 ? "s" : "")")
                    .font(.system(size: 11))
                    .foregroundColor(.revTextSecondary)
            }
            .padding(.horizontal, 4)

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                        VStack(spacing: 0) {
                            if index > 0 {
                                Divider().padding(.leading, 52)
                            }
                            TemplateItemRow(item: item) {
                                editingItem = item
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await viewModel.delete(item: item) }
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - TemplateItemRow

private struct TemplateItemRow: View {
    let item: PackingTemplateItem
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 14) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16))
                    .foregroundColor(Color.gray.opacity(0.4))
                    .frame(width: 24)

                Text(item.label)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.revText)

                Spacer()

                Image(systemName: "pencil")
                    .font(.system(size: 13))
                    .foregroundColor(.revTextSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add template item sheet

private struct AddTemplateItemSheet: View {
    @ObservedObject var viewModel: PackingTemplateViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var label: String = ""
    @State private var selectedCategoryId: Int? = nil
    @State private var isSaving: Bool = false
    @State private var localError: String?

    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.revBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        fieldCard(title: "ARTICLE", systemImage: "tag.fill") {
                            TextField("Ex : Crème solaire, chargeur…", text: $label)
                                .font(.system(size: 16, design: .rounded))
                                .textInputAutocapitalization(.sentences)
                                .submitLabel(.done)
                        }
                        categoryChips
                        if let err = localError {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundColor(.revError)
                                .multilineTextAlignment(.center)
                        }
                        BrandButton(
                            title: "Ajouter",
                            systemImage: "plus.circle.fill",
                            isLoading: isSaving
                        ) {
                            Task { await save() }
                        }
                        .disabled(!canSave || isSaving)
                        .opacity(canSave ? 1 : 0.55)
                        .padding(.top, 4)
                    }
                    .padding(18)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Nouvel article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundColor(.revBrown)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var categoryChips: some View {
        fieldCard(title: "CATÉGORIE", systemImage: "square.grid.2x2.fill") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chipButton(label: "Aucune", isSelected: selectedCategoryId == nil) {
                        selectedCategoryId = nil
                    }
                    ForEach(viewModel.categories) { cat in
                        chipButton(label: cat.name, isSelected: selectedCategoryId == cat.id) {
                            selectedCategoryId = cat.id
                        }
                    }
                }
            }
        }
    }

    private func chipButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(
                        isSelected
                        ? AnyShapeStyle(LinearGradient(colors: [.revOrange, .revRed],
                                                       startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(Color.revYellow.opacity(0.25))
                    )
                )
                .foregroundColor(isSelected ? .white : .revBrown)
        }
    }

    private func fieldCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                }
                .foregroundColor(.revOrange)
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        localError = nil
        defer { isSaving = false }

        let ok = await viewModel.add(label: label, categoryId: selectedCategoryId)
        if ok {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            dismiss()
        } else {
            localError = viewModel.errorMessage ?? "Une erreur est survenue"
        }
    }
}

// MARK: - Edit template item sheet

private struct EditTemplateItemSheet: View {
    @ObservedObject var viewModel: PackingTemplateViewModel
    let item: PackingTemplateItem
    @Environment(\.dismiss) private var dismiss

    @State private var label: String
    @State private var selectedCategoryId: Int?
    @State private var isSaving: Bool = false
    @State private var localError: String?

    init(viewModel: PackingTemplateViewModel, item: PackingTemplateItem) {
        self.viewModel = viewModel
        self.item = item
        _label = State(initialValue: item.label)
        _selectedCategoryId = State(initialValue: item.category_id)
    }

    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.revBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        fieldCard(title: "ARTICLE", systemImage: "tag.fill") {
                            TextField("Article…", text: $label)
                                .font(.system(size: 16, design: .rounded))
                                .textInputAutocapitalization(.sentences)
                                .submitLabel(.done)
                        }
                        categoryChips
                        if let err = localError {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundColor(.revError)
                                .multilineTextAlignment(.center)
                        }
                        BrandButton(
                            title: "Enregistrer",
                            systemImage: "checkmark.circle.fill",
                            isLoading: isSaving
                        ) {
                            Task { await save() }
                        }
                        .disabled(!canSave || isSaving)
                        .opacity(canSave ? 1 : 0.55)
                        .padding(.top, 4)
                    }
                    .padding(18)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Modifier l'article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundColor(.revBrown)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var categoryChips: some View {
        fieldCard(title: "CATÉGORIE", systemImage: "square.grid.2x2.fill") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chipButton(label: "Aucune", isSelected: selectedCategoryId == nil) {
                        selectedCategoryId = nil
                    }
                    ForEach(viewModel.categories) { cat in
                        chipButton(label: cat.name, isSelected: selectedCategoryId == cat.id) {
                            selectedCategoryId = cat.id
                        }
                    }
                }
            }
        }
    }

    private func chipButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(
                        isSelected
                        ? AnyShapeStyle(LinearGradient(colors: [.revOrange, .revRed],
                                                       startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(Color.revYellow.opacity(0.25))
                    )
                )
                .foregroundColor(isSelected ? .white : .revBrown)
        }
    }

    private func fieldCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                }
                .foregroundColor(.revOrange)
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        localError = nil
        defer { isSaving = false }

        let ok = await viewModel.update(item: item, label: label, categoryId: selectedCategoryId)
        if ok {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            dismiss()
        } else {
            localError = viewModel.errorMessage ?? "Une erreur est survenue"
        }
    }
}
