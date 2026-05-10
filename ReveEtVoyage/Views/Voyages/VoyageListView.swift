import SwiftUI

struct VoyageListView: View {
    @StateObject private var viewModel = VoyageListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.voyages.isEmpty {
                    LoadingView()
                } else if let error = viewModel.errorMessage, viewModel.voyages.isEmpty {
                    ErrorView(message: error) {
                        Task { await viewModel.loadVoyages() }
                    }
                } else if viewModel.voyages.isEmpty {
                    EmptyStateView(message: "Aucun voyage")
                } else {
                    List {
                        ForEach(viewModel.voyages) { voyage in
                            VoyageRowView(voyage: voyage)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                                .onAppear {
                                    if voyage.id == viewModel.voyages.last?.id {
                                        Task { await viewModel.loadMore() }
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await viewModel.refresh() }
                }
            }
            .navigationTitle("Voyages")
            .background(Color.revBackground.ignoresSafeArea())
            .task {
                if viewModel.voyages.isEmpty {
                    await viewModel.loadVoyages()
                }
            }
        }
    }
}
