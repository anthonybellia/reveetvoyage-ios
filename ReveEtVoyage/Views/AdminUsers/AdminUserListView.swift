import SwiftUI

struct AdminUserListView: View {
    @State private var users: [AdminUser] = []
    @State private var query: String = ""
    @State private var roleFilter: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var page: Int = 1
    @State private var canLoadMore: Bool = true
    @State private var showCreateSheet: Bool = false
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.revYellow.opacity(0.08), Color.revBackground],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                searchHeader
                filterChips
                Divider()
                content
            }
        }
        .navigationTitle("Utilisateurs")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill").foregroundColor(.revOrange)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            AdminUserFormSheet(mode: .create) { _ in
                Task { await load(reset: true) }
            }
        }
        .navigationDestination(for: AdminUser.self) { user in
            AdminUserDetailView(user: user) { updated in
                if let updated = updated {
                    if let idx = users.firstIndex(where: { $0.id == updated.id }) {
                        users[idx] = updated
                    }
                } else {
                    Task { await load(reset: true) }
                }
            }
        }
        .task { if users.isEmpty { await load(reset: true) } }
    }

    private var searchHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundColor(.revTextSecondary)
            TextField("Nom, prénom, email…", text: $query)
                .autocorrectionDisabled()
                .onChange(of: query) { newValue in
                    searchTask?.cancel()
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 280_000_000)
                        if Task.isCancelled { return }
                        await load(reset: true)
                    }
                }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.revTextSecondary)
                }
            }
        }
        .padding(12)
        .background(Color.revCardBackground)
    }

    private var filterChips: some View {
        HStack(spacing: 8) {
            chip("Tous", value: "")
            chip("Clients", value: "customer")
            chip("Admins", value: "admin")
            chip("Modérateurs", value: "moderator")
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func chip(_ label: String, value: String) -> some View {
        let isSelected = roleFilter == value
        return Button {
            roleFilter = value
            Task { await load(reset: true) }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? .white : .revBrown)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(
                    Capsule().fill(
                        isSelected
                            ? AnyShapeStyle(LinearGradient(colors: [.revOrange, .revRed],
                                                          startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.revCardBackground)
                    )
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && users.isEmpty {
            LoadingView()
        } else if let err = errorMessage, users.isEmpty {
            ErrorView(message: err) { Task { await load(reset: true) } }
        } else if users.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 48)).foregroundColor(.revOrange.opacity(0.4))
                Text("Aucun utilisateur").foregroundColor(.revTextSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(users) { user in
                        NavigationLink(value: user) {
                            AdminUserRow(user: user)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if user.id == users.last?.id { Task { await loadMore() } }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
    }

    private func load(reset: Bool) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let (items, hasMore) = try await UserAdminService.shared.list(
                page: 1,
                query: query.isEmpty ? nil : query,
                role: roleFilter.isEmpty ? nil : roleFilter
            )
            users = items
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
            let (items, hasMore) = try await UserAdminService.shared.list(
                page: page + 1,
                query: query.isEmpty ? nil : query,
                role: roleFilter.isEmpty ? nil : roleFilter
            )
            users.append(contentsOf: items)
            page += 1
            canLoadMore = hasMore
        } catch {}
    }
}

struct AdminUserRow: View {
    let user: AdminUser

    var body: some View {
        GlassCard(padding: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(roleColor.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Text(initials)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(roleColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.fullName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.revText)
                    Text(user.email)
                        .font(.system(size: 11))
                        .foregroundColor(.revTextSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(roleLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(roleColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(roleColor.opacity(0.14)))
            }
        }
    }

    private var roleColor: Color {
        switch user.role {
        case "admin": return .red
        case "moderator": return .blue
        default: return .revOrange
        }
    }

    private var roleLabel: String {
        switch user.role {
        case "admin": return "Admin"
        case "moderator": return "Modo"
        case "customer": return "Client"
        default: return user.role.capitalized
        }
    }

    private var initials: String {
        let first = (user.prenom?.first).map(String.init) ?? ""
        let second = user.name.first.map(String.init) ?? ""
        let result = (first + second).uppercased()
        return result.isEmpty ? "?" : result
    }
}
