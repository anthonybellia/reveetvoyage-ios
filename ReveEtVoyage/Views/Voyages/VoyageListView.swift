import SwiftUI

struct VoyageListView: View {
    @StateObject private var viewModel = VoyageListViewModel()
    @State private var selectedFilter: Filter = .all

    enum Filter: String, CaseIterable, Identifiable {
        case all, upcoming, past
        var id: Self { self }

        var label: String {
            switch self {
            case .all: return "Tous"
            case .upcoming: return "À venir"
            case .past: return "Terminés"
            }
        }

        func filter(_ v: Voyage) -> Bool {
            switch self {
            case .all: return true
            case .upcoming: return ["en_preparation", "confirme", "en_cours"].contains(v.statut)
            case .past: return ["termine", "annule"].contains(v.statut)
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterChips
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                content
            }
            .background(
                LinearGradient(
                    colors: [Color.revYellow.opacity(0.08), Color.revBackground],
                    startPoint: .top, endPoint: .center
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Voyages")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Int.self) { id in
                VoyageDetailView(voyageId: id)
            }
            .task { if viewModel.voyages.isEmpty { await viewModel.loadVoyages() } }
        }
    }

    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases) { f in
                let isSelected = f == selectedFilter
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        selectedFilter = f
                    }
                } label: {
                    Text(f.label)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(isSelected ? .white : .revBrown)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                isSelected
                                    ? AnyShapeStyle(LinearGradient(colors: [.revOrange, .revRed],
                                                                   startPoint: .leading, endPoint: .trailing))
                                    : AnyShapeStyle(Color.revCardBackground)
                            )
                        )
                        .shadow(color: isSelected ? Color.revOrange.opacity(0.3) : .clear,
                                radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var content: some View {
        let filtered = viewModel.voyages.filter(selectedFilter.filter)
        if viewModel.isLoading && viewModel.voyages.isEmpty {
            LoadingView()
        } else if let error = viewModel.errorMessage, viewModel.voyages.isEmpty {
            ErrorView(message: error) { Task { await viewModel.loadVoyages() } }
        } else if filtered.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "airplane.circle")
                    .font(.system(size: 64))
                    .foregroundColor(.revOrange.opacity(0.4))
                Text(selectedFilter == .all
                     ? "Aucun voyage pour le moment"
                     : "Aucun voyage \(selectedFilter.label.lowercased())")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.revTextSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(filtered) { voyage in
                        NavigationLink(value: voyage.id) {
                            VoyageCard(voyage: voyage)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if voyage.id == viewModel.voyages.last?.id {
                                Task { await viewModel.loadMore() }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .refreshable { await viewModel.refresh() }
        }
    }
}
