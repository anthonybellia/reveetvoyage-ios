import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var authService: AuthService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let user = authService.currentUser {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bienvenue, \(user.prenom) !")
                                .font(.title2.bold())
                                .foregroundColor(.revBrown)
                            Text("Vos prochains voyages")
                                .font(.subheadline)
                                .foregroundColor(.revTextSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .revSection()
                        .padding(.horizontal)
                    }

                    if viewModel.isLoading {
                        ProgressView().padding()
                    } else if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.revError)
                            .padding()
                    } else if viewModel.voyages.isEmpty {
                        EmptyStateView(message: "Aucun voyage pour l'instant")
                    } else {
                        Text("Voyages récents")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                        ForEach(viewModel.voyages) { voyage in
                            VoyageRowView(voyage: voyage)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Accueil")
            .background(Color.revBackground.ignoresSafeArea())
            .task { await viewModel.loadData() }
        }
    }
}

struct VoyageRowView: View {
    let voyage: Voyage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(voyage.titre)
                .font(.headline)
                .foregroundColor(.revBrown)
            Text(voyage.destination)
                .font(.subheadline)
                .foregroundColor(.revTextSecondary)
            HStack {
                Text(voyage.statut_label)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.revYellow.opacity(0.3))
                    .cornerRadius(6)
                Spacer()
                Text(String(format: "€ %.2f", voyage.montant_total))
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .revSection()
    }
}
