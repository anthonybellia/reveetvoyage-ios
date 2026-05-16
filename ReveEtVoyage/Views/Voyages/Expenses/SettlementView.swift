import SwiftUI

struct SettlementView: View {
    @ObservedObject var viewModel: ExpensesViewModel

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.settlement == nil {
                LoadingView()
            } else if let error = viewModel.errorMessage, viewModel.settlement == nil {
                ErrorView(message: error) { Task { await viewModel.refresh() } }
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        totalCard
                        balancesSection
                        transactionsSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .refreshable { await viewModel.refresh() }
            }
        }
    }

    // MARK: - Total

    private var totalCard: some View {
        GlassCard(padding: 18) {
            VStack(spacing: 4) {
                Text("Total dépensé")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.revOrange)
                    .tracking(0.8)
                Text(formatPrice(viewModel.totalSpent))
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.revOrange, .revRed],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Balances

    private var balancesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Soldes individuels", systemImage: "person.text.rectangle")
                .padding(.horizontal, 4)

            if let balances = viewModel.settlement?.balances, !balances.isEmpty {
                ForEach(balances) { balance in
                    BalanceRow(balance: balance)
                }
            } else {
                GlassCard {
                    Text("Aucun solde à afficher.")
                        .font(.system(size: 14))
                        .foregroundColor(.revTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Transactions

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Qui doit combien à qui", systemImage: "arrow.left.arrow.right")
                .padding(.horizontal, 4)

            if let txs = viewModel.settlement?.transactions, !txs.isEmpty {
                ForEach(txs) { tx in
                    TransactionRow(transaction: tx)
                }
            } else {
                GlassCard(padding: 22) {
                    VStack(spacing: 10) {
                        Text("🎉")
                            .font(.system(size: 42))
                        Text("Tout est équilibré !")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.revText)
                        Text("Personne ne doit rien à personne.")
                            .font(.system(size: 12))
                            .foregroundColor(.revTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
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

// MARK: - Balance row

private struct BalanceRow: View {
    let balance: SettlementBalance

    private var isCredit: Bool { balance.balance_cents > 0 }
    private var isZero: Bool { balance.balance_cents == 0 }

    var body: some View {
        GlassCard(padding: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.revYellow, .revOrange, .revRed],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 38, height: 38)
                    Text(initials(balance.name))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(balance.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.revText)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.revTextSecondary)
                }

                Spacer()

                Text(formatAmount(abs(balance.balance)))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(amountColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(amountColor.opacity(0.15))
                    )
            }
        }
    }

    private var subtitle: String {
        if isZero { return "Équilibré" }
        if isCredit { return "On lui doit" }
        return "Doit aux autres"
    }

    private var amountColor: Color {
        if isZero { return .revTextSecondary }
        return isCredit ? .revSuccess : .revOrange
    }

    private func formatAmount(_ amount: Double) -> String {
        String(format: "%.2f €", amount)
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map { String($0) } ?? ""
        let last = parts.dropFirst().first?.first.map { String($0) } ?? ""
        let result = (first + last).uppercased()
        return result.isEmpty ? "?" : result
    }
}

// MARK: - Transaction row

private struct TransactionRow: View {
    let transaction: SettlementTransaction

    var body: some View {
        GlassCard(padding: 14) {
            HStack(spacing: 12) {
                PersonChip(name: transaction.from_name, role: .debtor)

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        LinearGradient(colors: [.revOrange, .revRed],
                                       startPoint: .leading, endPoint: .trailing)
                    )

                PersonChip(name: transaction.to_name, role: .creditor)

                Spacer()

                Text(String(format: "%.2f €", transaction.amount))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.revOrange)
            }
        }
    }
}

private struct PersonChip: View {
    enum Role { case debtor, creditor }
    let name: String
    let role: Role

    var body: some View {
        Text(name)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(.revBrown)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color.revYellow.opacity(0.25))
            )
    }
}
