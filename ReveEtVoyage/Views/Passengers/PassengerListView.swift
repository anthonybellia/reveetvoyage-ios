import SwiftUI

struct PassengerListView: View {
    @StateObject private var viewModel = PassengerListViewModel()
    @State private var showFormSheet: Bool = false
    @State private var editingPassenger: Passenger? = nil

    var body: some View {
        NavigationStack {
            content
                .background(
                    LinearGradient(colors: [Color.revYellow.opacity(0.08), Color.revBackground],
                                   startPoint: .top, endPoint: .center)
                        .ignoresSafeArea()
                )
                .navigationTitle("Passagers")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            editingPassenger = nil
                            showFormSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(LinearGradient(colors: [.revOrange, .revRed],
                                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                        }
                    }
                }
                .sheet(isPresented: $showFormSheet) {
                    PassengerFormView(
                        passenger: editingPassenger,
                        onSave: { req in
                            if let p = editingPassenger {
                                return await viewModel.update(id: p.id, request: req)
                            } else {
                                return await viewModel.create(req)
                            }
                        }
                    )
                    .presentationDetents([.large])
                }
                .task { if viewModel.passengers.isEmpty { await viewModel.load() } }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.passengers.isEmpty {
            LoadingView()
        } else if let error = viewModel.errorMessage, viewModel.passengers.isEmpty {
            ErrorView(message: error) { Task { await viewModel.load() } }
        } else if viewModel.passengers.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 64))
                    .foregroundColor(.revOrange.opacity(0.4))
                Text("Aucun passager enregistré")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.revText)
                Text("Ajoute des passagers pour gagner du temps lors d'un devis")
                    .font(.system(size: 13))
                    .foregroundColor(.revTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                BrandButton(title: "Ajouter un passager", systemImage: "plus", style: .primary) {
                    editingPassenger = nil
                    showFormSheet = true
                }
                .padding(.horizontal, 50)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.passengers) { passenger in
                        PassengerCard(passenger: passenger)
                            .contextMenu {
                                Button {
                                    editingPassenger = passenger
                                    showFormSheet = true
                                } label: {
                                    Label("Modifier", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    Task { await viewModel.delete(id: passenger.id) }
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                            .onTapGesture {
                                editingPassenger = passenger
                                showFormSheet = true
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .refreshable { await viewModel.load() }
        }
    }
}

struct PassengerCard: View {
    let passenger: Passenger

    var body: some View {
        GlassCard(padding: 14) {
            HStack(spacing: 14) {
                AvatarView(firstName: passenger.prenom, lastName: passenger.nom, size: 48)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(passenger.fullName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.revText)
                        if passenger.is_default {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.revYellow)
                        }
                    }
                    if let nat = passenger.nationalite, !nat.isEmpty {
                        Text(nat)
                            .font(.system(size: 12))
                            .foregroundColor(.revTextSecondary)
                    }
                    if let doc = passenger.type_doc, let num = passenger.num_doc {
                        Text("\(doc.uppercased()) · \(num)")
                            .font(.system(size: 11))
                            .foregroundColor(.revOrange)
                    }
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.revTextSecondary)
            }
        }
    }
}
