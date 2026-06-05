import SwiftUI

struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: (CachedImagePhase) -> Content

    @State private var phase: CachedImagePhase = .empty

    var body: some View {
        content(phase)
            .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else {
            phase = .empty
            return
        }
        if let cached = await ImageCacheService.shared.image(for: url) {
            phase = .success(Image(uiImage: cached))
            return
        }
        phase = .empty
        if let img = await ImageCacheService.shared.loadImage(for: url) {
            phase = .success(Image(uiImage: img))
        } else {
            phase = .failure
        }
    }
}

enum CachedImagePhase {
    case empty
    case success(Image)
    case failure
}

extension CachedAsyncImage where Content == AnyView {
    init(url: URL?) {
        self.url = url
        self.content = { phase in
            AnyView(
                Group {
                    switch phase {
                    case .success(let image):
                        image.resizable()
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    case .empty:
                        ProgressView()
                    }
                }
            )
        }
    }
}
