import SwiftUI

struct DevisDetailView: View {
    @State private var devis: Devis
    @State private var appear: Bool = false
    @State private var showEditSheet: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var showConvertConfirm: Bool = false
    @State private var isConverting: Bool = false
    @State private var conversionError: String? = nil
    @State private var createdVoyageId: Int? = nil
    @State private var showConversionSuccess: Bool = false

    // Notes internes threadées (admin uniquement)
    @State private var notes: [DevisNote] = []
    @State private var notesLoading: Bool = false
    @State private var notesError: String? = nil
    @State private var newNoteText: String = ""
    @State private var isAddingNote: Bool = false
    @Environment(\.dismiss) private var dismiss

    private var isAdmin: Bool {
        AuthService.shared.isAdmin
    }

    init(devis: Devis) {
        _devis = State(initialValue: devis)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroCard
                    .padding(.horizontal, 18)
                    .padding(.top, 8)

                detailsCard
                    .padding(.horizontal, 18)

                if !preferencesItems.isEmpty {
                    preferencesCard
                        .padding(.horizontal, 18)
                }

                if let message = devis.message, !message.isEmpty {
                    messageCard(message)
                        .padding(.horizontal, 18)
                }

                if isAdmin {
                    notesCard
                        .padding(.horizontal, 18)
                }
            }
            .padding(.bottom, 30)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 16)
        }
        .background(
            LinearGradient(colors: [Color.revYellow.opacity(0.08), Color.revBackground],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        )
        .navigationTitle("Demande #\(devis.id)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { appear = true }
        }
        .task {
            if isAdmin { await loadNotes() }
        }
        .toolbar {
            if isAdmin {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Modifier la demande", systemImage: "pencil")
                        }
                        if devis.voyage_id == nil {
                            Button {
                                showConvertConfirm = true
                            } label: {
                                Label("Convertir en voyage", systemImage: "airplane.circle")
                            }
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundColor(.revOrange)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            DevisFormSheet(devis: devis) { updated in
                devis = updated
            }
        }
        .confirmationDialog(
            "Supprimer cette demande ?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                Task {
                    try? await DevisService.shared.deleteDevis(id: devis.id)
                    dismiss()
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("La demande de \(devis.prenom) \(devis.nom) sera supprimée définitivement.")
        }
        .confirmationDialog(
            "Convertir cette demande en voyage ?",
            isPresented: $showConvertConfirm,
            titleVisibility: .visible
        ) {
            Button(isConverting ? "Conversion…" : "Créer le voyage", role: nil) {
                Task { await convertToVoyage() }
            }
            .disabled(isConverting)
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Un nouveau voyage sera créé et lié à cette demande.")
        }
        .alert("Conversion impossible", isPresented: .constant(conversionError != nil)) {
            Button("OK") { conversionError = nil }
        } message: {
            Text(conversionError ?? "")
        }
        .alert("Voyage créé !", isPresented: $showConversionSuccess) {
            Button("OK") {}
        } message: {
            Text("Le voyage #\(createdVoyageId ?? 0) a été créé. Tu peux le retrouver dans l'onglet Voyages.")
        }
    }

    private func convertToVoyage() async {
        isConverting = true
        defer { isConverting = false }
        do {
            let voyageId = try await DevisService.shared.convertToVoyage(id: devis.id)
            createdVoyageId = voyageId
            showConversionSuccess = true
        } catch {
            conversionError = error.localizedDescription
        }
    }

    private var heroCard: some View {
        GlassCard(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        StatusBadge.devisStatut(devis.statut)
                        Text(devis.titre_voyage ?? devis.destination_souhaitee ?? "Demande de voyage")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.revText)
                    }
                    Spacer()
                    Image(systemName: heroIcon)
                        .font(.system(size: 38))
                        .foregroundStyle(LinearGradient(colors: [.revOrange, .revRed],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                }

                if let dest = devis.destination ?? devis.destination_souhaitee {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 13))
                        Text(dest)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.revTextSecondary)
                }

                if let owner = devis.owner {
                    OwnerLabel(owner: owner)
                }
            }
        }
    }

    private var heroIcon: String {
        switch devis.type_voyage {
        case "couple": return "heart.circle.fill"
        case "famille": return "figure.2.and.child.holdinghands"
        case "amis": return "person.3.fill"
        case "solo": return "figure.wave"
        case "lune_de_miel": return "sparkles"
        default: return "airplane.circle.fill"
        }
    }

    private var detailsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Détails", systemImage: "info.circle.fill")

                detailRow(icon: "person.2.fill", label: "Voyageurs",
                          value: devis.nb_personnes.map { "\($0) personne(s)" } ?? "—")
                detailRow(icon: "calendar", label: "Dates",
                          value: devis.dates_souhaitees ?? devis.flexible_dates ?? "—")
                detailRow(icon: "clock", label: "Durée", value: devis.duree ?? "—")
                detailRow(icon: "airplane.departure", label: "Départ depuis",
                          value: devis.lieu_depart ?? "—")
                detailRow(icon: "eurosign.circle", label: "Budget",
                          value: devis.budget ?? "—")
                detailRow(icon: "heart.fill", label: "Type de voyage",
                          value: devis.type_voyage?.replacingOccurrences(of: "_", with: " ").capitalized ?? "—")
            }
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.revOrange)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.revTextSecondary)
                Text(value)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.revText)
            }
            Spacer()
        }
    }

    private var preferencesItems: [(String, String)] {
        var items: [(String, String)] = []
        if let v = devis.cadre, !v.isEmpty { items.append(("Cadre", v)) }
        if let v = devis.hebergement, !v.isEmpty { items.append(("Hébergement", v)) }
        if let v = devis.activites, !v.isEmpty { items.append(("Activités", v)) }
        if let v = devis.activites_eviter, !v.isEmpty { items.append(("À éviter", v)) }
        if let v = devis.imperatifs, !v.isEmpty { items.append(("Impératifs", v)) }
        if let v = devis.evenement, !v.isEmpty { items.append(("Événement", v)) }
        if let v = devis.besoins_specifiques, !v.isEmpty { items.append(("Besoins spécifiques", v)) }
        return items
    }

    private var preferencesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "Préférences", systemImage: "slider.horizontal.3")
                ForEach(preferencesItems, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.0)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.revTextSecondary)
                        Text(item.1)
                            .font(.system(size: 13))
                            .foregroundColor(.revText)
                    }
                }
            }
        }
    }

    private func messageCard(_ message: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Ton message", systemImage: "text.quote")
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.revText)
            }
        }
    }

    // MARK: - Notes internes (admin)

    private var notesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "Notes internes", systemImage: "lock.doc.fill",
                             trailing: notes.isEmpty ? nil : "\(notes.count)")

                if notesLoading && notes.isEmpty {
                    HStack {
                        ProgressView()
                        Text("Chargement…")
                            .font(.system(size: 13))
                            .foregroundColor(.revTextSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                } else if let notesError {
                    VStack(spacing: 8) {
                        Text(notesError)
                            .font(.system(size: 13))
                            .foregroundColor(.revRed)
                            .multilineTextAlignment(.center)
                        BrandButton(title: "Réessayer", style: .ghost) {
                            Task { await loadNotes() }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                } else if notes.isEmpty {
                    Text("Aucune note pour l'instant. Ajoute une note visible uniquement par les administrateurs.")
                        .font(.system(size: 13))
                        .foregroundColor(.revTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 10) {
                        ForEach(notes) { note in
                            noteRow(note)
                        }
                    }
                }

                Divider()
                    .padding(.vertical, 2)

                composer
            }
        }
    }

    private func noteRow(_ note: DevisNote) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.revOrange)
                    Text(note.author)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.revText)
                    Spacer(minLength: 4)
                    Text(noteDateLabel(note.created_at))
                        .font(.system(size: 11))
                        .foregroundColor(.revTextSecondary)
                }
                Text(note.contenu)
                    .font(.system(size: 14))
                    .foregroundColor(.revText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { await deleteNote(note) }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.revRed)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Supprimer la note")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.revYellow.opacity(0.10))
        )
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Ajouter une note interne…", text: $newNoteText, axis: .vertical)
                .font(.system(size: 14))
                .lineLimit(1...4)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.revBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
                )

            BrandButton(
                title: "Ajouter",
                systemImage: "plus.circle.fill",
                isLoading: isAddingNote,
                style: .primary
            ) {
                Task { await addNote() }
            }
            .disabled(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAddingNote)
            .opacity(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
        }
    }

    private func noteDateLabel(_ raw: String) -> String {
        guard let date = raw.toDate() else { return raw }
        return date.formatted(dateStyle: .medium, timeStyle: .short)
    }

    // MARK: - Notes actions

    private func loadNotes() async {
        notesLoading = true
        notesError = nil
        defer { notesLoading = false }
        do {
            notes = try await DevisService.shared.fetchNotes(devisId: devis.id)
        } catch {
            notesError = error.localizedDescription
        }
    }

    private func addNote() async {
        let trimmed = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isAddingNote = true
        defer { isAddingNote = false }
        do {
            _ = try await DevisService.shared.addNote(devisId: devis.id, contenu: trimmed)
            newNoteText = ""
            await loadNotes()
        } catch {
            notesError = error.localizedDescription
        }
    }

    private func deleteNote(_ note: DevisNote) async {
        do {
            try await DevisService.shared.deleteNote(devisId: devis.id, noteId: note.id)
            await loadNotes()
        } catch {
            notesError = error.localizedDescription
        }
    }
}
