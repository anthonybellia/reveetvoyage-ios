import SwiftUI

struct AdminDestinationsView: View {
    @State private var destinations: [AdminDestination] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showCreate: Bool = false
    @State private var editing: AdminDestination? = nil
    @State private var pendingDelete: AdminDestination? = nil
    @State private var showDeleteConfirm: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.revYellow.opacity(0.08), Color.revBackground],
                           startPoint: .top, endPoint: .center).ignoresSafeArea()
            content
        }
        .navigationTitle("Destinations")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus.circle.fill").foregroundColor(.revOrange)
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            DestinationFormSheet(mode: .create) { saved in
                destinations.insert(saved, at: 0)
            }
        }
        .sheet(item: $editing) { d in
            DestinationFormSheet(mode: .edit(d)) { saved in
                if let i = destinations.firstIndex(where: { $0.id == saved.id }) {
                    destinations[i] = saved
                }
            }
        }
        .confirmationDialog("Supprimer cette destination ?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                guard let d = pendingDelete else { return }
                Task {
                    try? await ContentAdminService.shared.deleteDestination(id: d.id)
                    destinations.removeAll { $0.id == d.id }
                    pendingDelete = nil
                }
            }
            Button("Annuler", role: .cancel) { pendingDelete = nil }
        } message: {
            if let d = pendingDelete { Text("\(d.nom) sera supprimée définitivement.") }
        }
        .task { if destinations.isEmpty { await load() } }
        .refreshable { await load() }
    }

    @ViewBuilder private var content: some View {
        if isLoading && destinations.isEmpty {
            LoadingView()
        } else if let err = errorMessage, destinations.isEmpty {
            ErrorView(message: err) { Task { await load() } }
        } else if destinations.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "map.circle").font(.system(size: 48)).foregroundColor(.revOrange.opacity(0.4))
                Text("Aucune destination").foregroundColor(.revTextSecondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(destinations) { d in
                        DestinationRow(destination: d)
                            .contextMenu {
                                Button { editing = d } label: { Label("Modifier", systemImage: "pencil") }
                                Button(role: .destructive) {
                                    pendingDelete = d
                                    showDeleteConfirm = true
                                } label: { Label("Supprimer", systemImage: "trash") }
                            }
                            .onTapGesture { editing = d }
                    }
                }.padding(.horizontal, 14).padding(.vertical, 8)
            }
        }
    }

    private func load() async {
        isLoading = true; errorMessage = nil; defer { isLoading = false }
        do { destinations = try await ContentAdminService.shared.listDestinations() }
        catch { errorMessage = error.localizedDescription }
    }
}

struct DestinationRow: View {
    let destination: AdminDestination

    var body: some View {
        GlassCard(padding: 12) {
            HStack(spacing: 12) {
                if let urlString = destination.image_principale, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().aspectRatio(contentMode: .fill)
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        default:
                            RoundedRectangle(cornerRadius: 10).fill(Color.revOrange.opacity(0.12))
                                .frame(width: 56, height: 56)
                                .overlay(Image(systemName: "photo").foregroundColor(.revOrange))
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 10).fill(Color.revOrange.opacity(0.12))
                        .frame(width: 56, height: 56)
                        .overlay(Image(systemName: "mappin.and.ellipse").foregroundColor(.revOrange))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(destination.nom)
                        .font(.system(size: 15, weight: .bold)).foregroundColor(.revText)
                    Text("\(destination.continent) · \(destination.pays)")
                        .font(.system(size: 11)).foregroundColor(.revTextSecondary)
                    HStack(spacing: 6) {
                        if destination.featured {
                            Label("Vedette", systemImage: "star.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.revYellow)
                        }
                        if !destination.actif {
                            Label("Inactif", systemImage: "eye.slash.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.revTextSecondary)
                        }
                    }
                }
                Spacer()
                if let p = destination.prix_depuis {
                    Text(String(format: "€%.0f", p))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.revOrange)
                }
            }
        }
    }
}

