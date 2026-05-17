import SwiftUI

struct DevisWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService

    @StateObject private var draft = DevisDraft()
    @State private var currentStep: Int = 1
    @State private var isSubmitting = false
    @State private var submissionError: String? = nil
    @State private var submittedDevis: Devis? = nil

    private let totalSteps = 7

    var body: some View {
        NavigationStack {
            ZStack {
                Color.revBackground.ignoresSafeArea()

                if let devis = submittedDevis {
                    DevisConfirmationView(devis: devis) { dismiss() }
                        .transition(.opacity.combined(with: .scale))
                } else {
                    VStack(spacing: 0) {
                        progressHeader

                        stepContent
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        bottomBar
                    }
                }
            }
            .toolbar {
                if submittedDevis == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler") { dismiss() }
                            .foregroundColor(.revOrange)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("Erreur", isPresented: Binding(
                get: { submissionError != nil },
                set: { if !$0 { submissionError = nil } }
            )) {
                Button("Réessayer") { submit() }
                Button("OK", role: .cancel) { }
            } message: {
                Text(submissionError ?? "")
            }
        }
        .onAppear { draft.preFill(from: authService.currentUser) }
    }

    // MARK: - Progress header

    private var progressHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Étape \(currentStep) sur \(totalSteps)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.revTextSecondary)
                Spacer()
                Text(stepTitle(currentStep))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.revOrange)
            }
            ProgressView(value: Double(currentStep), total: Double(totalSteps))
                .progressViewStyle(.linear)
                .tint(.revOrange)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private func stepTitle(_ step: Int) -> String {
        switch step {
        case 1: return "Identité"
        case 2: return "Voyageurs"
        case 3: return "Dates"
        case 4: return "Destination"
        case 5: return "Séjour"
        case 6: return "Activités"
        case 7: return "Détails"
        default: return ""
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch currentStep {
                case 1: Step1IdentiteView(draft: draft, user: authService.currentUser)
                case 2: Step2VoyageursView(draft: draft)
                case 3: Step3DatesView(draft: draft)
                case 4: Step4DestinationView(draft: draft)
                case 5: Step5SejourView(draft: draft)
                case 6: Step6ActivitesView(draft: draft)
                case 7: Step7DetailsView(draft: draft)
                default: EmptyView()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .id(currentStep)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                if currentStep > 1 {
                    BrandButton(title: "Précédent", systemImage: "chevron.left", style: .secondary) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            currentStep -= 1
                        }
                    }
                }
                if currentStep < totalSteps {
                    BrandButton(title: "Suivant", systemImage: "chevron.right", style: .primary) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            currentStep += 1
                        }
                    }
                } else {
                    BrandButton(title: "Envoyer à Matilda",
                                systemImage: "paperplane.fill",
                                isLoading: isSubmitting,
                                style: .primary) {
                        submit()
                    }
                    .disabled(!draft.isStepValid(7) || isSubmitting)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Color.revBackground
                .shadow(color: .black.opacity(0.06), radius: 10, y: -4)
                .mask(Rectangle().padding(.top, -20))
        )
    }

    // MARK: - Submit

    private func submit() {
        isSubmitting = true
        submissionError = nil
        let request = draft.buildRequest()
        Task {
            do {
                let devis = try await DevisService.shared.createDevis(request: request)
                await MainActor.run {
                    isSubmitting = false
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        submittedDevis = devis
                    }
                }
            } catch let error as NetworkError {
                await MainActor.run {
                    isSubmitting = false
                    submissionError = errorMessage(for: error)
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    submissionError = "Échec de l'envoi. Vérifie ta connexion."
                }
            }
        }
    }

    private func errorMessage(for error: NetworkError) -> String {
        switch error {
        case .unauthorized: return "Tu dois être connecté pour envoyer une demande."
        case .validationError(let errs):
            return errs.values.flatMap { $0 }.first ?? "Validation échouée."
        case .serverError(_, let msg): return msg ?? "Erreur serveur. Réessaie plus tard."
        default: return "Échec de l'envoi. Vérifie ta connexion."
        }
    }
}

// MARK: - Step 1 — Identité

