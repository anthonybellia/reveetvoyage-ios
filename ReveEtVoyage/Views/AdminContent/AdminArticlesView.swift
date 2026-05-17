import SwiftUI

struct AdminArticlesView: View {
    @State private var articles: [AdminArticle] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showCreate: Bool = false
    @State private var editing: AdminArticle? = nil
    @State private var pendingDelete: AdminArticle? = nil
    @State private var showDeleteConfirm: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.revYellow.opacity(0.08), Color.revBackground],
                           startPoint: .top, endPoint: .center).ignoresSafeArea()
            content
        }
        .navigationTitle("Articles")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCreate = true } label: {
                    Image(systemName: "plus.circle.fill").foregroundColor(.revOrange)
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            ArticleFormSheet(mode: .create) { saved in articles.insert(saved, at: 0) }
        }
        .sheet(item: $editing) { a in
            ArticleFormSheet(mode: .edit(a)) { saved in
                if let i = articles.firstIndex(where: { $0.id == saved.id }) { articles[i] = saved }
            }
        }
        .confirmationDialog("Supprimer cet article ?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                guard let a = pendingDelete else { return }
                Task {
                    try? await ContentAdminService.shared.deleteArticle(id: a.id)
                    articles.removeAll { $0.id == a.id }
                    pendingDelete = nil
                }
            }
            Button("Annuler", role: .cancel) { pendingDelete = nil }
        } message: {
            if let a = pendingDelete { Text("\"\(a.titre)\" sera supprimé définitivement.") }
        }
        .task { if articles.isEmpty { await load() } }
        .refreshable { await load() }
    }

    @ViewBuilder private var content: some View {
        if isLoading && articles.isEmpty {
            LoadingView()
        } else if let err = errorMessage, articles.isEmpty {
            ErrorView(message: err) { Task { await load() } }
        } else if articles.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "doc.richtext").font(.system(size: 48)).foregroundColor(.revOrange.opacity(0.4))
                Text("Aucun article").foregroundColor(.revTextSecondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(articles) { a in
                        ArticleRow(article: a)
                            .contextMenu {
                                Button { editing = a } label: { Label("Modifier", systemImage: "pencil") }
                                Button(role: .destructive) {
                                    pendingDelete = a
                                    showDeleteConfirm = true
                                } label: { Label("Supprimer", systemImage: "trash") }
                            }
                            .onTapGesture { editing = a }
                    }
                }.padding(.horizontal, 14).padding(.vertical, 8)
            }
        }
    }

    private func load() async {
        isLoading = true; errorMessage = nil; defer { isLoading = false }
        do { articles = try await ContentAdminService.shared.listArticles() }
        catch { errorMessage = error.localizedDescription }
    }
}

struct ArticleRow: View {
    let article: AdminArticle

    var body: some View {
        GlassCard(padding: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(article.publie ? Color.green.opacity(0.14) : Color.gray.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: article.publie ? "checkmark.seal.fill" : "doc.text")
                        .foregroundColor(article.publie ? .green : .gray)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(article.titre)
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.revText)
                        .lineLimit(2)
                    if let extrait = article.extrait, !extrait.isEmpty {
                        Text(extrait).font(.system(size: 11))
                            .foregroundColor(.revTextSecondary).lineLimit(2)
                    }
                }
                Spacer()
            }
        }
    }
}

struct ArticleFormSheet: View {
    enum Mode { case create; case edit(AdminArticle) }
    let mode: Mode
    let onSaved: (AdminArticle) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var titre: String = ""
    @State private var slug: String = ""
    @State private var extrait: String = ""
    @State private var contenu: String = ""
    @State private var metaTitle: String = ""
    @State private var metaDescription: String = ""
    @State private var publie: Bool = false
    @State private var hasDate: Bool = false
    @State private var publieLe: Date = Date()

    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationView {
            Form {
                Section("Article") {
                    TextField("Titre *", text: $titre)
                    TextField("Slug (vide = auto)", text: $slug).autocapitalization(.none)
                    TextField("Extrait", text: $extrait, axis: .vertical).lineLimit(2...4)
                }
                Section("Contenu (HTML)") {
                    TextEditor(text: $contenu).frame(minHeight: 180).font(.system(size: 13))
                }
                Section("Publication") {
                    Toggle("Publié", isOn: $publie)
                    Toggle("Date de publication", isOn: $hasDate)
                    if hasDate {
                        DatePicker("", selection: $publieLe, displayedComponents: [.date]).labelsHidden()
                    }
                }
                Section("SEO") {
                    TextField("Meta title", text: $metaTitle)
                    TextField("Meta description", text: $metaDescription, axis: .vertical).lineLimit(2...3)
                }
                if let err = errorMessage {
                    Section { Text(err).foregroundColor(.red).font(.system(size: 13)) }
                }
            }
            .navigationTitle(isCreate ? "Nouvel article" : "Modifier l'article")
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
                    .disabled(isSaving || titre.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: preload)
        }
    }

    private var isCreate: Bool { if case .create = mode { return true } else { return false } }

    private func preload() {
        guard case .edit(let a) = mode else { return }
        titre = a.titre
        slug = a.slug ?? ""
        extrait = a.extrait ?? ""
        contenu = a.contenu ?? ""
        metaTitle = a.meta_title ?? ""
        metaDescription = a.meta_description ?? ""
        publie = a.publie
        if let p = a.publie_le {
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            if let d = f.date(from: String(p.prefix(10))) {
                hasDate = true
                publieLe = d
            }
        }
    }

    private func save() async {
        errorMessage = nil
        isSaving = true; defer { isSaving = false }
        let payload = AdminArticlePayload(
            titre: titre.trimmingCharacters(in: .whitespacesAndNewlines),
            slug: slug.isEmpty ? nil : slug,
            extrait: extrait.isEmpty ? nil : extrait,
            contenu: contenu.isEmpty ? nil : contenu,
            meta_title: metaTitle.isEmpty ? nil : metaTitle,
            meta_description: metaDescription.isEmpty ? nil : metaDescription,
            publie: publie,
            publie_le: hasDate ? Self.fmt.string(from: publieLe) : nil
        )
        do {
            let saved: AdminArticle
            switch mode {
            case .create:
                saved = try await ContentAdminService.shared.createArticle(payload)
            case .edit(let a):
                saved = try await ContentAdminService.shared.updateArticle(id: a.id, payload)
            }
            onSaved(saved)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
