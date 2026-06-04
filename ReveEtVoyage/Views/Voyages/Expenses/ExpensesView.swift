import SwiftUI

struct ExpensesView: View {
    @StateObject private var viewModel: ExpensesViewModel

    @State private var selectedTab: Tab = .expenses
    @State private var showAddExpense = false
    @State private var editingExpense: Expense?
    @State private var animatedTotal: Double = 0
    @State private var expenseToDelete: Expense?

    enum Tab: String, CaseIterable, Identifiable {
        case expenses    = "Dépenses"
        case settlement  = "Solde"
        case participants = "Participants"
        var id: String { rawValue }
    }

    init(voyageId: Int) {
        _viewModel = StateObject(wrappedValue: ExpensesViewModel(voyageId: voyageId))
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                tabPicker
                    .padding(.horizontal, 18)
                    .padding(.top, 8)

                Group {
                    switch selectedTab {
                    case .expenses:     expensesTab
                    case .settlement:   SettlementView(viewModel: viewModel)
                    case .participants: ParticipantsView(viewModel: viewModel)
                    }
                }
            }

            if selectedTab == .expenses {
                addExpenseFAB
            }
        }
        .navigationTitle("Dépenses")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
            updateAnimatedTotal()
            viewModel.startPolling()
        }
        .onDisappear { viewModel.stopPolling() }
        .onChange(of: viewModel.totalSpent) { _ in updateAnimatedTotal() }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseSheet(viewModel: viewModel, editingExpense: nil)
        }
        .sheet(item: $editingExpense) { expense in
            AddExpenseSheet(viewModel: viewModel, editingExpense: expense)
        }
        .confirmationDialog(
            "Supprimer cette dépense ?",
            isPresented: Binding(
                get: { expenseToDelete != nil },
                set: { if !$0 { expenseToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let e = expenseToDelete {
                Button("Supprimer", role: .destructive) {
                    Task { await viewModel.deleteExpense(e) }
                    expenseToDelete = nil
                }
                Button("Annuler", role: .cancel) { expenseToDelete = nil }
            }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [Color.revYellow.opacity(0.10), Color.revBackground],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Tab picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(selectedTab == tab ? .white : .revBrown)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            ZStack {
                                if selectedTab == tab {
                                    LinearGradient(
                                        colors: [.revOrange, .revRed],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.revCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.gray.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Expenses tab

    private var expensesTab: some View {
        Group {
            if viewModel.isLoading && viewModel.expenses.isEmpty {
                LoadingView()
            } else if let error = viewModel.errorMessage, viewModel.expenses.isEmpty {
                ErrorView(message: error) { Task { await viewModel.load() } }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        totalCard
                        categoriesRow
                        expensesList
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
                .refreshable { await viewModel.refresh() }
            }
        }
    }

    private var totalCard: some View {
        GlassCard(padding: 18) {
            VStack(spacing: 4) {
                Text("Total dépensé")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.revOrange)
                    .tracking(0.8)

                Text(formatPrice(animatedTotal))
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.revOrange, .revRed],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .contentTransition(.numericText())

                if viewModel.expenses.count > 0 {
                    Text("\(viewModel.expenses.count) dépense\(viewModel.expenses.count > 1 ? "s" : "")")
                        .font(.system(size: 12))
                        .foregroundColor(.revTextSecondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var categoriesRow: some View {
        let cats = viewModel.amountByCategory
        return Group {
            if cats.isEmpty {
                EmptyView()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(cats, id: \.category) { entry in
                            CategoryCard(category: entry.category, amount: entry.amount)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var expensesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Historique", systemImage: "list.bullet.rectangle")
                .padding(.horizontal, 4)

            if viewModel.expenses.isEmpty {
                GlassCard {
                    VStack(spacing: 8) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 32))
                            .foregroundColor(.revTextSecondary)
                        Text("Aucune dépense pour le moment.")
                            .font(.system(size: 14))
                            .foregroundColor(.revTextSecondary)
                        Text("Appuie sur + pour ajouter la première.")
                            .font(.system(size: 12))
                            .foregroundColor(.revTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            } else {
                ForEach(viewModel.expenses) { expense in
                    ExpenseRow(
                        expense: expense,
                        paidByName: viewModel.participantName(id: expense.paid_by_participant_id)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { editingExpense = expense }
                    .contextMenu {
                        Button {
                            editingExpense = expense
                        } label: {
                            Label("Modifier", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            expenseToDelete = expense
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - FAB

    private var addExpenseFAB: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showAddExpense = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(
                                colors: [.revOrange, .revRed],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.revOrange.opacity(0.45), radius: 12, x: 0, y: 6)
                }
                .padding(.trailing, 22)
                .padding(.bottom, 22)
            }
        }
    }

    // MARK: - Helpers

    private func updateAnimatedTotal() {
        withAnimation(.easeOut(duration: 0.7)) {
            animatedTotal = viewModel.totalSpent
        }
    }

    private func formatPrice(_ amount: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.locale = Locale(identifier: "fr_BE")
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: amount)) ?? String(format: "%.2f €", amount)
    }
}

// MARK: - Category card

private struct CategoryCard: View {
    let category: ExpenseCategory
    let amount: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: category.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(category.color)
            }
            Text(category.label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.revTextSecondary)
            Text(formatPrice(amount))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.revText)
        }
        .padding(12)
        .frame(minWidth: 100, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.revCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.gray.opacity(0.08), lineWidth: 1)
        )
    }

    private func formatPrice(_ amount: Double) -> String {
        if amount >= 1000 {
            return String(format: "%.0f €", amount)
        }
        return String(format: "%.2f €", amount)
    }
}

// MARK: - Expense row

private struct ExpenseRow: View {
    let expense: Expense
    let paidByName: String

    private var category: ExpenseCategory { .from(expense.category) }

    var body: some View {
        GlassCard(padding: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(category.color.opacity(0.18))
                        .frame(width: 42, height: 42)
                    Image(systemName: category.systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(category.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(expense.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.revText)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        AvatarView(
                            firstName: paidByName.split(separator: " ").first.map(String.init) ?? paidByName,
                            lastName: paidByName.split(separator: " ").dropFirst().first.map(String.init) ?? "",
                            avatarPath: expense.paid_by?.avatar_url,
                            size: 18
                        )
                        (Text("Payé par ").foregroundColor(.revTextSecondary)
                            + Text(paidByName).foregroundColor(.revBrown).bold())
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.revTextSecondary)

                    if let loc = expense.location_name, !loc.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.revOrange)
                            Text(loc)
                                .font(.system(size: 11))
                                .foregroundColor(.revOrange)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(formatPrice(expense.amount))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.revOrange)
                    if let date = expense.spentAtDate {
                        Text(date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "fr_BE"))))
                            .font(.system(size: 10))
                            .foregroundColor(.revTextSecondary)
                    }
                }
            }
        }
    }

    private func formatPrice(_ amount: Double) -> String {
        String(format: "%.2f €", amount)
    }
}