private struct Step1IdentiteView: View {
    @ObservedObject var draft: DevisDraft
    let user: User?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(title: "Commençons !",
                       subtitle: "Je vais créer un voyage rien que pour toi.")

            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    ReadOnlyRow(label: "Nom", value: user?.fullName ?? "—")
                    Divider().background(Color.revBrown.opacity(0.1))
                    ReadOnlyRow(label: "Email", value: user?.email ?? "—")
                    Divider().background(Color.revBrown.opacity(0.1))
                    if (user?.phone ?? "").isEmpty {
                        FieldLabel("Téléphone")
                        TextField("+32 4xx xx xx xx", text: $draft.telephone)
                            .keyboardType(.phonePad)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        ReadOnlyRow(label: "Téléphone", value: user?.phone ?? "")
                    }
                }
            }

            InfoBanner(text: "Tes informations sont préremplies depuis ton profil.")
        }
    }
}

// MARK: - Step 2 — Voyageurs

private struct Step2VoyageursView: View {
    @ObservedObject var draft: DevisDraft
    @State private var showFormSheet: Bool = false
    @State private var showScanFlow: Bool = false
    @State private var showPickerSheet: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(title: "Parfait !",
                       subtitle: "Qui voyage avec toi ?")

            if !draft.selectedPassengers.isEmpty {
                FieldLabel("Voyageurs sélectionnés (\(draft.selectedPassengers.count))")
                VStack(spacing: 8) {
                    ForEach(draft.selectedPassengers) { p in
                        PassengerWizardCard(passenger: p) {
                            draft.removePassenger(p)
                        }
                    }
                }
            }

            FieldLabel(draft.selectedPassengers.isEmpty ? "Ajouter des voyageurs" : "Ajouter d'autres voyageurs")

            VStack(spacing: 10) {
                WizardActionRow(icon: "doc.text.viewfinder",
                                title: "Scanner pièce d'identité",
                                subtitle: "Passeport ou CNI — auto-remplit") {
                    showScanFlow = true
                }
                WizardActionRow(icon: "person.crop.rectangle.badge.plus",
                                title: "Choisir parmi mes voyageurs",
                                subtitle: "Sélectionne dans ta liste enregistrée") {
                    showPickerSheet = true
                }
                WizardActionRow(icon: "square.and.pencil",
                                title: "Ajouter manuellement",
                                subtitle: "Saisis prénom, nom et dates") {
                    showFormSheet = true
                }
            }

            FieldLabel("Détails complémentaires (optionnel)")
            MultilineEditor(text: $draft.participants,
                            placeholder: "Notes additionnelles : âges des enfants, accompagnants non-enregistrés…",
                            minHeight: 80)
        }
        .sheet(isPresented: $showFormSheet) {
            PassengerFormView(passenger: nil, autoStartScanner: false) { req in
                await savePassenger(req)
            }
        }
        .sheet(isPresented: $showScanFlow) {
            PassengerFormView(passenger: nil, autoStartScanner: true) { req in
                await savePassenger(req)
            }
        }
        .sheet(isPresented: $showPickerSheet) {
            PassengerPickerSheet(alreadySelectedIds: Set(draft.selectedPassengers.map { $0.id })) { picked in
                for p in picked { draft.addPassenger(p) }
            }
        }
    }

    private func savePassenger(_ req: PassengerCreateRequest) async -> Bool {
        do {
            let created = try await PassengerService.shared.createPassenger(request: req)
            await MainActor.run { draft.addPassenger(created) }
            return true
        } catch {
            return false
        }
    }
}

private struct PassengerWizardCard: View {
    let passenger: Passenger
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(LinearGradient(colors: [.revYellow, .revOrange],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 40, height: 40)
                Text(initials)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(passenger.fullName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.revText)
                if let nat = passenger.nationalite, !nat.isEmpty {
                    Text(nat)
                        .font(.system(size: 12))
                        .foregroundColor(.revTextSecondary)
                }
            }
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill").foregroundColor(.revTextSecondary)
            }
        }
        .padding(12)
        .background(Color.revCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var initials: String {
        let p = passenger.prenom.first.map(String.init) ?? ""
        let n = passenger.nom.first.map(String.init) ?? ""
        return (p + n).uppercased()
    }
}

