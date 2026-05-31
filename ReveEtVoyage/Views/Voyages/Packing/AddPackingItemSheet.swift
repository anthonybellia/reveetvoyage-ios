import SwiftUI

struct AddPackingItemSheet: View {
    @ObservedObject var viewModel: PackingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var label: String = ""
    @State private var selectedCategoryId: Int? = nil
    @State private var keepForNext: Bool = false
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
                        labelField
                        categoryPicker
                        keepForNextToggle
                        if let err = localError {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundColor(.revError)
                                .multilineTextAlignment(.center)
                        }
                        saveButton
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

    // MARK: - Sections

    private var labelField: some View {
        fieldCard(title: "ARTICLE", systemImage: "tag.fill") {
            TextField("Ex : Crème solaire, chargeur…", text: $label)
                .font(.system(size: 16, design: .rounded))
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
        }
    }

    private var categoryPicker: some View {
        fieldCard(title: "CATÉGORIE", systemImage: "square.grid.2x2.fill") {
            if viewModel.categories.isEmpty {
                Text("Chargement des catégories…")
                    .font(.system(size: 13))
                    .foregroundColor(.revTextSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // "None" chip
                        Button {
                            selectedCategoryId = nil
                        } label: {
                            Text("Aucune")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(
                                        selectedCategoryId == nil
                                        ? AnyShapeStyle(LinearGradient(colors: [.revOrange, .revRed],
                                                                       startPoint: .leading, endPoint: .trailing))
                                        : AnyShapeStyle(Color.revYellow.opacity(0.25))
                                    )
                                )
                                .foregroundColor(selectedCategoryId == nil ? .white : .revBrown)
                        }

                        ForEach(viewModel.categories) { cat in
                            Button {
                                selectedCategoryId = cat.id
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: cat.systemImage)
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(cat.name)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(
                                        selectedCategoryId == cat.id
                                        ? AnyShapeStyle(LinearGradient(colors: [.revOrange, .revRed],
                                                                       startPoint: .leading, endPoint: .trailing))
                                        : AnyShapeStyle(Color.revYellow.opacity(0.25))
                                    )
                                )
                                .foregroundColor(selectedCategoryId == cat.id ? .white : .revBrown)
                            }
                        }
                    }
                }
            }
        }
    }

    private var keepForNextToggle: some View {
        fieldCard(title: "PROCHAINS VOYAGES", systemImage: "arrow.clockwise") {
            Toggle(isOn: $keepForNext) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Garder pour mes prochains voyages")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.revText)
                    Text("Cet article sera ajouté à ta liste de base")
                        .font(.system(size: 11))
                        .foregroundColor(.revTextSecondary)
                }
            }
            .tint(.revOrange)
        }
    }

    private var saveButton: some View {
        BrandButton(
            title: "Ajouter",
            systemImage: "plus.circle.fill",
            isLoading: isSaving
        ) {
            Task { await save() }
        }
        .disabled(!canSave || isSaving)
        .opacity(canSave ? 1 : 0.55)
    }

    // MARK: - Helpers

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

        let ok = await viewModel.add(
            label: label,
            categoryId: selectedCategoryId,
            keepForNext: keepForNext
        )

        if ok {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            dismiss()
        } else {
            localError = viewModel.errorMessage ?? "Une erreur est survenue"
        }
    }
}
