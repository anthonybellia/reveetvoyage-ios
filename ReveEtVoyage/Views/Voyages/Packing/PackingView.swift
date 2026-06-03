import SwiftUI

struct PackingView: View {
    @StateObject private var viewModel: PackingViewModel
    @State private var showAddItem = false

    init(voyageId: Int) {
        _viewModel = StateObject(wrappedValue: PackingViewModel(voyageId: voyageId))
    }

    var body: some View {
        ZStack {
            backgroundLayer

            Group {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    LoadingView()
                } else if let error = viewModel.errorMessage, viewModel.items.isEmpty {
                    ErrorView(message: error) { Task { await viewModel.load() } }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            progressCard
                            if !viewModel.items.isEmpty {
                                generateButton
                            }
                            itemsList
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .padding(.bottom, 100)
                    }
                    .refreshable { await viewModel.refresh() }
                }
            }

            addItemFAB
        }
        .navigationTitle("Liste de bagage")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(destination: PackingTemplateView()) {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Ma liste de base")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.revOrange)
                }
            }
        }
        .task { await viewModel.load() }
        .sheet(isPresented: $showAddItem) {
            AddPackingItemSheet(viewModel: viewModel)
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [Color.revYellow.opacity(0.10), Color.revBackground],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Progress card

    private var progressCard: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "suitcase.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.revOrange)
                        Text("\(viewModel.checkedCount) / \(viewModel.totalCount) prêts")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.revText)
                    }
                    Spacer()
                    Text("\(Int(viewModel.progress * 100)) %")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.revOrange)
                }

                ProgressBar(value: viewModel.progress)
                    .frame(height: 10)
            }
        }
    }

    // MARK: - Items list grouped by category

    private var itemsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.groupedItems.isEmpty {
                GlassCard {
                    VStack(spacing: 12) {
                        Image(systemName: "checklist")
                            .font(.system(size: 32))
                            .foregroundColor(.revTextSecondary)
                        Text("Aucun article dans ta liste.")
                            .font(.system(size: 14))
                            .foregroundColor(.revTextSecondary)
                        Text("Génère une liste classique pour démarrer, ou appuie sur + pour ajouter le premier.")
                            .font(.system(size: 12))
                            .foregroundColor(.revTextSecondary)
                            .multilineTextAlignment(.center)
                        generateButton
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            } else {
                ForEach(viewModel.groupedItems, id: \.category?.id) { group in
                    categorySection(group: group)
                }
            }
        }
    }

    private func categorySection(group: (category: PackingCategory?, items: [VoyagePackingItem])) -> some View {
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
                let checked = group.items.filter { $0.is_checked }.count
                Text("\(checked)/\(group.items.count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
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
                            PackingItemRow(item: item) {
                                Task { await viewModel.toggle(item: item) }
                            }
                            .contextMenu {
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

    // MARK: - Generate classic list button

    private var generateButton: some View {
        BrandButton(
            title: "Générer une liste classique",
            systemImage: "wand.and.stars",
            isLoading: viewModel.isGenerating,
            style: .secondary
        ) {
            Task { await viewModel.generateClassic() }
        }
    }

    // MARK: - FAB

    private var addItemFAB: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showAddItem = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(
                                colors: [.revOrange, .revRed],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.revOrange.opacity(0.45), radius: 12, x: 0, y: 6)
                }
                .padding(.trailing, 22)
                .padding(.bottom, 22)
            }
        }
    }
}

// MARK: - PackingItemRow

private struct PackingItemRow: View {
    let item: VoyagePackingItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                Image(systemName: item.is_checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(item.is_checked ? .revOrange : Color.gray.opacity(0.4))
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: item.is_checked)

                Text(item.label)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(item.is_checked ? .revTextSecondary : .revText)
                    .strikethrough(item.is_checked, color: .revTextSecondary)
                    .animation(.easeOut(duration: 0.2), value: item.is_checked)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}