private struct WizardActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.revOrange.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon).foregroundColor(.revOrange).font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(.revText)
                    Text(subtitle).font(.system(size: 11)).foregroundColor(.revTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.revTextSecondary)
            }
            .padding(12)
            .background(Color.revCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

private struct PassengerPickerSheet: View {
    let alreadySelectedIds: Set<Int>
    let onPicked: ([Passenger]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var passengers: [Passenger] = []
    @State private var isLoading = false
    @State private var picked: Set<Int> = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.revBackground.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(.revOrange)
                } else if passengers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash").font(.system(size: 36))
                            .foregroundColor(.revOrange.opacity(0.4))
                        Text("Aucun voyageur enregistré").foregroundColor(.revTextSecondary)
                        Text("Ajoute-en via 'Ajouter manuellement' ou 'Scanner pièce d'identité'.")
                            .font(.system(size: 12)).foregroundColor(.revTextSecondary)
                            .multilineTextAlignment(.center).padding(.horizontal, 32)
                    }
                } else {
                    List(passengers) { p in
                        let isAlready = alreadySelectedIds.contains(p.id)
                        let isPicked = picked.contains(p.id) || isAlready
                        Button {
                            if !isAlready {
                                if picked.contains(p.id) { picked.remove(p.id) } else { picked.insert(p.id) }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.fullName).font(.system(size: 15, weight: .semibold))
                                    if let nat = p.nationalite, !nat.isEmpty {
                                        Text(nat).font(.system(size: 12)).foregroundColor(.revTextSecondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: isPicked ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isPicked ? .revOrange : .revTextSecondary)
                            }
                        }
                        .listRowBackground(Color.revCardBackground)
                        .disabled(isAlready)
                        .opacity(isAlready ? 0.5 : 1)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Mes voyageurs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }.foregroundColor(.revOrange)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter (\(picked.count))") {
                        let chosen = passengers.filter { picked.contains($0.id) }
                        onPicked(chosen)
                        dismiss()
                    }
                    .disabled(picked.isEmpty)
                    .foregroundColor(.revOrange)
                }
            }
            .task { await loadPassengers() }
        }
    }

    private func loadPassengers() async {
        isLoading = true
        do {
            let list = try await PassengerService.shared.getPassengers()
            passengers = list
        } catch {
            passengers = []
        }
        isLoading = false
    }
}

// MARK: - Step 3 — Dates

private struct Step3DatesView: View {
    @ObservedObject var draft: DevisDraft
    @State private var usePicker = false
    @State private var dateStart = Date()
    @State private var dateEnd = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(title: "Les dates",
                       subtitle: "Précis ou approximatif, peu importe !")

            Picker("Mode", selection: $usePicker) {
                Text("Texte libre").tag(false)
                Text("Dates précises").tag(true)
            }
            .pickerStyle(.segmented)

            if usePicker {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        DatePicker("Départ", selection: $dateStart, displayedComponents: .date)
                        DatePicker("Retour", selection: $dateEnd, in: dateStart..., displayedComponents: .date)
                    }
                    .tint(.revOrange)
                }
                .onChange(of: dateStart) { _ in syncDates() }
                .onChange(of: dateEnd) { _ in syncDates() }
                .onAppear { syncDates() }
            } else {
                FieldLabel("Période souhaitée")
                MultilineEditor(text: $draft.datesText,
                                placeholder: "Vacances de Pâques 2026, été 2026, première semaine d'août…",
                                minHeight: 80)
            }

            Toggle("Mes dates sont flexibles", isOn: $draft.flexibleDates)
                .tint(.revOrange)
                .padding(.vertical, 4)

            FieldLabel("Durée du voyage")
            let durees = ["Week-end", "1 semaine", "2 semaines", "3 semaines", "1 mois", "Plus"]
            FlowChips(items: durees, selection: Binding(
                get: { [draft.duree] },
                set: { draft.duree = $0.first ?? "" }
            ), multi: false)
        }
    }

    private func syncDates() {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd/MM/yyyy"
        draft.datesText = "Du \(fmt.string(from: dateStart)) au \(fmt.string(from: dateEnd))"
    }
}

// MARK: - Step 4 — Destination

private struct Step4DestinationView: View {
    @ObservedObject var draft: DevisDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepHeader(title: "La destination",
                       subtitle: "Plusieurs aéroports possibles côté départ ET côté retour.")

            AirportMultiSelector(title: "Aéroports de départ",
                                 placeholder: "Bruxelles, Paris, Amsterdam…",
                                 selection: $draft.lieuxDepart)

            AirportMultiSelector(title: "Aéroports de retour",
                                 placeholder: "Même que départ si vol AR",
                                 selection: $draft.lieuxRetour)

            FieldLabel("Destination souhaitée")
            TextField("Bali, Maroc, surprise…", text: $draft.destination)
                .textFieldStyle(.roundedBorder)

