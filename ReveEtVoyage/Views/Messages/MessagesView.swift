import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct MessagesView: View {
    var initialDraft: String? = nil

    @StateObject private var viewModel = MessagesViewModel()
    @FocusState private var inputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var photoItem: PhotosPickerItem? = nil
    @State private var showDocPicker: Bool = false
    @State private var showFilesHistory: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            messagesScroll

            inputBar
        }
        .background(
            LinearGradient(colors: [Color.revYellow.opacity(0.06), Color.revBackground],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image("Icon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                    Text("Équipe Rêve et Voyage")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.revBrown)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showFilesHistory = true } label: {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.revOrange)
                }
            }
        }
        .onAppear {
            viewModel.startPolling()
            if let initialDraft, viewModel.draft.isEmpty {
                viewModel.draft = initialDraft
            }
        }
        .onDisappear { viewModel.stopPolling() }
        .onChange(of: photoItem) { newItem in
            guard let newItem else { return }
            Task { await handlePhoto(newItem) }
        }
        .fileImporter(
            isPresented: $showDocPicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleDoc(result)
        }
        .navigationDestination(isPresented: $showFilesHistory) {
            FilesView()
        }
    }

    // MARK: - Attachment handlers

    private func handlePhoto(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            viewModel.errorMessage = "Image illisible"
            return
        }
        let uti = item.supportedContentTypes.first
        let ext = uti?.preferredFilenameExtension ?? "jpg"
        let mime = uti?.preferredMIMEType ?? "image/jpeg"
        await viewModel.sendAttachment(data: data, fileName: "photo.\(ext)", mime: mime)
    }

    private func handleDoc(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) {
                Task {
                    await viewModel.sendAttachment(
                        data: data,
                        fileName: url.lastPathComponent,
                        mime: "application/pdf"
                    )
                }
            } else {
                viewModel.errorMessage = "Impossible de lire le fichier"
            }
        case .failure(let err):
            viewModel.errorMessage = err.localizedDescription
        }
    }

    private var messagesScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        emptyState
                            .padding(.top, 80)
                    } else {
                        ForEach(viewModel.messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let last = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "message.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(LinearGradient(colors: [.revYellow, .revOrange],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
            Text("Discute avec l'équipe")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.revText)
            Text("Pose tes questions, on te répondra rapidement.")
                .font(.system(size: 13))
                .foregroundColor(.revTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            // Photo
            PhotosPicker(selection: $photoItem, matching: .images) {
                Image(systemName: "photo.fill.on.rectangle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.revOrange)
                    .frame(width: 36, height: 36)
                    .background(Color.revOrange.opacity(0.10))
                    .clipShape(Circle())
            }
            // PDF / file
            Button { showDocPicker = true } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 18))
                    .foregroundColor(.revOrange)
                    .frame(width: 36, height: 36)
                    .background(Color.revOrange.opacity(0.10))
                    .clipShape(Circle())
            }

            TextField("Ton message…", text: $viewModel.draft, axis: .vertical)
                .focused($inputFocused)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.revCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(inputFocused ? Color.revOrange.opacity(0.5) : Color.gray.opacity(0.15),
                                      lineWidth: 1)
                )

            Button {
                Task { await viewModel.send() }
            } label: {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.revOrange, .revRed],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 42, height: 42)
                        .shadow(color: Color.revOrange.opacity(0.4), radius: 6, x: 0, y: 3)

                    if viewModel.isSending {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: -1, y: 1)
                    }
                }
            }
            .disabled(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
            .opacity(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Color.revBackground
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: -2)
        )
    }
}

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isFromUser { Spacer(minLength: 50) }

            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 6) {
                if message.hasAttachment {
                    AttachmentPreview(message: message)
                }

                if !message.body.isEmpty {
                    Text(message.body)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(message.isFromUser ? .white : .revText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(bubbleBackground)
                        .clipShape(BubbleShape(isFromUser: message.isFromUser))
                }

                if let date = message.sentAt {
                    Text(timeFormatter.string(from: date))
                        .font(.system(size: 10))
                        .foregroundColor(.revTextSecondary)
                        .padding(.horizontal, 4)
                }
            }

            if message.isFromAdmin { Spacer(minLength: 50) }
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if message.isFromUser {
            LinearGradient(colors: [.revOrange, .revRed],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            Color.revCardBackground
        }
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_BE")
        f.dateFormat = "HH:mm"
        return f
    }
}

struct BubbleShape: Shape {
    let isFromUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let smallRadius: CGFloat = 4
        let topLeftRadius     = isFromUser ? radius : radius
        let topRightRadius    = isFromUser ? radius : radius
        let bottomLeftRadius  = isFromUser ? radius : smallRadius
        let bottomRightRadius = isFromUser ? smallRadius : radius

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topLeftRadius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRightRadius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + topRightRadius),
                          control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRightRadius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - bottomRightRadius, y: rect.maxY),
                          control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + bottomLeftRadius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bottomLeftRadius),
                          control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeftRadius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + topLeftRadius, y: rect.minY),
                          control: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
