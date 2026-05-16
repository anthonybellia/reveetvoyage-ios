import SwiftUI

struct AddExpenseSheet: View {
    @ObservedObject var viewModel: ExpensesViewModel
    let editingExpense: Expense?

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var amountString: String = ""
    @State private var paidById: Int?
    @State private var sharedWith: Set<Int> = []
    @State private var category: ExpenseCategory = .restaurant
    @State private var spentAt: Date = Date()
    @State private var descriptionText: String = ""
    @State private var isSaving: Bool = false
    @State private var localError: String?
    @State private var locationName: String?
    @State private var locationLatitude: Double?
    @State private var locationLongitude: Double?
    @State private var showPlaceSheet: Bool = false

    init(viewModel: ExpensesViewModel, editingExpense: Expense?) {
        self.viewModel = viewModel
        self.editingExpense = editingExpense
    }

    private var isEditing: Bool { editingExpense != nil }

    private var canSave: Bool {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard (parsedAmount ?? 0) > 0 else { return false }
        guard paidById != nil else { return false }
        guard !sharedWith.isEmpty else { return false }
        return true
    }

    private var parsedAmount: Double? {
        let normalized = amountString
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        return Double(normalized)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.revBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        titleField
                        amountField
                        paidByPicker
                        sharedWithList
                        categoryPicker
                        datePicker
                        locationField
                        descriptionField
                        if let err = localError {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundColor(.revError)
                                .multilineTextAlignment(.center)
                        }
                        saveButton
                            .padding(.top, 4)
                    }
                    .padding(18)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(isEditing ? "Modifier la dépense" : "Nouvelle dépense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundColor(.revBrown)
                }
            }
            .onAppear(perform: bootstrap)
        }
        .presentationDetents([.large])
    }

    // MARK: - Sections

    private var titleField: some View {
        fieldCard(title: "TITRE", systemImage: "tag.fill") {
            TextField("Ex : Restaurant chez Mario", text: $title)
                .font(.system(size: 16, design: .rounded))
                .textInputAutocapitalization(.sentences)
        }
    }

    private var amountField: some View {
        fieldCard(title: "MONTANT", systemImage: "eurosign.circle.fill") {
            HStack {
                TextField("0,00", text: $amountString)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.revOrange)
                Text("€")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.revOrange)
            }
        }
    }

    private var paidByPicker: some View {
        fieldCard(title: "PAYÉ PAR", systemImage: "person.fill") {
            if viewModel.participants.isEmpty {
                Text("Aucun participant — ajoute-en dans l'onglet Participants.")
                    .font(.system(size: 13))
                    .foregroundColor(.revTextSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.participants) { p in
                            Button {
                                paidById = p.id
                            } label: {
                                Text(p.display_name)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(
                                            paidById == p.id
                                            ? AnyShapeStyle(LinearGradient(colors: [.revOrange, .revRed],
                                                                           startPoint: .leading, endPoint: .trailing))
                                            : AnyShapeStyle(Color.revYellow.opacity(0.25))
                                        )
                                    )
                                    .foregroundColor(paidById == p.id ? .white : .revBrown)
                            }
                        }
                    }
                }
            }
        }
    }

    private var sharedWithList: some View {
        fieldCard(title: "PARTAGÉ ENTRE", systemImage: "person.2.fill") {
            VStack(spacing: 6) {
                HStack {
                    Spacer()
                    Button {
                        if sharedWith.count == viewModel.participants.count {
                            sharedWith.removeAll()
                        } else {
                            sharedWith = Set(viewModel.participants.map { $0.id })
                        }
                    } label: {
                        Text(sharedWith.count == viewModel.participants.count ? "Tout désélectionner" : "Tout sélectionner")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.revOrange)
                    }
                }

                ForEach(viewModel.participants) { p in
                    Button {
                        if sharedWith.contains(p.id) {
                            sharedWith.remove(p.id)
                        } else {
                            sharedWith.insert(p.id)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: sharedWith.contains(p.id) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundColor(sharedWith.contains(p.id) ? .revOrange : .revTextSecondary)
                            Text(p.display_name)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.revText)
                            Spacer()
                            if p.is_guest {
                                Text("Invité")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.revTextSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.revYellow.opacity(0.25)))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var categoryPicker: some View {
        fieldCard(title: "CATÉGORIE", systemImage: "square.grid.2x2.fill") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 10)], spacing: 10) {
                ForEach(ExpenseCategory.allCases) { cat in
                    Button {
                        category = cat
                    } label: {
                        VStack(spacing: 5) {
                            ZStack {
                                Circle()
                                    .fill(category == cat ? cat.color : cat.color.opacity(0.18))
                                    .frame(width: 36, height: 36)
                                Image(systemName: cat.systemImage)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(category == cat ? .white : cat.color)
                            }
                            Text(cat.label)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.revText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(category == cat ? cat.color.opacity(0.10) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(category == cat ? cat.color : Color.gray.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var datePicker: some View {
        fieldCard(title: "DATE", systemImage: "calendar") {
            DatePicker(
                "Date de la dépense",
                selection: $spentAt,
                displayedComponents: [.date]
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "fr_BE"))
            .tint(.revOrange)
        }
    }

    private var locationField: some View {
        fieldCard(title: "LIEU (OPTIONNEL)", systemImage: "mappin.and.ellipse") {
            Button {
                showPlaceSheet = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if let name = locationName, !name.isEmpty {
                            Text(name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.revText)
                            if locationLatitude != nil {
                                Text("Position enregistrée")
                                    .font(.system(size: 11))
                                    .foregroundColor(.revTextSecondary)
                            }
                        } else {
                            Text("Rechercher un lieu…")
                                .font(.system(size: 14))
                                .foregroundColor(.revTextSecondary)
                        }
                    }
                    Spacer()
                    if locationName != nil {
                        Button {
                            locationName = nil
                            locationLatitude = nil
                            locationLongitude = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.revTextSecondary)
                        }
                    } else {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.revOrange)
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showPlaceSheet) {
            PlaceAutocompleteView(
                centerLatitude:  nil,
                centerLongitude: nil,
            ) { place in
                locationName = place.name
                locationLatitude = place.latitude
                locationLongitude = place.longitude
            }
        }
    }

    private var descriptionField: some View {
        fieldCard(title: "DESCRIPTION (OPTIONNEL)", systemImage: "text.alignleft") {
            ZStack(alignment: .topLeading) {
                if descriptionText.isEmpty {
                    Text("Détails additionnels…")
                        .font(.system(size: 14))
                        .foregroundColor(.revTextSecondary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $descriptionText)
                    .font(.system(size: 14))
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
            }
        }
    }

    private var saveButton: some View {
        BrandButton(
            title: isEditing ? "Enregistrer les modifications" : "Enregistrer",
            systemImage: "checkmark.circle.fill",
            isLoading: isSaving
        ) {
            Task { await save() }
        }
        .disabled(!canSave || isSaving)
        .opacity(canSave ? 1 : 0.55)
    }

    // MARK: - Helpers

    private func fieldCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                }
                .foregroundColor(.revOrange)
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func bootstrap() {
        if let e = editingExpense {
            title = e.title
            amountString = String(format: "%.2f", e.amount).replacingOccurrences(of: ".", with: ",")
            paidById = e.paid_by_participant_id
            sharedWith = Set(e.splits.map { $0.participant_id })
            category = .from(e.category)
            spentAt = e.spentAtDate ?? Date()
            descriptionText = e.description ?? ""
            locationName = e.location_name
            locationLatitude = e.location_latitude
            locationLongitude = e.location_longitude
        } else {
            // Default "payé par" = current logged-in user if they're a participant,
            // otherwise the first participant in the list.
            if paidById == nil {
                let currentUserId = AuthService.shared.currentUser?.id
                paidById = viewModel.participants.first(where: { $0.user_id == currentUserId })?.id
                    ?? viewModel.participants.first?.id
            }
            // Default "partagé entre" = everyone checked.
            if sharedWith.isEmpty {
                sharedWith = Set(viewModel.participants.map { $0.id })
            }
        }
    }

    private func save() async {
        guard canSave, let amount = parsedAmount, let payer = paidById else { return }
        isSaving = true
        localError = nil
        defer { isSaving = false }

        let spentAtIso = ISO8601DateFormatter().string(from: spentAt)
        let splits = sharedWith.map { ExpenseRequestSplit(participant_id: $0, share_weight: 1) }

        let req = ExpenseRequest(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            currency: "EUR",
            paid_by_participant_id: payer,
            spent_at: spentAtIso,
            description: descriptionText.isEmpty ? nil : descriptionText,
            category: category.rawValue,
            location_name: locationName,
            location_latitude: locationLatitude,
            location_longitude: locationLongitude,
            splits: splits
        )

        let ok: Bool
        if let e = editingExpense {
            ok = await viewModel.updateExpense(expenseId: e.id, request: req)
        } else {
            ok = await viewModel.addExpense(request: req)
        }

        if ok {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            dismiss()
        } else {
            localError = viewModel.errorMessage ?? "Une erreur est survenue"
        }
    }
}