struct DestinationFormSheet: View {
    enum Mode { case create; case edit(AdminDestination) }

    let mode: Mode
    let onSaved: (AdminDestination) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var nom: String = ""
    @State private var continent: String = ""
    @State private var pays: String = ""
    @State private var descriptionCourte: String = ""
    @State private var descriptionLong: String = ""
    @State private var prixDepuis: String = ""
    @State private var dureeJours: String = ""
    @State private var metaTitle: String = ""
    @State private var metaDescription: String = ""
    @State private var featured: Bool = false
    @State private var actif: Bool = true

    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationView {
            Form {
                Section("Informations") {
                    TextField("Nom *", text: $nom).autocapitalization(.words)
                    TextField("Continent *", text: $continent)
                    TextField("Pays *", text: $pays)
                }
                Section("Description") {
                    TextField("Résumé court (carte)", text: $descriptionCourte, axis: .vertical)
                        .lineLimit(2...3)
                    TextEditor(text: $descriptionLong).frame(minHeight: 120)
                }
                Section("Détails") {
                    HStack {
                        Text("Prix depuis")
                        Spacer()
                        TextField("0", text: $prixDepuis).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        Text("€").foregroundColor(.revTextSecondary)
                    }
                    HStack {
                        Text("Durée")
                        Spacer()
                        TextField("0", text: $dureeJours).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        Text("jours").foregroundColor(.revTextSecondary)
                    }
                    Toggle("Mise en avant", isOn: $featured)
                    Toggle("Actif (visible sur le site)", isOn: $actif)
                }
                Section("SEO") {
                    TextField("Meta title", text: $metaTitle)
                    TextField("Meta description", text: $metaDescription, axis: .vertical).lineLimit(2...3)
                }
                if let err = errorMessage {
                    Section { Text(err).foregroundColor(.red).font(.system(size: 13)) }
                }
            }
            .navigationTitle(isCreate ? "Nouvelle destination" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView().tint(.revOrange) }
                        else { Text("Enregistrer").fontWeight(.semibold).foregroundColor(.revOrange) }
                    }
                    .disabled(isSaving || !canSave)
                }
            }
            .onAppear(perform: preload)
        }
    }

    private var isCreate: Bool { if case .create = mode { return true } else { return false } }
    private var canSave: Bool {
        !nom.trimmingCharacters(in: .whitespaces).isEmpty
            && !continent.trimmingCharacters(in: .whitespaces).isEmpty
            && !pays.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func preload() {
        guard case .edit(let d) = mode else { return }
        nom = d.nom
        continent = d.continent
        pays = d.pays
        descriptionCourte = d.description_courte ?? ""
        descriptionLong = d.description ?? ""
        if let p = d.prix_depuis { prixDepuis = String(format: "%g", p) }
        if let dj = d.duree_jours { dureeJours = String(dj) }
        metaTitle = d.meta_title ?? ""
        metaDescription = d.meta_description ?? ""
        featured = d.featured
        actif = d.actif
    }

    private func save() async {
        errorMessage = nil
        isSaving = true; defer { isSaving = false }
        let payload = AdminDestinationPayload(
            nom: nom, continent: continent, pays: pays,
            description_courte: descriptionCourte.isEmpty ? nil : descriptionCourte,
            description: descriptionLong.isEmpty ? nil : descriptionLong,
            prix_depuis: Double(prixDepuis.replacingOccurrences(of: ",", with: ".")),
            duree_jours: Int(dureeJours),
            meta_title: metaTitle.isEmpty ? nil : metaTitle,
            meta_description: metaDescription.isEmpty ? nil : metaDescription,
            featured: featured, actif: actif
        )
        do {
            let saved: AdminDestination
            switch mode {
            case .create:
                saved = try await ContentAdminService.shared.createDestination(payload)
            case .edit(let d):
                saved = try await ContentAdminService.shared.updateDestination(id: d.id, payload)
            }
            onSaved(saved)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