            Toggle("Je suis ouvert aux suggestions de Matilda", isOn: $draft.ouvertSuggestions)
                .tint(.revOrange)
                .padding(.vertical, 4)
        }
    }
}

private struct AirportMultiSelector: View {
    let title: String
    let placeholder: String
    @Binding var selection: [Airport]

    @State private var query: String = ""
    @State private var results: [Airport] = []
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var isSearching = false

    private let shortcuts = ["BRU", "CRL", "CDG", "ORY", "AMS", "LGG"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel(title)

            if !selection.isEmpty {
                let cols = [GridItem(.adaptive(minimum: 90), spacing: 6)]
                LazyVGrid(columns: cols, alignment: .leading, spacing: 6) {
                    ForEach(selection) { a in
                        HStack(spacing: 6) {
                            Image(systemName: "airplane").font(.system(size: 11)).foregroundColor(.revOrange)
                            Text(a.code)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.revBrown)
                            Button {
                                selection.removeAll { $0.id == a.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.revTextSecondary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.revYellow.opacity(0.4))
                        .clipShape(Capsule())
                    }
                }
            }

            TextField(placeholder, text: $query)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .onChange(of: query) { debounce($0) }

            HStack(spacing: 6) {
                ForEach(shortcuts, id: \.self) { code in
                    Button { toggleShortcut(code) } label: {
                        Text(code)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isSelected(code) ? Color.revOrange : Color.revYellow.opacity(0.4))
                            .foregroundColor(isSelected(code) ? .white : .revBrown)
                            .clipShape(Capsule())
                    }
                }
            }

            if isSearching {
                HStack { ProgressView().tint(.revOrange); Text("Recherche…").foregroundColor(.revTextSecondary) }
            } else if !results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(results) { airport in
                        Button { add(airport) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(airport.displayLabel).font(.system(size: 14, weight: .semibold))
                                    Text(airport.displaySublabel).font(.system(size: 12)).foregroundColor(.revTextSecondary)
                                }
                                Spacer()
                                Image(systemName: isSelected(airport.code) ? "checkmark.circle.fill" : "plus.circle")
                                    .foregroundColor(.revOrange)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                        }
                        .foregroundColor(.revText)
                        Divider().background(Color.revBrown.opacity(0.1))
                    }
                }
                .background(Color.revCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func isSelected(_ code: String) -> Bool {
        selection.contains { $0.code == code }
    }

    private func add(_ a: Airport) {
        if !isSelected(a.code) { selection.append(a) }
        query = ""
        results = []
    }

    private func toggleShortcut(_ code: String) {
        if isSelected(code) {
            selection.removeAll { $0.code == code }
            return
        }
        Task {
            do {
                let res = try await AirportService.shared.search(query: code)
                if let match = res.first(where: { $0.code == code }) ?? res.first {
                    await MainActor.run { add(match) }
                }
            } catch {}
        }
    }

    private func debounce(_ value: String) {
        searchTask?.cancel()
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            results = []
            isSearching = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            await run(trimmed)
        }
    }

    private func run(_ q: String) async {
        isSearching = true
        do {
            let res = try await AirportService.shared.search(query: q)
            if !Task.isCancelled { results = res }
        } catch { results = [] }
        isSearching = false
    }
}

// MARK: - Step 5 — Séjour

private struct Step5SejourView: View {
    @ObservedObject var draft: DevisDraft

    private let cadres = ["Plage", "Montagne", "Ville", "Campagne", "Désert", "Exotique"]
    private let hebergements = ["Hôtel", "Riad", "Lodge", "Camping", "Villa", "Appartement"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(title: "Le séjour",
                       subtitle: "Choisis tout ce qui te correspond !")

            FieldLabel("Cadre (plusieurs choix)")
            FlowChips(items: cadres,
                      selection: Binding(get: { draft.cadre }, set: { draft.cadre = $0 }),
                      multi: true)

            FieldLabel("Hébergement préféré")
            FlowChips(items: hebergements,
                      selection: Binding(
                          get: { draft.hebergement.isEmpty ? [] : [draft.hebergement] },
                          set: { draft.hebergement = $0.first ?? "" }
                      ),
                      multi: false)

            FieldLabel("Besoins spécifiques (accessibilité, allergies, animaux…)")
            MultilineEditor(text: $draft.besoinsSpecifiques,
                            placeholder: "Allergie aux fruits de mer, accessibilité PMR, voyage avec chien…",
                            minHeight: 100)
        }
    }
}

// MARK: - Step 6 — Activités

