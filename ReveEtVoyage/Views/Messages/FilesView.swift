import SwiftUI

/// iCloud-style historic view of all attachments shared in messages.
/// Filter chips (Tous / Images / PDFs), grid for images, list for PDFs.
struct FilesView: View {
    @State private var allFiles: [Message] = []
    @State private var isLoading: Bool = true
    @State private var error: String? = nil
    @State private var filter: FileFilter = .all

    enum FileFilter: String, CaseIterable {
        case all = "Tous"
        case images = "Photos"
        case pdfs = "Documents"

        func matches(_ msg: Message) -> Bool {
            switch self {
            case .all: return msg.hasAttachment
            case .images: return msg.attachment_type == "image"
            case .pdfs: return msg.attachment_type == "pdf" || msg.attachment_type == "other"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterChips
                .padding(.horizontal, 18)
                .padding(.vertical, 12)

            content
        }
        .background(
            LinearGradient(colors: [Color.revYellow.opacity(0.06), Color.revBackground],
                           startPoint: .top, endPoint: .center).ignoresSafeArea()
        )
        .navigationTitle("Mes fichiers")
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .refreshable { await load() }
    }

    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach(FileFilter.allCases, id: \.self) { f in
                let selected = f == filter
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { filter = f }
                } label: {
                    Text(f.rawValue)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(selected ? .white : .revBrown)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                selected
                                    ? AnyShapeStyle(LinearGradient(colors: [.revOrange, .revRed],
                                                                   startPoint: .leading, endPoint: .trailing))
                                    : AnyShapeStyle(Color.revCardBackground)
                            )
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var content: some View {
        let filtered = allFiles.filter(filter.matches)
        if isLoading && allFiles.isEmpty {
            LoadingView()
        } else if let error, allFiles.isEmpty {
            ErrorView(message: error) { Task { await load() } }
        } else if filtered.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "folder").font(.system(size: 60)).foregroundColor(.revOrange.opacity(0.4))
                Text("Aucun fichier dans cette catégorie")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.revTextSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                if filter == .images {
                    imageGrid(filtered)
                } else {
                    fileList(filtered)
                }
            }
        }
    }

    private func imageGrid(_ items: [Message]) -> some View {
        let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: cols, spacing: 8) {
            ForEach(items) { msg in
                if let urlString = msg.attachment_url, let url = URL(string: urlString) {
                    NavigationLink {
                        ZoomableImageView(url: url, onClose: {})
                            .navigationBarHidden(true)
                    } label: {
                        CachedAsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(1, contentMode: .fill)
                            default:
                                Color.revCardBackground
                            }
                        }
                        .aspectRatio(1, contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private func fileList(_ items: [Message]) -> some View {
        LazyVStack(spacing: 10) {
            ForEach(items) { msg in
                FileRowCard(message: msg)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 24)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            allFiles = try await MessageService.shared.filesHistory()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct FileRowCard: View {
    let message: Message

    var body: some View {
        Button {
            if let urlString = message.attachment_url, let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(tint)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(message.attachment_name ?? "Fichier")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.revText)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(typeLabel).font(.system(size: 11)).foregroundColor(.revOrange)
                        Text("·").foregroundColor(.revTextSecondary)
                        Text(sizeLabel).font(.system(size: 11)).foregroundColor(.revTextSecondary)
                        Text("·").foregroundColor(.revTextSecondary)
                        Text(dateLabel).font(.system(size: 11)).foregroundColor(.revTextSecondary)
                    }
                }
                Spacer()
                Image(systemName: "arrow.up.right.square").foregroundColor(.revTextSecondary)
            }
            .padding(12)
            .background(Color.revCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var icon: String { message.attachment_type == "pdf" ? "doc.fill" : "paperclip" }
    private var tint: Color  { message.attachment_type == "pdf" ? .revRed : .revOrange }
    private var typeLabel: String { (message.attachment_type ?? "fichier").uppercased() }
    private var sizeLabel: String {
        guard let bytes = message.attachment_size else { return "—" }
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024.0) }
        return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
    }
    private var dateLabel: String {
        guard let d = message.sentAt else { return "—" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_BE")
        f.dateFormat = "d MMM"
        return f.string(from: d)
    }
}
