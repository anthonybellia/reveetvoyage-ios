import SwiftUI

struct DevisListView: View {
    @StateObject private var viewModel = DevisListViewModel()

    var body: some View {
        NavigationStack {
            content
                .background(
                    LinearGradient(
                        colors: [Color.revYellow.opacity(0.08), Color.revBackground],
                        startPoint: .top, endPoint: .center
                    )
                    .ignoresSafeArea()
                )
                .navigationTitle("Mes demandes")
                .navigationBarTitleDisplayMode(.large)
                .navigationDestination(for: Devis.self) { devis in
                    DevisDetailView(devis: devis)
                }
                .task { if viewModel.devis.isEmpty { await viewModel.load() } }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.devis.isEmpty {
            LoadingView()
        } else if let error = viewModel.errorMessage, viewModel.devis.isEmpty {
            ErrorView(message: error) { Task { await viewModel.load() } }
        } else if viewModel.devis.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundColor(.revOrange.opacity(0.4))
                Text("Aucune demande de voyage")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.revText)
                Text("Tes futures demandes apparaîtront ici")
                    .font(.system(size: 13))
                    .foregroundColor(.revTextSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 22) {
                    if !viewModel.pending.isEmpty {
                        section(title: "En attente", icon: "clock.fill", items: viewModel.pending)
                    }
                    if !viewModel.validated.isEmpty {
                        section(title: "Validés", icon: "checkmark.seal.fill", items: viewModel.validated)
                    }
                    if !viewModel.others.isEmpty {
                        section(title: "Archivés", icon: "archivebox.fill", items: viewModel.others)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .refreshable { await viewModel.refresh() }
        }
    }

    private func section(title: String, icon: String, items: [Devis]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: title, systemImage: icon, trailing: "\(items.count)")
            ForEach(items) { devis in
                NavigationLink(value: devis) {
                    DevisDetailedRow(devis: devis)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct DevisDetailedRow: View {
    let devis: Devis

    var body: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(devis.titre_voyage ?? devis.destination ?? devis.destination_souhaitee ?? "Demande de voyage")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.revText)
                            .lineLimit(2)

                        if let dest = devis.destination ?? devis.destination_souhaitee {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 11))
                                Text(dest)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.revTextSecondary)
                        }

                        if let owner = devis.owner {
                            OwnerLabel(owner: owner)
                        }
                    }
                    Spacer()
                    StatusBadge.devisStatut(devis.statut)
                }

                HStack(spacing: 12) {
                    if let nb = devis.nb_personnes {
                        chip(icon: "person.fill", text: "\(nb)")
                    }
                    if let duree = devis.duree {
                        chip(icon: "calendar", text: duree)
                    }
                    if let typ = devis.type_voyage {
                        chip(icon: "heart.fill", text: typ.replacingOccurrences(of: "_", with: " ").capitalized)
                    }
                    Spacer()
                }
            }
        }
    }

    private func chip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.revOrange)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.revOrange.opacity(0.10)))
    }
}

extension Devis: Hashable {
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    public static func == (lhs: Devis, rhs: Devis) -> Bool { lhs.id == rhs.id }
}