private struct Step6ActivitesView: View {
    @ObservedObject var draft: DevisDraft

    private let activites = ["Plongée", "Randonnée", "Gastronomie", "Culture", "Spa", "Aventure", "Famille", "Romantique"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(title: "Les activités",
                       subtitle: "Tout ce que tu coches, je l'intègre !")

            FieldLabel("Activités souhaitées")
            FlowChips(items: activites,
                      selection: Binding(get: { draft.activites }, set: { draft.activites = $0 }),
                      multi: true)

            FieldLabel("Ce que tu veux éviter")
            MultilineEditor(text: $draft.activitesEviter,
                            placeholder: "Visites guidées trop longues, foules touristiques, sports extrêmes…",
                            minHeight: 100)
        }
    }
}

// MARK: - Step 7 — Détails

private struct Step7DetailsView: View {
    @ObservedObject var draft: DevisDraft

    private let budgets = [
        ("Économique", "< 1 500 € / pers."),
        ("Moyen", "1 500 – 3 000 €"),
        ("Confort", "3 000 – 5 000 €"),
        ("Luxe", "5 000 €+"),
        ("Sans limite", "Le meilleur, sans contrainte")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(title: "Derniers détails",
                       subtitle: "Plus tu es précis, plus ton voyage sera parfait.")

            FieldLabel("Budget")
            VStack(spacing: 8) {
                ForEach(budgets, id: \.0) { item in
                    BudgetCard(title: item.0, subtitle: item.1,
                               selected: draft.budget == item.0) {
                        draft.budget = item.0
                    }
                }
            }

            FieldLabel("Impératifs (vol direct, dates fixes, animaux…)")
            MultilineEditor(text: $draft.imperatifs,
                            placeholder: "Vol direct obligatoire, départ vendredi soir…",
                            minHeight: 80)

            FieldLabel("Événement spécial (optionnel)")
            MultilineEditor(text: $draft.evenement,
                            placeholder: "Anniversaire, lune de miel, fiançailles…",
                            minHeight: 60)
        }
    }
}

// MARK: - Confirmation

private struct DevisConfirmationView: View {
    let devis: Devis
    let onDone: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.revYellow, .revOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 110, height: 110)
                    .shadow(color: .revOrange.opacity(0.4), radius: 20, y: 10)
                Image(systemName: "checkmark")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(appeared ? 1 : 0.5)
            .opacity(appeared ? 1 : 0)

            Text("Matilda a reçu ta demande !")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.revBrown)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text("Elle revient vers toi très vite avec une proposition sur-mesure.\n\nRéférence : **\(devis.token)**")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.revTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            BrandButton(title: "Voir mes voyages", systemImage: "airplane", style: .primary, action: onDone)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                appeared = true
            }
        }
    }
}

// MARK: - Shared components

private struct StepHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.revBrown)
            Text(subtitle)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.revTextSecondary)
        }
    }
}

private struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(.revText)
            .padding(.top, 4)
    }
}

private struct ReadOnlyRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.revTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.revText)
        }
    }
}

private struct InfoBanner: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill").foregroundColor(.revOrange)
            Text(text)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.revTextSecondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.revYellow.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct MultilineEditor: View {
    @Binding var text: String
    let placeholder: String
    var minHeight: CGFloat = 80

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.revTextSecondary.opacity(0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
            TextEditor(text: $text)
                .font(.system(size: 14, design: .rounded))
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .background(Color.revCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.revBrown.opacity(0.1), lineWidth: 1))
    }
}

private struct FlowChips: View {
    let items: [String]
    @Binding var selection: Set<String>
    var multi: Bool = true

    var body: some View {
        let cols = [GridItem(.adaptive(minimum: 100), spacing: 8)]
        LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button {
                    if multi {
                        if selection.contains(item) { selection.remove(item) } else { selection.insert(item) }
                    } else {
                        selection = [item]
                    }
                } label: {
                    Text(item)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(selection.contains(item) ? Color.revOrange : Color.revCardBackground)
                        .foregroundColor(selection.contains(item) ? .white : .revText)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}

private struct BudgetCard: View {
    let title: String
    let subtitle: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(selected ? .white : .revText)
                    Text(subtitle)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(selected ? .white.opacity(0.85) : .revTextSecondary)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.white)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if selected {
                        LinearGradient(colors: [.revOrange, .revRed], startPoint: .leading, endPoint: .trailing)
                    } else {
                        Color.revCardBackground
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
