import SwiftUI

struct FactureListView: View {
    @State private var factures: [Facture] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var page: Int = 1
    @State private var canLoadMore: Bool = true

    private var isAdmin: Bool {
        AuthService.shared.currentUser?.role == "admin"
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.revYellow.opacity(0.08), Color.revBackground],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
            content
        }
        .navigationTitle("Factures")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: Facture.self) { facture in
            FactureDetailView(facture: facture)
        }
        .task { if factures.isEmpty { await load() } }
        .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && factures.isEmpty {
            LoadingView()
        } else if let error = errorMessage, factures.isEmpty {
            ErrorView(message: error) { Task { await load() } }
        } else if factures.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 56))
                    .foregroundColor(.revOrange.opacity(0.4))
                Text(isAdmin ? "Aucune facture" : "Aucune facture pour le moment")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.revTextSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(factures) { facture in
                        NavigationLink(value: facture) {
                            FactureRow(facture: facture)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if facture.id == factures.last?.id { Task { await loadMore() } }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let (items, hasMore) = try await FactureService.shared.listFactures(page: 1)
            factures = items
            page = 1
            canLoadMore = hasMore
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard canLoadMore, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let (items, hasMore) = try await FactureService.shared.listFactures(page: page + 1)
            factures.append(contentsOf: items)
            page += 1
            canLoadMore = hasMore
        } catch {
            // silent
        }
    }
}

struct FactureRow: View {
    let facture: Facture

    var body: some View {
        GlassCard(padding: 14) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(statutColor.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(statutColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(facture.numero)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.revText)
                    Text(facture.client_nom)
                        .font(.system(size: 12))
                        .foregroundColor(.revTextSecondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "€%.2f", facture.total))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.revText)
                    Text(statutLabel)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(statutColor)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(statutColor.opacity(0.14)))
                }
            }
        }
    }

    private var statutColor: Color {
        switch facture.statut {
        case "payee": return .green
        case "envoyee": return .blue
        case "annulee": return .red
        default: return .revOrange
        }
    }

    private var statutLabel: String {
        switch facture.statut {
        case "payee": return "Payée"
        case "envoyee": return "Envoyée"
        case "annulee": return "Annulée"
        case "brouillon": return "Brouillon"
        default: return facture.statut.capitalized
        }
    }
}
