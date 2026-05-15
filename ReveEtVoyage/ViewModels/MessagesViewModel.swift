import Foundation

@MainActor
final class MessagesViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var draft: String = ""
    @Published var isLoading: Bool = false
    @Published var isSending: Bool = false
    @Published var errorMessage: String?

    private let service = MessageService.shared
    private var pollingTask: Task<Void, Never>?
    private let pollInterval: UInt64 = 5_000_000_000  // 5s in nanoseconds

    func startPolling() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            // Initial full fetch
            await self?.loadAll()

            // Loop polling for new messages only
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: self?.pollInterval ?? 5_000_000_000)
                if Task.isCancelled { break }
                await self?.fetchNewSinceLast()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func loadAll() async {
        isLoading = true
        defer { isLoading = false }

        do {
            messages = try await service.getMessages()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchNewSinceLast() async {
        let since = messages.last?.sentAt
        do {
            let fresh = try await service.getMessages(since: since)
            if !fresh.isEmpty {
                let existingIds = Set(messages.map { $0.id })
                let dedup = fresh.filter { !existingIds.contains($0.id) }
                messages.append(contentsOf: dedup)
            }
        } catch {
            // silent on poll errors
        }
    }

    func send() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }

        isSending = true
        defer { isSending = false }

        let snapshotDraft = draft
        draft = ""

        do {
            let message = try await service.sendMessage(body: body)
            messages.append(message)
        } catch {
            // Restore draft on failure
            draft = snapshotDraft
            errorMessage = error.localizedDescription
        }
    }

    /// Send an attachment (image or PDF), optionally with body text.
    func sendAttachment(data: Data, fileName: String, mime: String) async {
        isSending = true
        defer { isSending = false }
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let snapshotDraft = draft
        draft = ""

        do {
            let message = try await service.sendAttachment(
                body: body, fileData: data, fileName: fileName, mime: mime
            )
            messages.append(message)
        } catch {
            draft = snapshotDraft
            errorMessage = error.localizedDescription
        }
    }
}
