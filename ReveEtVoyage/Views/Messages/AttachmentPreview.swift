import SwiftUI

/// Inline preview shown inside a chat bubble for an attachment.
/// - Image: AsyncImage 200x200 with tap to open full screen
/// - PDF: card with file icon + name + size + tap to open in browser
struct AttachmentPreview: View {
    let message: Message
    @State private var showFullImage: Bool = false

    var body: some View {
        Group {
            if message.attachment_type == "image", let urlString = message.attachment_url, let url = URL(string: urlString) {
                imagePreview(url: url)
            } else if message.attachment_type == "pdf", let urlString = message.attachment_url, let url = URL(string: urlString) {
                pdfCard(url: url, name: message.attachment_name ?? "Document.pdf",
                        size: message.attachment_size)
            } else if let urlString = message.attachment_url, let url = URL(string: urlString) {
                fileCard(url: url, name: message.attachment_name ?? "Fichier",
                         size: message.attachment_size)
            }
        }
    }

    private func imagePreview(url: URL) -> some View {
        CachedAsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .onTapGesture { showFullImage = true }
            case .failure:
                placeholder(icon: "exclamationmark.triangle.fill", text: "Image indisponible")
            case .empty:
                placeholder(icon: "photo", text: "Chargement…")
            }
        }
        .fullScreenCover(isPresented: $showFullImage) {
            ZoomableImageView(url: url) { showFullImage = false }
        }
    }

    private func pdfCard(url: URL, name: String, size: Int?) -> some View {
        Button {
            UIApplication.shared.open(url)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.revRed)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.revText)
                        .lineLimit(1)
                    Text("PDF · \(formattedSize(size))")
                        .font(.system(size: 11))
                        .foregroundColor(.revTextSecondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.revOrange)
            }
            .padding(10)
            .frame(width: 240)
            .background(Color.revCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.gray.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func fileCard(url: URL, name: String, size: Int?) -> some View {
        Button {
            UIApplication.shared.open(url)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "paperclip")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.revOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.revText).lineLimit(1)
                    Text(formattedSize(size)).font(.system(size: 11)).foregroundColor(.revTextSecondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.revOrange)
            }
            .padding(10)
            .frame(width: 240)
            .background(Color.revCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.gray.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func placeholder(icon: String, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 28)).foregroundColor(.revTextSecondary)
            Text(text).font(.caption).foregroundColor(.revTextSecondary)
        }
        .frame(width: 200, height: 200)
        .background(Color.revCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func formattedSize(_ bytes: Int?) -> String {
        guard let bytes else { return "—" }
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024.0) }
        return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
    }
}

struct FullImageView: View {
    let url: URL
    let onClose: () -> Void
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in scale = lastScale * value }
                                .onEnded   { _ in lastScale = scale }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation { scale = scale > 1 ? 1 : 2; lastScale = scale }
                        }
                } else {
                    ProgressView().tint(.white)
                }
            }
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(20)
            }
        }
    }
}
